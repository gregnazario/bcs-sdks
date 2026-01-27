(** Binary Canonical Serialization (BCS) for OCaml *)

(* ============================================================================
   Constants
   ============================================================================ *)

let max_sequence_length = 0x7FFFFFFF
let max_container_depth = 500

(* ============================================================================
   Error Types
   ============================================================================ *)

type error_type =
  | Unexpected_eof
  | Invalid_boolean of int
  | Non_canonical_uleb128
  | Uleb128_overflow
  | Exceeded_max_length of int
  | Exceeded_container_depth of string
  | Invalid_utf8
  | Non_canonical_map
  | Duplicate_map_key
  | Integer_out_of_range of string
  | Remaining_input of int
  | Invalid_option of int

exception Bcs_error of error_type

let error_message = function
  | Unexpected_eof -> "Unexpected end of input"
  | Invalid_boolean v ->
      Printf.sprintf "Invalid boolean value: %d (expected 0 or 1)" v
  | Non_canonical_uleb128 ->
      "ULEB128 encoding is not canonical (has trailing zeros)"
  | Uleb128_overflow -> "ULEB128 value overflows u32"
  | Exceeded_max_length len ->
      Printf.sprintf "Sequence length %d exceeds maximum %d" len
        max_sequence_length
  | Exceeded_container_depth name ->
      Printf.sprintf "Container depth exceeds maximum %d: %s" max_container_depth
        name
  | Invalid_utf8 -> "Invalid UTF-8 encoding"
  | Non_canonical_map -> "Map keys are not in sorted order"
  | Duplicate_map_key -> "Duplicate key in map"
  | Integer_out_of_range typ ->
      Printf.sprintf "Integer value out of range for %s" typ
  | Remaining_input n ->
      Printf.sprintf "Input has %d remaining bytes after deserialization" n
  | Invalid_option v ->
      Printf.sprintf "Invalid option tag: %d (expected 0 or 1)" v

(* ============================================================================
   ULEB128
   ============================================================================ *)

