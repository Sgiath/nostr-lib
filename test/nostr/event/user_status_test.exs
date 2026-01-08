defmodule Nostr.Event.UserStatusTest do
  use ExUnit.Case, async: true

  alias Nostr.Event
  alias Nostr.Event.UserStatus
  alias Nostr.Test.Fixtures

  describe "parse/1" do
    test "parses user status with all fields" do
      expiration = DateTime.to_unix(~U[2025-01-15 12:00:00Z])

      tags = [
        Nostr.Tag.create(:d, "general"),
        Nostr.Tag.create(:r, "https://nostr.world"),
        Nostr.Tag.create(:p, "pubkey123"),
        Nostr.Tag.create(:e, "event123"),
        Nostr.Tag.create(:a, "30023:author:article"),
        Nostr.Tag.create("expiration", Integer.to_string(expiration)),
        Nostr.Tag.create(:emoji, "wave", ["https://example.com/wave.png"])
      ]

      event = Fixtures.signed_event(kind: 30_315, content: "Working on nostr-lib", tags: tags)
      status = UserStatus.parse(event)

      assert %UserStatus{} = status
      assert status.status_type == "general"
      assert status.status == "Working on nostr-lib"
      assert status.url == "https://nostr.world"
      assert status.profile == "pubkey123"
      assert status.note == "event123"
      assert status.address == "30023:author:article"
      assert status.expiration == ~U[2025-01-15 12:00:00Z]
      assert status.emojis == %{"wave" => "https://example.com/wave.png"}
    end

    test "parses user status with minimal fields" do
      tags = [Nostr.Tag.create(:d, "music")]
      event = Fixtures.signed_event(kind: 30_315, content: "Song - Artist", tags: tags)
      status = UserStatus.parse(event)

      assert status.status_type == "music"
      assert status.status == "Song - Artist"
      assert status.url == nil
      assert status.profile == nil
      assert status.note == nil
      assert status.address == nil
      assert status.expiration == nil
      assert status.emojis == %{}
    end

    test "parses cleared status (empty content)" do
      tags = [Nostr.Tag.create(:d, "general")]
      event = Fixtures.signed_event(kind: 30_315, content: "", tags: tags)
      status = UserStatus.parse(event)

      assert status.status_type == "general"
      assert status.status == ""
    end

    test "handles missing d tag" do
      event = Fixtures.signed_event(kind: 30_315, content: "Test", tags: [])
      status = UserStatus.parse(event)

      assert status.status_type == ""
    end

    test "returns error for wrong kind" do
      event = Fixtures.signed_event(kind: 1, content: "Not a status")

      assert {:error, "Event is not a user status (expected kind 30315)", _} =
               UserStatus.parse(event)
    end
  end

  describe "create/3" do
    test "creates user status with all options" do
      expiration = DateTime.add(DateTime.utc_now(), 180, :second)

      status =
        UserStatus.create("general", "Working hard!",
          url: "https://example.com",
          profile: "pubkey123",
          note: "event123",
          address: "30023:author:article",
          expiration: expiration,
          emojis: %{"wave" => "https://example.com/wave.png"}
        )

      assert %UserStatus{} = status
      assert status.event.kind == 30_315
      assert status.status_type == "general"
      assert status.status == "Working hard!"
      assert status.url == "https://example.com"
      assert status.profile == "pubkey123"
      assert status.note == "event123"
      assert status.address == "30023:author:article"
      # Compare unix timestamps since microseconds are lost in conversion
      assert DateTime.to_unix(status.expiration) == DateTime.to_unix(expiration)
      assert status.emojis == %{"wave" => "https://example.com/wave.png"}
    end

    test "creates user status with minimal options" do
      status = UserStatus.create("custom", "My status")

      assert status.event.kind == 30_315
      assert status.status_type == "custom"
      assert status.status == "My status"
      assert status.url == nil
      assert status.expiration == nil
      assert status.emojis == %{}
    end
  end

  describe "general/2" do
    test "creates general status" do
      status = UserStatus.general("In a meeting")

      assert status.status_type == "general"
      assert status.status == "In a meeting"
    end

    test "creates general status with options" do
      status = UserStatus.general("Join my nest!", url: "https://nostrnests.com/abc")

      assert status.status_type == "general"
      assert status.url == "https://nostrnests.com/abc"
    end
  end

  describe "music/2" do
    test "creates music status" do
      status = UserStatus.music("Intergalactic - Beastie Boys")

      assert status.status_type == "music"
      assert status.status == "Intergalactic - Beastie Boys"
    end

    test "creates music status with expiration" do
      expiration = DateTime.add(DateTime.utc_now(), 240, :second)
      status = UserStatus.music("Song Name", expiration: expiration)

      assert status.status_type == "music"
      # Compare unix timestamps since microseconds are lost in conversion
      assert DateTime.to_unix(status.expiration) == DateTime.to_unix(expiration)
    end
  end

  describe "clear/2" do
    test "clears general status" do
      status = UserStatus.clear("general")

      assert status.status_type == "general"
      assert status.status == ""
    end

    test "clears music status" do
      status = UserStatus.clear("music")

      assert status.status_type == "music"
      assert status.status == ""
    end
  end

  describe "expired?/1" do
    test "returns false when no expiration set" do
      status = UserStatus.general("Test")
      refute UserStatus.expired?(status)
    end

    test "returns false when expiration is in the future" do
      expiration = DateTime.add(DateTime.utc_now(), 3600, :second)
      status = UserStatus.general("Test", expiration: expiration)
      refute UserStatus.expired?(status)
    end

    test "returns true when expiration is in the past" do
      expiration = DateTime.add(DateTime.utc_now(), -60, :second)
      status = UserStatus.general("Test", expiration: expiration)
      assert UserStatus.expired?(status)
    end
  end

  describe "coordinates/1" do
    test "returns coordinates when pubkey is set" do
      status = UserStatus.general("Test")
      event = Nostr.Event.sign(status.event, Fixtures.seckey())
      status = %{status | event: event}

      coords = UserStatus.coordinates(status)
      assert coords == "30315:#{Fixtures.pubkey()}:general"
    end

    test "returns nil when pubkey is not set" do
      status = UserStatus.general("Test")
      assert UserStatus.coordinates(status) == nil
    end
  end

  describe "roundtrip" do
    test "create -> sign -> serialize -> parse" do
      expiration = DateTime.add(DateTime.utc_now(), 180, :second)

      original =
        UserStatus.music("Intergalactic - Beastie Boys",
          url: "spotify:search:Intergalactic",
          expiration: expiration,
          pubkey: Fixtures.pubkey()
        )

      # Sign and serialize
      signed_event = Event.sign(original.event, Fixtures.seckey())
      json = JSON.encode!(signed_event)

      # Parse back
      parsed_event = Nostr.Event.Parser.parse(JSON.decode!(json))
      parsed_status = UserStatus.parse(parsed_event)

      assert parsed_status.status_type == "music"
      assert parsed_status.status == "Intergalactic - Beastie Boys"
      assert parsed_status.url == "spotify:search:Intergalactic"
      assert DateTime.to_unix(parsed_status.expiration) == DateTime.to_unix(expiration)
    end
  end

  describe "parser integration" do
    test "parse_specific routes kind 30315 to UserStatus" do
      tags = [Nostr.Tag.create(:d, "general")]
      event = Fixtures.signed_event(kind: 30_315, content: "Test", tags: tags)

      parsed = Event.Parser.parse_specific(event)
      assert %UserStatus{} = parsed
      assert parsed.status_type == "general"
    end
  end
end
