defmodule Nostr.Bolt11Test do
  use ExUnit.Case, async: true

  alias Nostr.Bolt11

  describe "decode/1" do
    test "returns error for invalid prefix" do
      # Invalid prefix should return error
      assert {:error, _reason} =
               Bolt11.decode(
                 "lnxx1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq5qw8xv"
               )
    end

    test "returns error for invalid bech32" do
      assert {:error, :invalid_bech32} = Bolt11.decode("notavalidinvoice")
    end

    test "returns error for empty string" do
      assert {:error, :invalid_bech32} = Bolt11.decode("")
    end
  end

  describe "amount_sats/1" do
    test "returns amount in satoshis" do
      invoice = %Bolt11{amount_msats: 1_000_000}
      assert Bolt11.amount_sats(invoice) == 1000
    end

    test "returns nil for invoice without amount" do
      invoice = %Bolt11{amount_msats: nil}
      assert Bolt11.amount_sats(invoice) == nil
    end

    test "rounds down fractional sats" do
      invoice = %Bolt11{amount_msats: 1500}
      assert Bolt11.amount_sats(invoice) == 1
    end
  end

  describe "amount_msats/1" do
    test "returns amount in millisatoshis" do
      invoice = %Bolt11{amount_msats: 1_000_000}
      assert Bolt11.amount_msats(invoice) == 1_000_000
    end

    test "returns nil for invoice without amount" do
      invoice = %Bolt11{amount_msats: nil}
      assert Bolt11.amount_msats(invoice) == nil
    end
  end

  describe "expired?/1" do
    test "returns true for expired invoice" do
      # Old timestamp
      invoice = %Bolt11{timestamp: 0, expiry: 3600}
      assert Bolt11.expired?(invoice) == true
    end

    test "returns false for fresh invoice" do
      now = DateTime.utc_now() |> DateTime.to_unix()
      invoice = %Bolt11{timestamp: now, expiry: 3600}
      assert Bolt11.expired?(invoice) == false
    end
  end

  describe "expires_at/1" do
    test "returns expiry datetime" do
      invoice = %Bolt11{timestamp: 1_700_000_000, expiry: 3600}
      expires = Bolt11.expires_at(invoice)
      # 1_700_000_000 + 3600 = 1_700_003_600
      assert DateTime.to_unix(expires) == 1_700_003_600
    end
  end

  describe "struct defaults" do
    test "has default expiry of 3600" do
      invoice = %Bolt11{}
      assert invoice.expiry == 3600
    end
  end
end
