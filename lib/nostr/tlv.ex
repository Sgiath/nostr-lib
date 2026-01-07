defmodule Nostr.TLV do
  @moduledoc """
  Provides functions to decode, encode and work with ASN.1 BER-TLV structures. It supports tags
  encoded on multiple bytes, length encoded on multiple bytes, indefinite length and both
  primitive and constructed TLVs.
  """

  @typedoc """
  Represents a BER-TLV structure. The `tag` is represented as an integer and header bits are not
  separated from the tag. This is to accommodate common usages of the encoding. Primitive TLVs
  have a binary `value`, while constructed have a list of TLVs. The `indefinite_length` field is
  set by the decoder to reflect the original byte representation and also serves as instruction to
  the encoder on how to encode the length.
  """
  @type t() :: %__MODULE__{tag: integer(), value: binary() | [t()], indefinite_length: boolean()}
  defstruct [:tag, :value, indefinite_length: false]

  @doc """
  Decodes (recursively) the first binary encoded TLV in the given binary and returns a tuple with
  the parsed TLV structure and the remaining data as a binary in the form
  `{parsed_tlv, remaining_data}`. On error it returns the atom `:no_tlv`.

  The decoder tolerates lengths encoded on more bytes than strictly needed, although the ASN.1
  specification require encoders to always generate the shortest possible encoding.

  ## Examples

      # Primitive TLV + data after its end
      iex> Nostr.TLV.decode(<<0x80, 0x02, 0xCA, 0xFE, 0xAA, 0xBB>>)
      {%Nostr.TLV{indefinite_length: false, tag: 0x80, value: <<0xCA, 0xFE>>}, <<0xAA, 0xBB>>}

      # Constructed TLV
      iex> Nostr.TLV.decode(<<0xE0, 0x03, 0x80, 0x01, 0xAA>>)
      {%Nostr.TLV{indefinite_length: false, tag: 0xE0, value:
        [%Nostr.TLV{indefinite_length: false, tag: 0x80, value: <<0xAA>>}]
      }, ""}

      # Malformed TLV
      iex> Nostr.TLV.decode(<<0x80, 0x02, 0x00>>)
      :no_tlv

  """
  @spec decode(binary()) :: {t(), binary()} | :no_tlv
  defdelegate decode(tlv), to: __MODULE__.Decoder

  @doc """
  Encodes (recursively) the given TLV structure and returns its binary representation according to
  the BER-TLV specifications.

  If `indefinite_length` is set to `true` and the TLV is a constructed one, indefinite length
  encoding will be use. For primitive TLVs this field will be ignored, since for primitive TLVs
  only definite length is allowed.

  The primitive/constructed bit of the `tag` field will not be checked for consistency with the
  `value` field.

  ## Examples

      # Primitive TLV
      iex> Nostr.TLV.encode(%Nostr.TLV{tag: 0x80, value: <<0xAA, 0xBB>>})
      <<0x80, 0x02, 0xAA, 0xBB>>

      # Constructed TLV
      iex> Nostr.TLV.encode(%Nostr.TLV{tag: 0xE0, value: [%Nostr.TLV{tag: 0x80, value: <<0xAA>>}]})
      <<0xE0, 0x03, 0x80, 0x01, 0xAA>>

  """
  @spec encode(t()) :: binary()
  defdelegate encode(tlv), to: __MODULE__.Encoder
end
