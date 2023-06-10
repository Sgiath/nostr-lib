defmodule Nostr.TLV.Encoder do
  @moduledoc false

  import Bitwise

  @compile {:inline, encode_tag: 1}

  def encode(tlv) do
    encode_tag(tlv.tag) <> encode_lv(tlv.indefinite_length, tlv.value)
  end

  defp encode_tag(tag), do: :binary.encode_unsigned(tag)

  defp encode_lv(_indefinite_length, value) when is_binary(value) do
    encode_length(value) <> value
  end

  defp encode_lv(true, tlvs) when is_list(tlvs) do
    <<0x80>> <> encode_tlvs(tlvs) <> <<0x00, 0x00>>
  end

  defp encode_lv(false, tlvs) when is_list(tlvs) do
    encode_lv(false, encode_tlvs(tlvs))
  end

  defp encode_tlvs(tlvs) do
    Enum.reduce(tlvs, <<>>, fn tlv, acc -> acc <> encode(tlv) end)
  end

  defp encode_length(value) do
    value_length = byte_size(value)
    encoded_length = :binary.encode_unsigned(value_length)

    if value_length < 0x80 do
      encoded_length
    else
      len_of_len = byte_size(encoded_length) ||| 0x80
      <<len_of_len::unsigned-big-integer-size(8)>> <> encoded_length
    end
  end
end
