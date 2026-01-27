(** Binary Canonical Serialization (BCS) for OCaml

    BCS is a deterministic binary serialization format designed for
    canonical representation of data structures. *)

(** {1 Constants} *)

val max_sequence_length : int
(** Maximum length for variable-length sequences (2^31 - 1) *)

val max_container_depth : int
(** Maximum container depth for nested structures *)

(** {1 Error Types} *)

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
(** Exception raised for BCS errors *)

val error_message : error_type -> string
(** Get human-readable error message *)

(** {1 ULEB128 Encoding/Decoding} *)

module Uleb128 : sig
  val encode : int -> bytes
  (** Encode a non-negative integer as ULEB128 *)

  val decode : bytes -> int -> int * int
  (** [decode bytes offset] decodes ULEB128 from [bytes] starting at [offset].
      Returns [(value, bytes_read)].
      @raise Bcs_error on invalid encoding *)

  val encoded_size : int -> int
  (** Calculate the encoded size of a value *)
end

(** {1 Serializer} *)

module Serializer : sig
  type t
  (** Serializer state *)

  val create : unit -> t
  (** Create a new serializer *)

  val to_bytes : t -> bytes
  (** Get the serialized bytes *)

  val size : t -> int
  (** Get current buffer size *)

  val reset : t -> unit
  (** Reset the serializer for reuse *)

  (** {2 Boolean} *)

  val write_bool : t -> bool -> unit

  (** {2 Unsigned Integers} *)

  val write_u8 : t -> int -> unit
  val write_u16 : t -> int -> unit
  val write_u32 : t -> int32 -> unit
  val write_u64 : t -> int64 -> unit
  val write_u128 : t -> bytes -> unit
  val write_u256 : t -> bytes -> unit

  (** {2 Signed Integers} *)

  val write_i8 : t -> int -> unit
  val write_i16 : t -> int -> unit
  val write_i32 : t -> int32 -> unit
  val write_i64 : t -> int64 -> unit
  val write_i128 : t -> bytes -> unit
  val write_i256 : t -> bytes -> unit

  (** {2 ULEB128} *)

  val write_uleb128 : t -> int -> unit

  (** {2 Bytes and Strings} *)

  val write_fixed_bytes : t -> bytes -> unit
  val write_bytes : t -> bytes -> unit
  val write_string : t -> string -> unit

  (** {2 Composite Types} *)

  val write_option : t -> 'a option -> (t -> 'a -> unit) -> unit
  val write_list : t -> 'a list -> (t -> 'a -> unit) -> unit
  val write_array : t -> 'a array -> (t -> 'a -> unit) -> unit

  (** {2 Container Depth} *)

  val enter_struct : t -> unit
  val leave_struct : t -> unit
  val write_variant_index : t -> int -> unit
  val leave_enum : t -> unit
end

(** {1 Deserializer} *)

module Deserializer : sig
  type t
  (** Deserializer state *)

  val create : bytes -> t
  (** Create a deserializer from bytes *)

  val of_string : string -> t
  (** Create a deserializer from a string *)

  val check_end : t -> unit
  (** Check that all input has been consumed.
      @raise Bcs_error if there are remaining bytes *)

  val remaining : t -> int
  (** Get the number of remaining bytes *)

  val offset : t -> int
  (** Get current read offset *)

  (** {2 Boolean} *)

  val read_bool : t -> bool

  (** {2 Unsigned Integers} *)

  val read_u8 : t -> int
  val read_u16 : t -> int
  val read_u32 : t -> int32
  val read_u64 : t -> int64
  val read_u128 : t -> bytes
  val read_u256 : t -> bytes

  (** {2 Signed Integers} *)

  val read_i8 : t -> int
  val read_i16 : t -> int
  val read_i32 : t -> int32
  val read_i64 : t -> int64
  val read_i128 : t -> bytes
  val read_i256 : t -> bytes

  (** {2 ULEB128} *)

  val read_uleb128 : t -> int

  (** {2 Bytes and Strings} *)

  val read_fixed_bytes : t -> int -> bytes
  val read_bytes : t -> bytes
  val read_string : t -> string

  (** {2 Composite Types} *)

  val read_option : t -> (t -> 'a) -> 'a option
  val read_list : t -> (t -> 'a) -> 'a list
  val read_array : t -> (t -> 'a) -> 'a array

  (** {2 Container Depth} *)

  val enter_struct : t -> unit
  val leave_struct : t -> unit
  val read_variant_index : t -> int
  val leave_enum : t -> unit
end

(** {1 Utilities} *)

val bytes_to_hex : bytes -> string
(** Convert bytes to hexadecimal string *)

val hex_to_bytes : string -> bytes
(** Convert hexadecimal string to bytes *)