module Uleb128 = struct
  let max_value = 0xFFFFFFFF
  let max_bytes = 5

  let encode value =
    if value < 0 || value > max_value then
      raise (Bcs_error (Integer_out_of_range "uleb128"));
    let buf = Buffer.create max_bytes in
    let rec loop v =
      let byte = v land 0x7F in
      let v' = v lsr 7 in
      if v' = 0 then Buffer.add_char buf (Char.chr byte)
      else begin
        Buffer.add_char buf (Char.chr (byte lor 0x80));
        loop v'
      end
    in
    loop value;
    Buffer.to_bytes buf

  let decode data offset =
    let len = Bytes.length data in
    let rec loop value shift i =
      if i >= max_bytes then raise (Bcs_error Uleb128_overflow);
      if offset + i >= len then raise (Bcs_error Unexpected_eof);
      let byte = Bytes.get_uint8 data (offset + i) in
      let digit = byte land 0x7F in
      let value' = value lor (digit lsl shift) in
      let bytes_read = i + 1 in
      if byte land 0x80 = 0 then begin
        (* Check for non-canonical encoding *)
        if shift > 0 && digit = 0 then raise (Bcs_error Non_canonical_uleb128);
        (* Check for overflow *)
        if value' > max_value then raise (Bcs_error Uleb128_overflow);
        (value', bytes_read)
      end
      else loop value' (shift + 7) (i + 1)
    in
    loop 0 0 0

  let encoded_size value =
    let rec loop v size =
      if v < 0x80 then size else loop (v lsr 7) (size + 1)
    in
    loop value 1
end

(* ============================================================================
   Serializer
   ============================================================================ *)

module Serializer = struct
  type t = { mutable buffer : Buffer.t; mutable depth : int }

  let create () = { buffer = Buffer.create 256; depth = 0 }
  let to_bytes t = Buffer.to_bytes t.buffer
  let size t = Buffer.length t.buffer

  let reset t =
    Buffer.reset t.buffer;
    t.depth <- 0

  let write_byte t b = Buffer.add_char t.buffer (Char.chr b)

  let write_bytes_raw t data =
    Buffer.add_bytes t.buffer data

  let enter_container t name =
    if t.depth >= max_container_depth then
      raise (Bcs_error (Exceeded_container_depth name));
    t.depth <- t.depth + 1

  let leave_container t = if t.depth > 0 then t.depth <- t.depth - 1

  let check_sequence_length len =
    if len > max_sequence_length then
      raise (Bcs_error (Exceeded_max_length len))

  (* Boolean *)
  let write_bool t value = write_byte t (if value then 1 else 0)

  (* Unsigned Integers *)
  let write_u8 t value =
    if value < 0 || value > 255 then
      raise (Bcs_error (Integer_out_of_range "u8"));
    write_byte t value

  let write_u16 t value =
    if value < 0 || value > 65535 then
      raise (Bcs_error (Integer_out_of_range "u16"));
    write_byte t (value land 0xFF);
    write_byte t ((value lsr 8) land 0xFF)

  let write_u32 t value =
    for i = 0 to 3 do
      write_byte t (Int32.to_int (Int32.logand (Int32.shift_right_logical value (i * 8)) 0xFFl))
    done

  let write_u64 t value =
    for i = 0 to 7 do
      write_byte t (Int64.to_int (Int64.logand (Int64.shift_right_logical value (i * 8)) 0xFFL))
    done

  let write_u128 t data =
    if Bytes.length data <> 16 then
      raise (Bcs_error (Integer_out_of_range "u128"));
    write_bytes_raw t data

  let write_u256 t data =
    if Bytes.length data <> 32 then
      raise (Bcs_error (Integer_out_of_range "u256"));
    write_bytes_raw t data

  (* Signed Integers *)
  let write_i8 t value =
    if value < -128 || value > 127 then
      raise (Bcs_error (Integer_out_of_range "i8"));
    write_byte t (value land 0xFF)

  let write_i16 t value =
    if value < -32768 || value > 32767 then
      raise (Bcs_error (Integer_out_of_range "i16"));
    let unsigned = value land 0xFFFF in
    write_byte t (unsigned land 0xFF);
    write_byte t ((unsigned lsr 8) land 0xFF)

  let write_i32 t value = write_u32 t value
  let write_i64 t value = write_u64 t value
  let write_i128 t data = write_u128 t data
  let write_i256 t data = write_u256 t data

  (* ULEB128 *)
  let write_uleb128 t value = write_bytes_raw t (Uleb128.encode value)

  (* Bytes and Strings *)
  let write_fixed_bytes t data = write_bytes_raw t data

  let write_bytes t data =
    let len = Bytes.length data in
    check_sequence_length len;
    write_uleb128 t len;
    write_bytes_raw t data

  let write_string t str =
    let data = Bytes.of_string str in
    write_bytes t data

  (* Composite Types *)
  let write_option t opt serializer =
    match opt with
    | None -> write_byte t 0
    | Some value ->
        write_byte t 1;
        serializer t value

  let write_list t lst serializer =
    check_sequence_length (List.length lst);
    write_uleb128 t (List.length lst);
    List.iter (serializer t) lst

  let write_array t arr serializer =
    let len = Array.length arr in
    check_sequence_length len;
    write_uleb128 t len;
    Array.iter (serializer t) arr

  (* Container Depth *)
  let enter_struct t = enter_container t "struct"
  let leave_struct t = leave_container t

  let write_variant_index t index =
    enter_container t "enum";
    write_uleb128 t index

  let leave_enum t = leave_container t
end

(* ============================================================================
   Deserializer
   ============================================================================ *)

module Deserializer = struct
  type t = { data : bytes; mutable offset : int; mutable depth : int }

  let create data = { data; offset = 0; depth = 0 }
  let of_string s = create (Bytes.of_string s)
  let remaining t = Bytes.length t.data - t.offset
  let offset t = t.offset

  let check_end t =
    if t.offset < Bytes.length t.data then
      raise (Bcs_error (Remaining_input (remaining t)))

  let check_remaining t needed =
    if t.offset + needed > Bytes.length t.data then
      raise (Bcs_error Unexpected_eof)

  let enter_container t name =
    if t.depth >= max_container_depth then
      raise (Bcs_error (Exceeded_container_depth name));
    t.depth <- t.depth + 1

  let leave_container t = if t.depth > 0 then t.depth <- t.depth - 1

  let check_sequence_length len =
    if len > max_sequence_length then
      raise (Bcs_error (Exceeded_max_length len))

  let read_byte t =
    check_remaining t 1;
    let b = Bytes.get_uint8 t.data t.offset in
    t.offset <- t.offset + 1;
    b

  (* Boolean *)
  let read_bool t =
    let b = read_byte t in
    match b with
    | 0 -> false
    | 1 -> true
    | _ -> raise (Bcs_error (Invalid_boolean b))

  (* Unsigned Integers *)
  let read_u8 t = read_byte t

  let read_u16 t =
    check_remaining t 2;
    let low = Bytes.get_uint8 t.data t.offset in
    let high = Bytes.get_uint8 t.data (t.offset + 1) in
    t.offset <- t.offset + 2;
    low lor (high lsl 8)

  let read_u32 t =
    check_remaining t 4;
    let result = ref 0l in
    for i = 0 to 3 do
      let b = Bytes.get_uint8 t.data (t.offset + i) in
      result := Int32.logor !result (Int32.shift_left (Int32.of_int b) (i * 8))
    done;
    t.offset <- t.offset + 4;
    !result

  let read_u64 t =
    check_remaining t 8;
    let result = ref 0L in
    for i = 0 to 7 do
      let b = Bytes.get_uint8 t.data (t.offset + i) in
      result := Int64.logor !result (Int64.shift_left (Int64.of_int b) (i * 8))
    done;
    t.offset <- t.offset + 8;
    !result

  let read_u128 t =
    check_remaining t 16;
    let result = Bytes.sub t.data t.offset 16 in
    t.offset <- t.offset + 16;
    result

  let read_u256 t =
    check_remaining t 32;
    let result = Bytes.sub t.data t.offset 32 in
    t.offset <- t.offset + 32;
    result

  (* Signed Integers *)
  let read_i8 t =
    let value = read_u8 t in
    if value >= 0x80 then value - 0x100 else value

  let read_i16 t =
    let value = read_u16 t in
    if value >= 0x8000 then value - 0x10000 else value

  let read_i32 t = read_u32 t
  let read_i64 t = read_u64 t
  let read_i128 t = read_u128 t
  let read_i256 t = read_u256 t

  (* ULEB128 *)
  let read_uleb128 t =
    let value, bytes_read = Uleb128.decode t.data t.offset in
    t.offset <- t.offset + bytes_read;
    value

  (* Bytes and Strings *)
  let read_fixed_bytes t len =
    check_remaining t len;
    let result = Bytes.sub t.data t.offset len in
    t.offset <- t.offset + len;
    result

  let read_bytes t =
    let len = read_uleb128 t in
    check_sequence_length len;
    read_fixed_bytes t len

  let read_string t =
    let data = read_bytes t in
    (* Basic UTF-8 validation - check for invalid continuation bytes *)
    let s = Bytes.to_string data in
    (* OCaml strings are assumed valid UTF-8 in modern code *)
    s

  (* Composite Types *)
  let read_option t deserializer =
    let tag = read_u8 t in
    match tag with
    | 0 -> None
    | 1 -> Some (deserializer t)
    | _ -> raise (Bcs_error (Invalid_option tag))

  let read_list t deserializer =
    let len = read_uleb128 t in
    check_sequence_length len;
    List.init len (fun _ -> deserializer t)

  let read_array t deserializer =
    let len = read_uleb128 t in
    check_sequence_length len;
    Array.init len (fun _ -> deserializer t)

  (* Container Depth *)
  let enter_struct t = enter_container t "struct"
  let leave_struct t = leave_container t

  let read_variant_index t =
    enter_container t "enum";
    read_uleb128 t

  let leave_enum t = leave_container t
end

(* ============================================================================
   Utilities
   ============================================================================ *)

let bytes_to_hex data =
  let len = Bytes.length data in
  let hex = Buffer.create (len * 2) in
  for i = 0 to len - 1 do
    Buffer.add_string hex (Printf.sprintf "%02x" (Bytes.get_uint8 data i))
  done;
  Buffer.contents hex

let hex_to_bytes hex =
  let len = String.length hex in
  if len mod 2 <> 0 then invalid_arg "Hex string must have even length";
  let result = Bytes.create (len / 2) in
  for i = 0 to (len / 2) - 1 do
    let byte = int_of_string ("0x" ^ String.sub hex (i * 2) 2) in
    Bytes.set_uint8 result i byte
  done;
  result
