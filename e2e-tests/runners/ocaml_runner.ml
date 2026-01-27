(* OCaml BCS E2E Test Runner *)
(* Run: ocaml ocaml_runner.ml *)

(* Simple BCS Serializer *)
let ser_buffer = Buffer.create 256

let ser_reset () = Buffer.clear ser_buffer
let ser_write_u8 v = Buffer.add_char ser_buffer (Char.chr (v land 0xFF))
let ser_write_bool v = ser_write_u8 (if v then 1 else 0)

let ser_write_u16 v =
  ser_write_u8 (v land 0xFF);
  ser_write_u8 ((v lsr 8) land 0xFF)

let ser_write_u32 v =
  for i = 0 to 3 do
    ser_write_u8 ((Int32.to_int (Int32.shift_right v (i * 8))) land 0xFF)
  done

let ser_write_u64 v =
  for i = 0 to 7 do
    ser_write_u8 ((Int64.to_int (Int64.shift_right v (i * 8))) land 0xFF)
  done

let ser_write_u128 bytes =
  for i = 0 to 15 do
    ser_write_u8 (Bytes.get_uint8 bytes i)
  done

let ser_write_i8 v = ser_write_u8 (v land 0xFF)
let ser_write_i16 v = ser_write_u16 (v land 0xFFFF)
let ser_write_i32 v = ser_write_u32 (Int32.of_int v)
let ser_write_i64 v = ser_write_u64 v

let ser_write_uleb128 v =
  let rec loop v =
    let b = v land 0x7F in
    let v' = v lsr 7 in
    if v' = 0 then ser_write_u8 b
    else begin
      ser_write_u8 (b lor 0x80);
      loop v'
    end
  in loop v

let ser_write_string s =
  let len = String.length s in
  ser_write_uleb128 len;
  for i = 0 to len - 1 do
    ser_write_u8 (Char.code s.[i])
  done

let ser_write_bytes bytes =
  let len = Bytes.length bytes in
  ser_write_uleb128 len;
  for i = 0 to len - 1 do
    ser_write_u8 (Bytes.get_uint8 bytes i)
  done

let ser_write_fixed_bytes bytes =
  for i = 0 to Bytes.length bytes - 1 do
    ser_write_u8 (Bytes.get_uint8 bytes i)
  done

let ser_to_bytes () = Buffer.to_bytes ser_buffer

(* Simple BCS Deserializer *)
type deserializer = { data : bytes; mutable offset : int }

exception Des_error of string

let des_init data = { data; offset = 0 }

let des_read_u8 d =
  if d.offset >= Bytes.length d.data then raise (Des_error "EOF");
  let v = Bytes.get_uint8 d.data d.offset in
  d.offset <- d.offset + 1;
  v

let des_read_bool d =
  let b = des_read_u8 d in
  if b = 0 then false
  else if b = 1 then true
  else raise (Des_error "Invalid bool")

let des_read_u16 d =
  if d.offset + 2 > Bytes.length d.data then raise (Des_error "EOF");
  let v = Bytes.get_uint8 d.data d.offset lor (Bytes.get_uint8 d.data (d.offset + 1) lsl 8) in
  d.offset <- d.offset + 2;
  v

let des_read_u32 d =
  if d.offset + 4 > Bytes.length d.data then raise (Des_error "EOF");
  let v = ref Int32.zero in
  for i = 0 to 3 do
    v := Int32.logor !v (Int32.shift_left (Int32.of_int (Bytes.get_uint8 d.data (d.offset + i))) (i * 8))
  done;
  d.offset <- d.offset + 4;
  !v

let des_read_u64 d =
  if d.offset + 8 > Bytes.length d.data then raise (Des_error "EOF");
  let v = ref Int64.zero in
  for i = 0 to 7 do
    v := Int64.logor !v (Int64.shift_left (Int64.of_int (Bytes.get_uint8 d.data (d.offset + i))) (i * 8))
  done;
  d.offset <- d.offset + 8;
  !v

let des_read_u128 d =
  if d.offset + 16 > Bytes.length d.data then raise (Des_error "EOF");
  let bytes = Bytes.sub d.data d.offset 16 in
  d.offset <- d.offset + 16;
  bytes

let des_read_i8 d =
  let u = des_read_u8 d in
  if u < 128 then u else u - 256

let des_read_i16 d =
  let u = des_read_u16 d in
  if u < 32768 then u else u - 65536

let des_read_i32 d =
  Int32.to_int (des_read_u32 d)

