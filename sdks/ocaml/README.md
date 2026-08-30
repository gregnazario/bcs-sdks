# BCS OCaml SDK

A pure OCaml implementation of Binary Canonical Serialization (BCS).

## Features

- **Pure OCaml**: No C bindings or external dependencies
- **OCaml 4.14+**: Uses modern OCaml features
- **Type-safe**: Fully typed serialization/deserialization
- **Functional API**: Idiomatic OCaml patterns

## Installation

> **Note:** This package is not yet published to opam. For now, clone this repo and run `opam install .` in [sdks/ocaml](.).

### Using opam

```bash
opam install bcs
```

### Using dune

Add to your `dune-project`:

```lisp
(depends (bcs (>= 0.1.0)))
```

## Quick Start

```ocaml
open Bcs

(* Serialize *)
let ser = Serializer.create () in
Serializer.write_u64 ser 12345L;
Serializer.write_string ser "hello";
Serializer.write_bool ser true;
let bytes = Serializer.to_bytes ser in

(* Deserialize *)
let des = Deserializer.create bytes in
let num = Deserializer.read_u64 des in
let str = Deserializer.read_string des in
let flag = Deserializer.read_bool des in
Deserializer.check_end des
```

## Supported Types

| BCS Type | OCaml Type | Serialize | Deserialize |
|----------|------------|-----------|-------------|
| bool | `bool` | `write_bool` | `read_bool` |
| u8 | `int` | `write_u8` | `read_u8` |
| u16 | `int` | `write_u16` | `read_u16` |
| u32 | `int32` | `write_u32` | `read_u32` |
| u64 | `int64` | `write_u64` | `read_u64` |
| u128 | `bytes` | `write_u128` | `read_u128` |
| u256 | `bytes` | `write_u256` | `read_u256` |
| i8 | `int` | `write_i8` | `read_i8` |
| i16 | `int` | `write_i16` | `read_i16` |
| i32 | `int32` | `write_i32` | `read_i32` |
| i64 | `int64` | `write_i64` | `read_i64` |
| string | `string` | `write_string` | `read_string` |
| bytes | `bytes` | `write_bytes` | `read_bytes` |
| option | `'a option` | `write_option` | `read_option` |
| vector | `'a list` | `write_list` | `read_list` |
| vector | `'a array` | `write_array` | `read_array` |

## Complex Types

### Options

```ocaml
open Bcs

let ser = Serializer.create () in

(* Some value *)
Serializer.write_option ser (Some 42) (fun s v -> Serializer.write_u32 s (Int32.of_int v));

(* None *)
Serializer.write_option ser None (fun s v -> Serializer.write_u32 s (Int32.of_int v));

(* Deserialize *)
let des = Deserializer.create (Serializer.to_bytes ser) in
let opt1 = Deserializer.read_option des (fun d -> Int32.to_int (Deserializer.read_u32 d)) in
let opt2 = Deserializer.read_option des (fun d -> Int32.to_int (Deserializer.read_u32 d)) in
(* opt1 = Some 42, opt2 = None *)
```

### Lists

```ocaml
open Bcs

let ser = Serializer.create () in
Serializer.write_list ser [100; 200; 300] (fun s v -> Serializer.write_u16 s v);

(* Deserialize *)
let des = Deserializer.create (Serializer.to_bytes ser) in
let vec = Deserializer.read_list des Deserializer.read_u16 in
(* vec = [100; 200; 300] *)
```

### Structs

```ocaml
open Bcs

type person = {
  name : string;
  age : int;
  email : string option;
}

let serialize_person ser person =
  Serializer.enter_struct ser;
  Serializer.write_string ser person.name;
  Serializer.write_u32 ser (Int32.of_int person.age);
  Serializer.write_option ser person.email (fun s e -> Serializer.write_string s e);
  Serializer.leave_struct ser

let deserialize_person des =
  Deserializer.enter_struct des;
  let name = Deserializer.read_string des in
  let age = Int32.to_int (Deserializer.read_u32 des) in
  let email = Deserializer.read_option des Deserializer.read_string in
  Deserializer.leave_struct des;
  { name; age; email }
```

### Enums

```ocaml
open Bcs

type message =
  | Text of string
  | Image of bytes * int * int  (* data, width, height *)

let serialize_message ser msg =
  match msg with
  | Text content ->
      Serializer.write_variant_index ser 0;
      Serializer.write_string ser content;
      Serializer.leave_enum ser
  | Image (data, width, height) ->
      Serializer.write_variant_index ser 1;
      Serializer.write_bytes ser data;
      Serializer.write_u32 ser (Int32.of_int width);
      Serializer.write_u32 ser (Int32.of_int height);
      Serializer.leave_enum ser

let deserialize_message des =
  let variant = Deserializer.read_variant_index des in
  let result = match variant with
    | 0 -> Text (Deserializer.read_string des)
    | 1 ->
        let data = Deserializer.read_bytes des in
        let width = Int32.to_int (Deserializer.read_u32 des) in
        let height = Int32.to_int (Deserializer.read_u32 des) in
        Image (data, width, height)
    | _ -> failwith "Unknown variant"
  in
  Deserializer.leave_enum des;
  result
```

## Error Handling

Errors are raised as `Bcs_error` exceptions:

```ocaml
open Bcs

try
  let des = Deserializer.create data in
  let value = Deserializer.read_u64 des in
  (* ... *)
with Bcs_error err ->
  Printf.eprintf "BCS error: %s\n" (error_message err);
  match err with
  | Unexpected_eof -> (* Handle EOF *)
  | Invalid_utf8 -> (* Handle invalid UTF-8 *)
  | _ -> raise (Bcs_error err)
```

## ULEB128 Utilities

Direct access to ULEB128 encoding/decoding:

```ocaml
open Bcs

(* Encode *)
let encoded = Uleb128.encode 300 in

(* Decode *)
let value, bytes_read = Uleb128.decode encoded 0 in

(* Get encoded size *)
let size = Uleb128.encoded_size 300 in  (* 2 *)
```

## Hex Utilities

```ocaml
open Bcs

(* Bytes to hex *)
let hex = bytes_to_hex (Bytes.of_string "\x01\x02\xab") in  (* "0102ab" *)

(* Hex to bytes *)
let bytes = hex_to_bytes "0102ab" in
```

## Development

### Prerequisites

- OCaml 4.14+
- Dune 3.0+
- opam (recommended)

### Building

```bash
make deps      # Install dependencies
make build     # Build library
make test      # Run tests
make docs      # Generate documentation
```

### Code Style

```bash
make format      # Format code with ocamlformat
make format-check  # Check formatting
make lint        # Run linter
```

## License

Apache-2.0
