defmodule Nostr.TLVTest do
  use ExUnit.Case, async: true

  doctest Nostr.TLV

  describe "encode/1 and decode/1" do
    test "roundtrip for primitive TLV" do
      tlv = %Nostr.TLV{tag: 0x80, value: <<1, 2, 3, 4>>}
      encoded = Nostr.TLV.encode(tlv)
      {decoded, ""} = Nostr.TLV.decode(encoded)
      assert decoded == tlv
    end

    test "roundtrip for constructed TLV" do
      inner = %Nostr.TLV{tag: 0x80, value: <<1, 2>>}
      tlv = %Nostr.TLV{tag: 0xE0, value: [inner]}
      encoded = Nostr.TLV.encode(tlv)
      {decoded, ""} = Nostr.TLV.decode(encoded)
      assert decoded == tlv
    end

    test "roundtrip for nested constructed TLV" do
      inner1 = %Nostr.TLV{tag: 0x80, value: <<1>>}
      inner2 = %Nostr.TLV{tag: 0x81, value: <<2>>}
      middle = %Nostr.TLV{tag: 0xE0, value: [inner1, inner2]}
      tlv = %Nostr.TLV{tag: 0xE1, value: [middle]}
      encoded = Nostr.TLV.encode(tlv)
      {decoded, ""} = Nostr.TLV.decode(encoded)
      assert decoded == tlv
    end

    test "handles empty primitive value" do
      tlv = %Nostr.TLV{tag: 0x80, value: <<>>}
      encoded = Nostr.TLV.encode(tlv)
      {decoded, ""} = Nostr.TLV.decode(encoded)
      assert decoded == tlv
    end

    test "decode returns :no_tlv for incomplete data" do
      # Tag byte only, no length
      assert :no_tlv = Nostr.TLV.decode(<<1>>)
    end

    test "decode returns remaining bytes" do
      tlv = %Nostr.TLV{tag: 0x80, value: <<1, 2>>}
      encoded = Nostr.TLV.encode(tlv)
      extra = <<99, 99>>
      {decoded, rest} = Nostr.TLV.decode(encoded <> extra)
      assert decoded == tlv
      assert rest == extra
    end
  end
end
