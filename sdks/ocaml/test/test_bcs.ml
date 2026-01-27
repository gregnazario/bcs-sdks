(** BCS Test Suite *)

open Bcs

(* ============================================================================
   Test Helpers
   ============================================================================ *)

let bytes_eq = Alcotest.testable (Fmt.of_to_string bytes_to_hex) Bytes.equal

let check_bytes msg expected actual = Alcotest.check bytes_eq msg expected actual

let check_raises msg f =
  try
    ignore (f ());
    Alcotest.fail (msg ^ ": expected exception")
  with Bcs_error _ -> ()

(* ============================================================================
   ULEB128 Tests
   ============================================================================ *)

let test_uleb128_encode_zero () =
  check_bytes "encode 0" (Bytes.of_string "\x00") (Uleb128.encode 0)

let test_uleb128_encode_127 () =
  check_bytes "encode 127" (Bytes.of_string "\x7f") (Uleb128.encode 127)

let test_uleb128_encode_128 () =
  check_bytes "encode 128" (Bytes.of_string "\x80\x01") (Uleb128.encode 128)

let test_uleb128_encode_300 () =
  check_bytes "encode 300" (Bytes.of_string "\xac\x02") (Uleb128.encode 300)

let test_uleb128_decode_zero () =
  let value, bytes_read = Uleb128.decode (Bytes.of_string "\x00") 0 in
  Alcotest.(check int) "value" 0 value;
  Alcotest.(check int) "bytes_read" 1 bytes_read

let test_uleb128_decode_128 () =
  let value, bytes_read = Uleb128.decode (Bytes.of_string "\x80\x01") 0 in
  Alcotest.(check int) "value" 128 value;
  Alcotest.(check int) "bytes_read" 2 bytes_read

let test_uleb128_reject_non_canonical () =
  check_raises "non-canonical" (fun () ->
      Uleb128.decode (Bytes.of_string "\x80\x00") 0)

