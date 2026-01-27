defmodule BcsTest do
  use ExUnit.Case, async: true
  doctest Bcs.Uleb128
  doctest Bcs.Serializer
  doctest Bcs.Deserializer

  alias Bcs.{Deserializer, Error, Serializer, Uleb128}

  # Load test vectors
  @test_vectors_path System.get_env("TEST_VECTORS", "../../test-vectors")
  @external_resource Path.join(@test_vectors_path, "bcs-comprehensive.json")

  @test_vectors (
                  path = Path.join(@test_vectors_path, "bcs-comprehensive.json")

                  if File.exists?(path) do
                    path
                    |> File.read!()
                    |> Jason.decode!()
                  else
                    %{}
                  end
                )

  defp hex_to_bytes(hex) when is_binary(hex) do
    # Handle odd-length hex strings by padding with leading zero
    padded_hex = if rem(String.length(hex), 2) == 1, do: "0" <> hex, else: hex
    Base.decode16!(padded_hex, case: :lower)
  end

  # ==========================================================================
  # BOOLEAN TESTS
  # ==========================================================================

  describe "boolean serialization" do
    test "serialize true" do
      assert Serializer.write_bool(<<>>, true) == <<1>>
    end

    test "serialize false" do
      assert Serializer.write_bool(<<>>, false) == <<0>>
    end

    test "deserialize true" do
      assert Deserializer.read_bool!(<<1>>) == {true, <<>>}
    end

    test "deserialize false" do
      assert Deserializer.read_bool!(<<0>>) == {false, <<>>}
    end

    test "reject invalid boolean 0x02" do
      assert {:error, %Error{type: :invalid_boolean}} = Deserializer.read_bool(<<2>>)
    end

    test "reject invalid boolean 0xff" do
      assert {:error, %Error{type: :invalid_boolean}} = Deserializer.read_bool(<<0xFF>>)
    end
  end

  # ==========================================================================
  # UNSIGNED INTEGER TESTS
  # ==========================================================================

  describe "u8 serialization" do
    test_cases = get_in(@test_vectors, ["primitives", "u8", "valid"]) || []

    for test_case <- test_cases do
      test_case_escaped = Macro.escape(test_case)

      test "serialize #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        value = test_case["value"]
        expected = hex_to_bytes(test_case["bcs_hex"])
        assert Serializer.write_u8(<<>>, value) == expected
      end

      test "deserialize #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        data = hex_to_bytes(test_case["bcs_hex"])
        expected = test_case["value"]
        assert Deserializer.read_u8!(data) == {expected, <<>>}
      end
    end
  end

  describe "u16 serialization" do
    test_cases = get_in(@test_vectors, ["primitives", "u16", "valid"]) || []

    for test_case <- test_cases do
      test_case_escaped = Macro.escape(test_case)

      test "serialize #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        value = test_case["value"]
        expected = hex_to_bytes(test_case["bcs_hex"])
        assert Serializer.write_u16(<<>>, value) == expected
      end

      test "deserialize #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        data = hex_to_bytes(test_case["bcs_hex"])
        expected = test_case["value"]
        assert Deserializer.read_u16!(data) == {expected, <<>>}
      end
    end
  end

  describe "u32 serialization" do
    test_cases = get_in(@test_vectors, ["primitives", "u32", "valid"]) || []

    for test_case <- test_cases do
      test_case_escaped = Macro.escape(test_case)

      test "serialize #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        value = test_case["value"]
        expected = hex_to_bytes(test_case["bcs_hex"])
        assert Serializer.write_u32(<<>>, value) == expected
      end

      test "deserialize #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        data = hex_to_bytes(test_case["bcs_hex"])
        expected = test_case["value"]
        assert Deserializer.read_u32!(data) == {expected, <<>>}
      end
    end
  end

  describe "u64 serialization" do
    test_cases = get_in(@test_vectors, ["primitives", "u64", "valid"]) || []

    for test_case <- test_cases do
      test_case_escaped = Macro.escape(test_case)

      test "serialize #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        value = String.to_integer(test_case["value"])
        expected = hex_to_bytes(test_case["bcs_hex"])
        assert Serializer.write_u64(<<>>, value) == expected
      end

      test "deserialize #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        data = hex_to_bytes(test_case["bcs_hex"])
        expected = String.to_integer(test_case["value"])
        assert Deserializer.read_u64!(data) == {expected, <<>>}
      end
    end
  end

  describe "u128 serialization" do
    test_cases = get_in(@test_vectors, ["primitives", "u128", "valid"]) || []

    for test_case <- test_cases do
      test_case_escaped = Macro.escape(test_case)

      test "serialize #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        value = String.to_integer(test_case["value"])
        expected = hex_to_bytes(test_case["bcs_hex"])
        assert Serializer.write_u128(<<>>, value) == expected
      end

      test "deserialize #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        data = hex_to_bytes(test_case["bcs_hex"])
        expected = String.to_integer(test_case["value"])
        assert Deserializer.read_u128!(data) == {expected, <<>>}
      end
    end
  end

  describe "u256 serialization" do
    test_cases = get_in(@test_vectors, ["primitives", "u256", "valid"]) || []

    for test_case <- test_cases do
      test_case_escaped = Macro.escape(test_case)

      test "serialize #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        value = String.to_integer(test_case["value"])
        expected = hex_to_bytes(test_case["bcs_hex"])
        assert Serializer.write_u256(<<>>, value) == expected
      end

      test "deserialize #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        data = hex_to_bytes(test_case["bcs_hex"])
        expected = String.to_integer(test_case["value"])
        assert Deserializer.read_u256!(data) == {expected, <<>>}
      end
    end
  end

  # ==========================================================================
  # SIGNED INTEGER TESTS
  # ==========================================================================

  describe "i8 serialization" do
    test_cases = get_in(@test_vectors, ["primitives", "i8", "valid"]) || []

    for test_case <- test_cases do
      test_case_escaped = Macro.escape(test_case)

      test "serialize #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        value = test_case["value"]
        expected = hex_to_bytes(test_case["bcs_hex"])
        assert Serializer.write_i8(<<>>, value) == expected
      end

      test "deserialize #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        data = hex_to_bytes(test_case["bcs_hex"])
        expected = test_case["value"]
        assert Deserializer.read_i8!(data) == {expected, <<>>}
      end
    end
  end

  describe "i16 serialization" do
    test_cases = get_in(@test_vectors, ["primitives", "i16", "valid"]) || []

    for test_case <- test_cases do
      test_case_escaped = Macro.escape(test_case)

      test "serialize #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        value = test_case["value"]
        expected = hex_to_bytes(test_case["bcs_hex"])
        assert Serializer.write_i16(<<>>, value) == expected
      end

      test "deserialize #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        data = hex_to_bytes(test_case["bcs_hex"])
        expected = test_case["value"]
        assert Deserializer.read_i16!(data) == {expected, <<>>}
      end
    end
  end

  describe "i32 serialization" do
    test_cases = get_in(@test_vectors, ["primitives", "i32", "valid"]) || []

    for test_case <- test_cases do
      test_case_escaped = Macro.escape(test_case)

      test "serialize #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        value = test_case["value"]
        expected = hex_to_bytes(test_case["bcs_hex"])
        assert Serializer.write_i32(<<>>, value) == expected
      end

      test "deserialize #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        data = hex_to_bytes(test_case["bcs_hex"])
        expected = test_case["value"]
        assert Deserializer.read_i32!(data) == {expected, <<>>}
      end
    end
  end

  describe "i64 serialization" do
    test_cases = get_in(@test_vectors, ["primitives", "i64", "valid"]) || []

    for test_case <- test_cases do
      test_case_escaped = Macro.escape(test_case)

      test "serialize #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        value = String.to_integer(test_case["value"])
        expected = hex_to_bytes(test_case["bcs_hex"])
        assert Serializer.write_i64(<<>>, value) == expected
      end

      test "deserialize #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        data = hex_to_bytes(test_case["bcs_hex"])
        expected = String.to_integer(test_case["value"])
        assert Deserializer.read_i64!(data) == {expected, <<>>}
      end
    end
  end

  # ==========================================================================
  # ULEB128 TESTS
  # ==========================================================================

  describe "ULEB128 encoding" do
    test_cases = get_in(@test_vectors, ["uleb128", "valid"]) || []

    for test_case <- test_cases do
      test_case_escaped = Macro.escape(test_case)

      test "encode #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        value = test_case["value"]
        expected = hex_to_bytes(test_case["bcs_hex"])
        assert Uleb128.encode(value) == expected
      end

      test "decode #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        data = hex_to_bytes(test_case["bcs_hex"])
        expected = test_case["value"]
        assert Uleb128.decode!(data) == {expected, <<>>}
      end
    end

    test "reject non-canonical encoding" do
      # 0x80 0x00 is non-canonical for 0
      assert {:error, %Error{type: :non_canonical_uleb128}} = Uleb128.decode(<<0x80, 0x00>>)
    end

    test "reject overflow" do
      # 6 bytes with continuation bits
      assert {:error, %Error{type: :uleb128_overflow}} =
               Uleb128.decode(<<0x80, 0x80, 0x80, 0x80, 0x80, 0x01>>)
    end
  end

  # ==========================================================================
  # STRING TESTS
  # ==========================================================================

  describe "string serialization" do
    test_cases = get_in(@test_vectors, ["strings", "valid"]) || []

    for test_case <- test_cases do
      test_case_escaped = Macro.escape(test_case)

      test "serialize #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        value = test_case["value"]
        expected = hex_to_bytes(test_case["bcs_hex"])
        assert Serializer.write_string(<<>>, value) == expected
      end

      test "deserialize #{test_case["name"]}" do
        test_case = unquote(test_case_escaped)
        data = hex_to_bytes(test_case["bcs_hex"])
        expected = test_case["value"]
        assert Deserializer.read_string!(data) == {expected, <<>>}
      end
    end

    test "reject invalid UTF-8 on deserialize" do
      # Length 1, byte 0xFF (invalid UTF-8)
      data = <<1, 0xFF>>
      assert {:error, %Error{type: :invalid_utf8}} = Deserializer.read_string(data)
    end

    test "reject invalid UTF-8 on serialize" do
      # Invalid UTF-8 binary (0xFF is never valid in UTF-8)
      invalid_binary = <<0xFF>>
      assert_raise Error, fn -> Serializer.write_string(<<>>, invalid_binary) end
    end
  end

  # ==========================================================================
  # MAP TESTS
  # ==========================================================================

  describe "map serialization" do
    test "serialize sorted map" do
      # Map with keys 1, 2, 3 (already sorted)
      data =
        Serializer.write_map(
          <<>>,
          %{1 => 10, 2 => 20},
          &Serializer.write_u8/2,
          &Serializer.write_u8/2
        )

      # Length 2, then (1, 10), (2, 20)
      assert data == <<2, 1, 10, 2, 20>>
    end

    test "deserialize valid map" do
      # Length 2, keys in sorted order: (1, 10), (2, 20)
      data = <<2, 1, 10, 2, 20>>

      {result, rest} =
        Deserializer.read_map!(data, &Deserializer.read_u8/1, &Deserializer.read_u8/1)

      assert result == %{1 => 10, 2 => 20}
      assert rest == <<>>
    end

    test "reject unsorted keys" do
      # Length 3, keys NOT sorted: (2, 20), (1, 10) - 2 > 1 is wrong order
      data = <<3, 2, 20, 1, 10>>

      assert {:error, %Error{type: :non_canonical_map}} =
               Deserializer.read_map(data, &Deserializer.read_u8/1, &Deserializer.read_u8/1)
    end

    test "reject duplicate keys" do
      # Length 2, duplicate key 1: (1, 10), (1, 10)
      data = <<2, 1, 10, 1, 10>>

      assert {:error, %Error{type: :non_canonical_map}} =
               Deserializer.read_map(data, &Deserializer.read_u8/1, &Deserializer.read_u8/1)
    end
  end

  # ==========================================================================
  # CONTAINER DEPTH TESTS
  # ==========================================================================

  describe "container depth" do
    test "allows up to 500 nested structs" do
      # Serialize 500 nested structs (at max depth)
      state =
        Enum.reduce(1..500, Serializer.new(), fn _, acc ->
          Serializer.enter_struct(acc)
        end)

      # Should succeed - we're at depth 500
      assert state.depth == 500
    end

    test "rejects exceeding 500 nested structs on serializer" do
      # First reach depth 500
      state =
        Enum.reduce(1..500, Serializer.new(), fn _, acc ->
          Serializer.enter_struct(acc)
        end)

      # 501st should fail
      assert_raise Error, fn ->
        Serializer.enter_struct(state)
      end
    end

    test "rejects exceeding 500 nested structs on deserializer" do
      # First reach depth 500
      state =
        Enum.reduce(1..500, Deserializer.new(<<>>), fn _, acc ->
          Deserializer.enter_struct(acc)
        end)

      # 501st should fail
      assert_raise Error, fn ->
        Deserializer.enter_struct(state)
      end
    end

    test "allows up to 500 nested enums" do
      # Serialize 500 nested enums - each enter_enum increments depth and writes variant index
      # We need data for this since enter_enum reads the variant index
      # For serializer, we can just check the depth tracking
      state =
        Enum.reduce(1..500, Serializer.new(), fn _, acc ->
          Serializer.enter_enum(acc, 0)
        end)

      # Should succeed - we're at depth 500
      assert state.depth == 500
    end

    test "rejects exceeding 500 nested enums on serializer" do
      # First reach depth 500
      state =
        Enum.reduce(1..500, Serializer.new(), fn _, acc ->
          Serializer.enter_enum(acc, 0)
        end)

      # 501st should fail
      assert_raise Error, fn ->
        Serializer.enter_enum(state, 0)
      end
    end
  end

  # ==========================================================================
  # OPTION TESTS
  # ==========================================================================

  describe "option serialization" do
    test "serialize None" do
      result = Serializer.write_option(<<>>, nil, &Serializer.write_u8/2)
      assert result == <<0>>
    end

    test "serialize Some(42)" do
      result = Serializer.write_option(<<>>, 42, &Serializer.write_u8/2)
      assert result == <<1, 42>>
    end

    test "deserialize None" do
      assert Deserializer.read_option!(<<0>>, &Deserializer.read_u8/1) == {nil, <<>>}
    end

    test "deserialize Some(42)" do
      assert Deserializer.read_option!(<<1, 42>>, &Deserializer.read_u8/1) == {42, <<>>}
    end

    test "reject invalid option tag" do
      assert {:error, %Error{type: :invalid_option}} =
               Deserializer.read_option(<<2>>, &Deserializer.read_u8/1)
    end
  end

  # ==========================================================================
  # VECTOR TESTS
  # ==========================================================================

  describe "vector serialization" do
    test "serialize empty vector" do
      result = Serializer.write_vector(<<>>, [], &Serializer.write_u8/2)
      assert result == <<0>>
    end

    test "serialize [1, 2, 3]" do
      result = Serializer.write_vector(<<>>, [1, 2, 3], &Serializer.write_u8/2)
      assert result == <<3, 1, 2, 3>>
    end

    test "deserialize empty vector" do
      assert Deserializer.read_vector!(<<0>>, &Deserializer.read_u8/1) == {[], <<>>}
    end

    test "deserialize [1, 2, 3]" do
      assert Deserializer.read_vector!(<<3, 1, 2, 3>>, &Deserializer.read_u8/1) == {[1, 2, 3], <<>>}
    end

    test "reject vector with length exceeding data" do
      assert {:error, %Error{type: :unexpected_eof}} =
               Deserializer.read_vector(<<5, 1, 2, 3>>, &Deserializer.read_u8/1)
    end
  end

  # ==========================================================================
  # ERROR CASE TESTS
  # ==========================================================================

  describe "error cases" do
    test "remaining input" do
      assert {:error, %Error{type: :remaining_input}} = Deserializer.check_end(<<0>>)
    end

    test "unexpected EOF on u64" do
      assert {:error, %Error{type: :unexpected_eof}} = Deserializer.read_u64(<<1, 2, 3>>)
    end

    test "unexpected EOF on empty input" do
      assert {:error, %Error{type: :unexpected_eof}} = Deserializer.read_u8(<<>>)
    end
  end

  # ==========================================================================
  # ROUND-TRIP TESTS
  # ==========================================================================

  describe "round-trip" do
    test "complex struct" do
      # Simulate a Transfer struct: sender (32 bytes), recipient (32 bytes), amount (u64)
      sender = :binary.copy(<<0>>, 31) <> <<1>>
      recipient = :binary.copy(<<0>>, 31) <> <<2>>
      amount = 1_000_000

      data =
        Serializer.new()
        |> Serializer.enter_struct("Transfer")
        |> Serializer.write_fixed_bytes(sender, 32)
        |> Serializer.write_fixed_bytes(recipient, 32)
        |> Serializer.write_u64(amount)
        |> Serializer.leave_struct()
        |> Serializer.to_bytes()

      state =
        data
        |> Deserializer.new()
        |> Deserializer.enter_struct("Transfer")

      {read_sender, state} = Deserializer.read_fixed_bytes!(state, 32)
      {read_recipient, state} = Deserializer.read_fixed_bytes!(state, 32)
      {read_amount, state} = Deserializer.read_u64!(state)
      state |> Deserializer.leave_struct() |> Deserializer.check_end!()

      assert read_sender == sender
      assert read_recipient == recipient
      assert read_amount == amount
    end

    test "nested vectors" do
      values = [[1, 2], [3, 4, 5]]

      data =
        Serializer.write_vector(<<>>, values, fn acc, inner ->
          Serializer.write_vector(acc, inner, &Serializer.write_u8/2)
        end)

      {result, rest} =
        Deserializer.read_vector!(data, fn d ->
          Deserializer.read_vector(d, &Deserializer.read_u8/1)
        end)

      Deserializer.check_end!(rest)
      assert result == values
    end
  end
end