let des_read_i64 d = des_read_u64 d
let des_read_i128 d = des_read_u128 d

let des_read_uleb128 d =
  let rec loop value shift =
    if d.offset >= Bytes.length d.data then raise (Des_error "EOF");
    let b = Bytes.get_uint8 d.data d.offset in
    d.offset <- d.offset + 1;
    let value' = value lor ((b land 0x7F) lsl shift) in
    if b land 0x80 = 0 then value'
    else loop value' (shift + 7)
  in loop 0 0

let des_read_string d =
  let len = des_read_uleb128 d in
  if d.offset + len > Bytes.length d.data then raise (Des_error "EOF");
  let s = Bytes.sub_string d.data d.offset len in
  d.offset <- d.offset + len;
  s

let des_read_bytes d =
  let len = des_read_uleb128 d in
  if d.offset + len > Bytes.length d.data then raise (Des_error "EOF");
  let bytes = Bytes.sub d.data d.offset len in
  d.offset <- d.offset + len;
  bytes

let des_read_fixed_bytes d len =
  if d.offset + len > Bytes.length d.data then raise (Des_error "EOF");
  let bytes = Bytes.sub d.data d.offset len in
  d.offset <- d.offset + len;
  bytes

let des_check_end d =
  if d.offset <> Bytes.length d.data then raise (Des_error "Remaining input")

(* Hex conversion *)
let hex_to_bytes hex =
  let len = String.length hex / 2 in
  let bytes = Bytes.create len in
  for i = 0 to len - 1 do
    let s = String.sub hex (i * 2) 2 in
    Bytes.set_uint8 bytes i (int_of_string ("0x" ^ s))
  done;
  bytes

let bytes_to_hex bytes =
  let len = Bytes.length bytes in
  let hex = Buffer.create (len * 2) in
  for i = 0 to len - 1 do
    Buffer.add_string hex (Printf.sprintf "%02x" (Bytes.get_uint8 bytes i))
  done;
  Buffer.contents hex

(* JSON helpers *)
let escape_json s =
  let buf = Buffer.create (String.length s) in
  String.iter (fun c ->
    match c with
    | '"' -> Buffer.add_string buf "\\\""
    | '\\' -> Buffer.add_string buf "\\\\"
    | '\n' -> Buffer.add_string buf "\\n"
    | '\r' -> Buffer.add_string buf "\\r"
    | '\t' -> Buffer.add_string buf "\\t"
    | c -> Buffer.add_char buf c
  ) s;
  Buffer.contents buf

let find_json_string key json =
  let search = "\"" ^ key ^ "\"" in
  try
    let pos = Str.search_forward (Str.regexp_string search) json 0 in
    let after_key = String.sub json (pos + String.length search) (String.length json - pos - String.length search) in
    let after_colon = String.sub after_key (Str.search_forward (Str.regexp ":[ \t]*\"") after_key 0 + 1) (String.length after_key) in
    let start = Str.search_forward (Str.regexp "\"") after_colon 0 + 1 in
    let end_pos = Str.search_forward (Str.regexp "\"") after_colon start in
    Some (String.sub after_colon start (end_pos - start))
  with Not_found -> None