let uleb128_tests =
  [
    ("encode zero", `Quick, test_uleb128_encode_zero);
    ("encode 127", `Quick, test_uleb128_encode_127);
    ("encode 128", `Quick, test_uleb128_encode_128);
    ("encode 300", `Quick, test_uleb128_encode_300);
    ("decode zero", `Quick, test_uleb128_decode_zero);
    ("decode 128", `Quick, test_uleb128_decode_128);
    ("reject non-canonical", `Quick, test_uleb128_reject_non_canonical);
  ]

(* ============================================================================
   Boolean Tests
   ============================================================================ *)

let test_bool_serialize_true () =
  let ser = Serializer.create () in
  Serializer.write_bool ser true;
  check_bytes "true" (Bytes.of_string "\x01") (Serializer.to_bytes ser)

let test_bool_serialize_false () =
  let ser = Serializer.create () in
  Serializer.write_bool ser false;
  check_bytes "false" (Bytes.of_string "\x00") (Serializer.to_bytes ser)

let test_bool_deserialize () =
  let des = Deserializer.create (Bytes.of_string "\x01\x00") in
  Alcotest.(check bool) "true" true (Deserializer.read_bool des);
  Alcotest.(check bool) "false" false (Deserializer.read_bool des)

let test_bool_invalid () =
  let des = Deserializer.create (Bytes.of_string "\x02") in
  check_raises "invalid boolean" (fun () -> Deserializer.read_bool des)

let bool_tests =
  [
    ("serialize true", `Quick, test_bool_serialize_true);
    ("serialize false", `Quick, test_bool_serialize_false);
    ("deserialize", `Quick, test_bool_deserialize);
    ("invalid value", `Quick, test_bool_invalid);
  ]

(* ============================================================================
   Integer Tests
   ============================================================================ *)

let test_u8_serialize () =
  let ser = Serializer.create () in
  Serializer.write_u8 ser 42;
  check_bytes "u8" (Bytes.of_string "\x2a") (Serializer.to_bytes ser)

let test_u16_serialize () =
  let ser = Serializer.create () in
  Serializer.write_u16 ser 0x1234;
  check_bytes "u16" (Bytes.of_string "\x34\x12") (Serializer.to_bytes ser)

let test_u32_serialize () =
  let ser = Serializer.create () in
  Serializer.write_u32 ser 0x12345678l;
  check_bytes "u32" (Bytes.of_string "\x78\x56\x34\x12") (Serializer.to_bytes ser)

let test_u64_serialize () =
  let ser = Serializer.create () in
  Serializer.write_u64 ser 0x123456789ABCDEF0L;
  check_bytes "u64"
    (Bytes.of_string "\xf0\xde\xbc\x9a\x78\x56\x34\x12")
    (Serializer.to_bytes ser)

let test_i8_serialize () =
  let ser = Serializer.create () in
  Serializer.write_i8 ser (-1);
  check_bytes "i8" (Bytes.of_string "\xff") (Serializer.to_bytes ser)

let test_i16_serialize () =
  let ser = Serializer.create () in
  Serializer.write_i16 ser (-32768);
  check_bytes "i16" (Bytes.of_string "\x00\x80") (Serializer.to_bytes ser)

let test_integer_deserialize () =
  let des = Deserializer.create (Bytes.of_string "\x2a\x34\x12") in
  Alcotest.(check int) "u8" 42 (Deserializer.read_u8 des);
  Alcotest.(check int) "u16" 0x1234 (Deserializer.read_u16 des)

let test_signed_integer_deserialize () =
  let des = Deserializer.create (Bytes.of_string "\xff\x00\x80") in
  Alcotest.(check int) "i8" (-1) (Deserializer.read_i8 des);
  Alcotest.(check int) "i16" (-32768) (Deserializer.read_i16 des)

let integer_tests =
  [
    ("u8 serialize", `Quick, test_u8_serialize);
    ("u16 serialize", `Quick, test_u16_serialize);
    ("u32 serialize", `Quick, test_u32_serialize);
    ("u64 serialize", `Quick, test_u64_serialize);
    ("i8 serialize", `Quick, test_i8_serialize);
    ("i16 serialize", `Quick, test_i16_serialize);
    ("integer deserialize", `Quick, test_integer_deserialize);
    ("signed integer deserialize", `Quick, test_signed_integer_deserialize);
  ]

(* ============================================================================
   String Tests
   ============================================================================ *)

let test_string_serialize_empty () =
  let ser = Serializer.create () in
  Serializer.write_string ser "";
  check_bytes "empty" (Bytes.of_string "\x00") (Serializer.to_bytes ser)

let test_string_serialize_hello () =
  let ser = Serializer.create () in
  Serializer.write_string ser "hello";
  check_bytes "hello"
    (Bytes.of_string "\x05hello")
    (Serializer.to_bytes ser)

let test_string_deserialize () =
  let des =
    Deserializer.create (Bytes.of_string "\x05hello")
  in
  Alcotest.(check string) "hello" "hello" (Deserializer.read_string des)

let test_string_roundtrip_unicode () =
  let original = "Hello, 世界! 🌍" in
  let ser = Serializer.create () in
  Serializer.write_string ser original;
  let des = Deserializer.create (Serializer.to_bytes ser) in
  Alcotest.(check string) "unicode" original (Deserializer.read_string des)

let string_tests =
  [
    ("serialize empty", `Quick, test_string_serialize_empty);
    ("serialize hello", `Quick, test_string_serialize_hello);
    ("deserialize", `Quick, test_string_deserialize);
    ("roundtrip unicode", `Quick, test_string_roundtrip_unicode);
  ]

(* ============================================================================
   Option Tests
   ============================================================================ *)

let test_option_some () =
  let ser = Serializer.create () in
  Serializer.write_option ser (Some 42) (fun s v -> Serializer.write_u8 s v);
  check_bytes "some" (Bytes.of_string "\x01\x2a") (Serializer.to_bytes ser)

let test_option_none () =
  let ser = Serializer.create () in
  Serializer.write_option ser None (fun s v -> Serializer.write_u8 s v);
  check_bytes "none" (Bytes.of_string "\x00") (Serializer.to_bytes ser)

let test_option_deserialize_some () =
  let des = Deserializer.create (Bytes.of_string "\x01\x2a") in
  let result = Deserializer.read_option des Deserializer.read_u8 in
  Alcotest.(check (option int)) "some" (Some 42) result

let test_option_deserialize_none () =
  let des = Deserializer.create (Bytes.of_string "\x00") in
  let result = Deserializer.read_option des Deserializer.read_u8 in
  Alcotest.(check (option int)) "none" None result

let test_option_invalid_tag () =
  let des = Deserializer.create (Bytes.of_string "\x02") in
  check_raises "invalid tag" (fun () ->
      Deserializer.read_option des Deserializer.read_u8)

let option_tests =
  [
    ("serialize some", `Quick, test_option_some);
    ("serialize none", `Quick, test_option_none);
    ("deserialize some", `Quick, test_option_deserialize_some);
    ("deserialize none", `Quick, test_option_deserialize_none);
    ("invalid tag", `Quick, test_option_invalid_tag);
  ]

(* ============================================================================
   List Tests
   ============================================================================ *)

