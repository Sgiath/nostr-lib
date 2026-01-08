defmodule Nostr.FilterTest do
  use ExUnit.Case, async: true

  alias Nostr.Test.Fixtures

  doctest Nostr.Filter

  describe "parse/1" do
    test "parses filter with all fields" do
      raw = %{
        ids: ["id1", "id2"],
        authors: [Fixtures.pubkey()],
        kinds: [1, 2, 3],
        "#e": ["event_id"],
        "#p": ["pubkey"],
        "#a": ["address"],
        "#d": ["identifier"],
        since: 1_704_067_200,
        until: 1_704_153_600,
        limit: 100,
        search: "query"
      }

      filter = Nostr.Filter.parse(raw)

      assert filter.ids == ["id1", "id2"]
      assert filter.authors == [Fixtures.pubkey()]
      assert filter.kinds == [1, 2, 3]
      assert filter."#e" == ["event_id"]
      assert filter."#p" == ["pubkey"]
      assert filter."#a" == ["address"]
      assert filter."#d" == ["identifier"]
      assert filter.since == ~U[2024-01-01 00:00:00Z]
      assert filter.until == ~U[2024-01-02 00:00:00Z]
      assert filter.limit == 100
      assert filter.search == "query"
    end

    test "parses filter with minimal fields" do
      raw = %{kinds: [1]}
      filter = Nostr.Filter.parse(raw)

      assert filter.kinds == [1]
      assert filter.ids == nil
      assert filter.authors == nil
      assert filter.since == nil
      assert filter.until == nil
      assert filter.limit == nil
    end

    test "parses empty filter" do
      raw = %{}
      filter = Nostr.Filter.parse(raw)

      assert %Nostr.Filter{} = filter
    end

    test "converts unix timestamps to DateTime" do
      raw = %{since: 0, until: 1_000_000_000}
      filter = Nostr.Filter.parse(raw)

      assert filter.since == ~U[1970-01-01 00:00:00Z]
      assert filter.until == ~U[2001-09-09 01:46:40Z]
    end

    test "parses filter with tag filters" do
      raw = %{
        "#e": ["event1", "event2"],
        "#p": ["pubkey1"]
      }

      filter = Nostr.Filter.parse(raw)
      assert filter."#e" == ["event1", "event2"]
      assert filter."#p" == ["pubkey1"]
    end

    test "parses filter with arbitrary single-letter tag filters (NIP-01)" do
      raw = %{
        "#t" => ["nostr", "bitcoin"],
        "#g" => ["u4pruydqqvj"],
        "#r" => ["https://example.com"]
      }

      filter = Nostr.Filter.parse(raw)

      assert filter.tags == %{
               "#t" => ["nostr", "bitcoin"],
               "#g" => ["u4pruydqqvj"],
               "#r" => ["https://example.com"]
             }
    end

    test "parses filter with mixed known and arbitrary tags" do
      raw = %{
        "kinds" => [1],
        "#e" => ["event1"],
        "#t" => ["tag1"]
      }

      filter = Nostr.Filter.parse(raw)
      assert filter.kinds == [1]
      assert filter."#e" == ["event1"]
      assert filter.tags == %{"#t" => ["tag1"]}
    end

    test "ignores multi-letter tag keys" do
      raw = %{"#tag" => ["value"], "kinds" => [1]}
      filter = Nostr.Filter.parse(raw)

      assert filter.kinds == [1]
      assert filter.tags == nil
    end
  end

  describe "JSON encoding" do
    test "encodes filter to JSON" do
      filter = %Nostr.Filter{
        kinds: [1, 2],
        limit: 10
      }

      json = JSON.encode!(filter)
      decoded = JSON.decode!(json)

      assert decoded["kinds"] == [1, 2]
      assert decoded["limit"] == 10
      refute Map.has_key?(decoded, "ids")
      refute Map.has_key?(decoded, "authors")
    end

    test "encodes timestamps as unix integers" do
      filter = %Nostr.Filter{
        since: ~U[2024-01-01 00:00:00Z],
        until: ~U[2024-01-02 00:00:00Z]
      }

      json = JSON.encode!(filter)
      decoded = JSON.decode!(json)

      assert decoded["since"] == 1_704_067_200
      assert decoded["until"] == 1_704_153_600
    end

    test "omits nil fields from JSON" do
      filter = %Nostr.Filter{kinds: [1]}
      json = JSON.encode!(filter)
      decoded = JSON.decode!(json)

      assert Map.keys(decoded) == ["kinds"]
    end

    test "encodes tag filters" do
      filter = %Nostr.Filter{
        "#e": ["event1"],
        "#p": ["pubkey1"]
      }

      json = JSON.encode!(filter)
      decoded = JSON.decode!(json)

      assert decoded["#e"] == ["event1"]
      assert decoded["#p"] == ["pubkey1"]
    end

    test "encodes arbitrary single-letter tag filters" do
      filter = %Nostr.Filter{
        kinds: [1],
        tags: %{"#t" => ["nostr"], "#g" => ["geohash"]}
      }

      json = JSON.encode!(filter)
      decoded = JSON.decode!(json)

      assert decoded["kinds"] == [1]
      assert decoded["#t"] == ["nostr"]
      assert decoded["#g"] == ["geohash"]
      refute Map.has_key?(decoded, "tags")
    end
  end

  describe "roundtrip" do
    test "parse and encode arbitrary tags" do
      raw = %{"kinds" => [1], "#t" => ["nostr"], "#r" => ["url"]}
      filter = Nostr.Filter.parse(raw)
      json = JSON.encode!(filter)
      decoded = JSON.decode!(json)

      assert decoded["kinds"] == [1]
      assert decoded["#t"] == ["nostr"]
      assert decoded["#r"] == ["url"]
    end
  end
end
