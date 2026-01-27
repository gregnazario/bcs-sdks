defmodule Bcs.Error do
  @moduledoc """
  BCS error types.
  """

  defexception [:message, :type]

  @type error_type ::
          :unexpected_eof
          | :invalid_boolean
          | :invalid_option
          | :invalid_utf8
          | :non_canonical_uleb128
          | :uleb128_overflow
          | :exceeded_max_length
          | :exceeded_container_depth
          | :remaining_input
          | :non_canonical_map
          | :unknown_variant
          | :not_supported
          | :value_out_of_range

  @type t :: %__MODULE__{
          message: String.t(),
          type: error_type()
        }

  @doc """
  Create an unexpected EOF error.
  """
  @spec unexpected_eof() :: t()
  def unexpected_eof do
    %__MODULE__{message: "Unexpected end of input", type: :unexpected_eof}
  end

  @spec unexpected_eof(non_neg_integer(), non_neg_integer()) :: t()
  def unexpected_eof(expected, available) do
    %__MODULE__{
      message: "Unexpected end of input: expected #{expected} bytes, got #{available}",
      type: :unexpected_eof
    }
  end

  @doc """
  Create an invalid boolean error.
  """
  @spec invalid_boolean(non_neg_integer()) :: t()
  def invalid_boolean(value) do
    hex = Integer.to_string(value, 16) |> String.pad_leading(2, "0")

    %__MODULE__{
      message: "Invalid boolean value: 0x#{hex} (expected 0x00 or 0x01)",
      type: :invalid_boolean
    }
  end

  @doc """
  Create an invalid option error.
  """
  @spec invalid_option(non_neg_integer()) :: t()
  def invalid_option(value) do
    hex = Integer.to_string(value, 16) |> String.pad_leading(2, "0")

    %__MODULE__{
      message: "Invalid option tag: 0x#{hex} (expected 0x00 or 0x01)",
      type: :invalid_option
    }
  end

  @doc """
  Create an invalid UTF-8 error.
  """
  @spec invalid_utf8(String.t()) :: t()
  def invalid_utf8(reason \\ "Invalid UTF-8 encoding") do
    %__MODULE__{message: reason, type: :invalid_utf8}
  end

  @doc """
  Create a non-canonical ULEB128 error.
  """
  @spec non_canonical_uleb128() :: t()
  def non_canonical_uleb128 do
    %__MODULE__{
      message: "Non-canonical ULEB128 encoding (trailing zero bytes)",
      type: :non_canonical_uleb128
    }
  end

  @doc """
  Create a ULEB128 overflow error.
  """
  @spec uleb128_overflow() :: t()
  def uleb128_overflow do
    %__MODULE__{
      message: "ULEB128 value overflow (exceeds u32 max)",
      type: :uleb128_overflow
    }
  end

  @doc """
  Create an exceeded max length error.
  """
  @spec exceeded_max_length(non_neg_integer()) :: t()
  def exceeded_max_length(length) do
    %__MODULE__{
      message: "Sequence length #{length} exceeds maximum allowed (2^31 - 1)",
      type: :exceeded_max_length
    }
  end

  @doc """
  Create an exceeded container depth error.
  """
  @spec exceeded_container_depth(String.t()) :: t()
  def exceeded_container_depth(container \\ "") do
    msg =
      if container == "" do
        "Exceeded maximum container depth (500)"
      else
        "Exceeded maximum container depth (500) while entering #{container}"
      end

    %__MODULE__{message: msg, type: :exceeded_container_depth}
  end

  @doc """
  Create a remaining input error.
  """
  @spec remaining_input(non_neg_integer()) :: t()
  def remaining_input(remaining) do
    %__MODULE__{
      message: "Remaining input after deserialization: #{remaining} bytes",
      type: :remaining_input
    }
  end

  @doc """
  Create a non-canonical map error.
  """
  @spec non_canonical_map(String.t()) :: t()
  def non_canonical_map(reason \\ "keys not sorted or contain duplicates") do
    %__MODULE__{
      message: "Non-canonical map: #{reason}",
      type: :non_canonical_map
    }
  end

  @doc """
  Create an unknown variant error.
  """
  @spec unknown_variant(non_neg_integer(), non_neg_integer()) :: t()
  def unknown_variant(index, max_index) do
    %__MODULE__{
      message: "Unknown enum variant index: #{index} (max: #{max_index})",
      type: :unknown_variant
    }
  end

  @doc """
  Create a not supported error.
  """
  @spec not_supported(String.t()) :: t()
  def not_supported(type_name) do
    %__MODULE__{
      message: "Type not supported: #{type_name}",
      type: :not_supported
    }
  end

  @doc """
  Create a value out of range error.
  """
  @spec value_out_of_range(String.t(), integer()) :: t()
  def value_out_of_range(type_name, value) do
    %__MODULE__{
      message: "#{type_name} value out of range: #{value}",
      type: :value_out_of_range
    }
  end
end