let test_list_empty () =
  let ser = Serializer.create () in
  Serializer.write_list ser [] (fun s v -> Serializer.write_u8 s v);
  check_bytes "empty" (Bytes.of_string "\x00") (Serializer.to_bytes ser)

let test_list_u8 () =
  let ser = Serializer.create () in
  Serializer.write_list ser [ 1; 2; 3 ] (fun s v -> Serializer.write_u8 s v);
  check_bytes "list" (Bytes.of_string "\x03\x01\x02\x03") (Serializer.to_bytes ser)

let test_list_deserialize () =
  let des = Deserializer.create (Bytes.of_string "\x03\x01\x02\x03") in
  let result = Deserializer.read_list des Deserializer.read_u8 in
  Alcotest.(check (list int)) "list" [ 1; 2; 3 ] result

let list_tests =
  [
    ("serialize empty", `Quick, test_list_empty);
    ("serialize u8 list", `Quick, test_list_u8);
    ("deserialize", `Quick, test_list_deserialize);
  ]

(* ============================================================================
   Error Handling Tests
   ============================================================================ *)

let test_unexpected_eof () =
  let des = Deserializer.create (Bytes.of_string "\x01") in
  check_raises "unexpected eof" (fun () -> Deserializer.read_u16 des)

let test_remaining_input () =
  let des = Deserializer.create (Bytes.of_string "\x01\x02") in
  ignore (Deserializer.read_u8 des);
  check_raises "remaining input" (fun () -> Deserializer.check_end des)

let error_tests =
  [
    ("unexpected eof", `Quick, test_unexpected_eof);
    ("remaining input", `Quick, test_remaining_input);
  ]

(* ============================================================================
   Round-trip Tests
   ============================================================================ *)

let test_roundtrip_u64 () =
  let original = 0x123456789ABCDEF0L in
  let ser = Serializer.create () in
  Serializer.write_u64 ser original;
  let des = Deserializer.create (Serializer.to_bytes ser) in
  let result = Deserializer.read_u64 des in
  Alcotest.(check int64) "u64" original result

let test_roundtrip_complex () =
  let ser = Serializer.create () in
  Serializer.write_u8 ser 42;
  Serializer.write_string ser "test";
  Serializer.write_list ser [ 100; 200; 300 ] (fun s v -> Serializer.write_u16 s v);

  let des = Deserializer.create (Serializer.to_bytes ser) in
  Alcotest.(check int) "u8" 42 (Deserializer.read_u8 des);
  Alcotest.(check string) "string" "test" (Deserializer.read_string des);
  let vec = Deserializer.read_list des Deserializer.read_u16 in
  Alcotest.(check (list int)) "list" [ 100; 200; 300 ] vec;
  Deserializer.check_end des

let roundtrip_tests =
  [
    ("u64", `Quick, test_roundtrip_u64);
    ("complex", `Quick, test_roundtrip_complex);
  ]

(* ============================================================================
   Hex Utilities Tests
   ============================================================================ *)

let test_bytes_to_hex () =
  let bytes = Bytes.of_string "\x01\x02\xab\xcd" in
  Alcotest.(check string) "hex" "0102abcd" (bytes_to_hex bytes)

let test_hex_to_bytes () =
  let bytes = hex_to_bytes "0102abcd" in
  check_bytes "bytes" (Bytes.of_string "\x01\x02\xab\xcd") bytes

let hex_tests =
  [
    ("bytes to hex", `Quick, test_bytes_to_hex);
    ("hex to bytes", `Quick, test_hex_to_bytes);
  ]

(* ============================================================================
   Container Depth Tests
   ============================================================================ *)

let test_depth_allows_500 () =
  let ser = Serializer.create () in
  for _ = 1 to 500 do
    Serializer.enter_struct ser
  done
(* Should succeed at depth 500 *)

let test_depth_rejects_501 () =
  let ser = Serializer.create () in
  for _ = 1 to 500 do
    Serializer.enter_struct ser
  done;
  check_raises "501st struct" (fun () -> Serializer.enter_struct ser)

let depth_tests =
  [
    ("allows 500 nested structs", `Quick, test_depth_allows_500);
    ("rejects 501 nested structs", `Quick, test_depth_rejects_501);
  ]

(* ============================================================================
   Main
   ============================================================================ *)

let () =
  Alcotest.run "BCS"
    [
      ("ULEB128", uleb128_tests);
      ("Boolean", bool_tests);
      ("Integer", integer_tests);
      ("String", string_tests);
      ("Option", option_tests);
      ("List", list_tests);
      ("Error handling", error_tests);
      ("Round-trip", roundtrip_tests);
      ("Hex utilities", hex_tests);
      ("Container depth", depth_tests);
    ]