(* Process test case *)
let process_test_case tc =
  let name = match find_json_string "name" tc with Some s -> s | None -> "" in
  let typ = match find_json_string "type" tc with Some s -> s | None -> "" in
  let bcs_hex = match find_json_string "bcs_hex" tc with Some s -> s | None -> "" in
  
  (* Extract value section *)
  let value_json =
    try
      let pos = Str.search_forward (Str.regexp_string "\"value\"") tc 0 in
      let after = String.sub tc pos (String.length tc - pos) in
      let colon_pos = Str.search_forward (Str.regexp ":") after 0 in
      let rest = String.sub after (colon_pos + 1) (String.length after - colon_pos - 1) in
      let rest = String.trim rest in
      (* Find matching end *)
      let rec find_end i depth in_str =
        if i >= String.length rest then i
        else match rest.[i] with
        | '"' when not in_str -> find_end (i+1) depth true
        | '"' -> find_end (i+1) depth false
        | '{' | '[' when not in_str -> find_end (i+1) (depth+1) in_str
        | '}' | ']' when not in_str -> if depth <= 1 then i else find_end (i+1) (depth-1) in_str
        | ',' when not in_str && depth = 0 -> i
        | _ -> find_end (i+1) depth in_str
      in
      let end_pos = find_end 0 0 false in
      String.sub rest 0 end_pos
    with Not_found -> "null"
  in
  
  let data = hex_to_bytes bcs_hex in
  let d = des_init data in
  
  ser_reset ();
  
  try
    begin match typ with
    | "bool" ->
        let v = des_read_bool d in
        des_check_end d;
        ser_write_bool v
    | "u8" ->
        let v = des_read_u8 d in
        des_check_end d;
        ser_write_u8 v
    | "u16" ->
        let v = des_read_u16 d in
        des_check_end d;
        ser_write_u16 v
    | "u32" ->
        let v = des_read_u32 d in
        des_check_end d;
        ser_write_u32 v
    | "u64" ->
        let v = des_read_u64 d in
        des_check_end d;
        ser_write_u64 v
    | "u128" ->
        let v = des_read_u128 d in
        des_check_end d;
        ser_write_u128 v
    | "i8" ->
        let v = des_read_i8 d in
        des_check_end d;
        ser_write_i8 v
    | "i16" ->
        let v = des_read_i16 d in
        des_check_end d;
        ser_write_i16 v
    | "i32" ->
        let v = des_read_i32 d in
        des_check_end d;
        ser_write_i32 v
    | "i64" ->
        let v = des_read_i64 d in
        des_check_end d;
        ser_write_i64 v
    | "i128" ->
        let v = des_read_i128 d in
        des_check_end d;
        ser_write_u128 v
    | "string" ->
        let v = des_read_string d in
        des_check_end d;
        ser_write_string v
    | "bytes" ->
        let v = des_read_bytes d in
        des_check_end d;
        ser_write_bytes v
    | "fixed_bytes_32" ->
        let v = des_read_fixed_bytes d 32 in
        des_check_end d;
        ser_write_fixed_bytes v
    | _ ->
        raise (Des_error ("Unknown or complex type: " ^ typ))
    end;
    let result_hex = bytes_to_hex (ser_to_bytes ()) in
    Printf.sprintf "    {\"name\": \"%s\", \"type\": \"%s\", \"bcs_hex\": \"%s\", \"value\": %s}"
      (escape_json name) typ result_hex value_json
  with Des_error err ->
    Printf.sprintf "    {\"name\": \"%s\", \"type\": \"%s\", \"bcs_hex\": \"\", \"value\": %s, \"error\": \"%s\"}"
      (escape_json name) typ value_json (escape_json err)

(* Extract test cases from category *)
let extract_test_cases category json =
  let search = "\"" ^ category ^ "\"" in
  try
    let pos = Str.search_forward (Str.regexp_string search) json 0 in
    let after = String.sub json pos (String.length json - pos) in
    let arr_start = Str.search_forward (Str.regexp "\\[") after 0 in
    let arr_content = String.sub after (arr_start + 1) (String.length after - arr_start - 1) in
    
    (* Extract objects *)
    let rec extract_objects s acc =
      try
        let obj_start = Str.search_forward (Str.regexp "{") s 0 in
        let rec find_end i depth =
          if i >= String.length s then i
          else match s.[i] with
          | '{' -> find_end (i+1) (depth+1)
          | '}' -> if depth = 1 then i+1 else find_end (i+1) (depth-1)
          | _ -> find_end (i+1) depth
        in
        let obj_end = find_end obj_start 0 in
        let obj = String.sub s obj_start (obj_end - obj_start) in
        let rest = String.sub s obj_end (String.length s - obj_end) in
        extract_objects rest (obj :: acc)
      with Not_found -> List.rev acc
    in
    extract_objects arr_content []
  with Not_found -> []

let () =
  (* Read all stdin *)
  let buf = Buffer.create 4096 in
  (try
    while true do
      Buffer.add_string buf (input_line stdin);
      Buffer.add_char buf '\n'
    done
  with End_of_file -> ());
  let input = Buffer.contents buf in
  
  print_endline "{";
  print_endline "  \"version\": \"1.0.0\",";
  print_endline "  \"description\": \"OCaml roundtrip results\",";
  
  let categories = ["primitives"; "strings"; "bytes"; "options"; "vectors"; "structs"; "complex"] in
  let last_cat = List.hd (List.rev categories) in
  
  List.iter (fun cat ->
    Printf.printf "  \"%s\": [\n" cat;
    let test_cases = extract_test_cases cat input in
    let len = List.length test_cases in
    List.iteri (fun i tc ->
      let result = process_test_case tc in
      print_string result;
      if i < len - 1 then print_string ",";
      print_newline ()
    ) test_cases;
    Printf.printf "  ]%s\n" (if cat = last_cat then "" else ",")
  ) categories;
  
  print_endline "}"
