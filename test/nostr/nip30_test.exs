defmodule Nostr.NIP30Test do
  use ExUnit.Case, async: true

  alias Nostr.NIP30
  alias Nostr.Tag

  doctest Nostr.NIP30

  describe "to_tag/2" do
    test "creates emoji tag" do
      tag = NIP30.to_tag("wave", "https://example.com/wave.png")

      assert %Tag{type: :emoji, data: "wave", info: ["https://example.com/wave.png"]} = tag
    end
  end

  describe "from_tags/1" do
    test "extracts emoji map from tags" do
      tags = [
        %Tag{type: :emoji, data: "wave", info: ["https://example.com/wave.png"]},
        %Tag{type: :emoji, data: "smile", info: ["https://example.com/smile.png"]},
        %Tag{type: :p, data: "pubkey123", info: []}
      ]

      result = NIP30.from_tags(tags)

      assert result == %{
               "wave" => "https://example.com/wave.png",
               "smile" => "https://example.com/smile.png"
             }
    end

    test "returns empty map when no emoji tags" do
      tags = [
        %Tag{type: :p, data: "pubkey123", info: []},
        %Tag{type: :e, data: "event123", info: []}
      ]

      assert NIP30.from_tags(tags) == %{}
    end

    test "handles empty tag list" do
      assert NIP30.from_tags([]) == %{}
    end

    test "ignores emoji tags with missing URL" do
      tags = [
        %Tag{type: :emoji, data: "wave", info: ["https://example.com/wave.png"]},
        %Tag{type: :emoji, data: "broken", info: []}
      ]

      result = NIP30.from_tags(tags)

      assert result == %{"wave" => "https://example.com/wave.png"}
    end
  end

  describe "extract_shortcodes/1" do
    test "extracts single shortcode" do
      assert NIP30.extract_shortcodes("Hello :wave:!") == ["wave"]
    end

    test "extracts multiple shortcodes" do
      assert NIP30.extract_shortcodes("Hello :wave: and :smile:!") == ["wave", "smile"]
    end

    test "returns empty list when no shortcodes" do
      assert NIP30.extract_shortcodes("No emojis here") == []
    end

    test "handles shortcodes with underscores" do
      assert NIP30.extract_shortcodes("Hello :my_emoji:!") == ["my_emoji"]
    end

    test "handles shortcodes with numbers" do
      assert NIP30.extract_shortcodes("Hello :emoji123:!") == ["emoji123"]
    end

    test "extracts shortcodes at start and end" do
      assert NIP30.extract_shortcodes(":start: middle :end:") == ["start", "end"]
    end
  end

  describe "valid_shortcode?/1" do
    test "accepts alphanumeric shortcodes" do
      assert NIP30.valid_shortcode?("wave")
      assert NIP30.valid_shortcode?("Wave")
      assert NIP30.valid_shortcode?("WAVE")
      assert NIP30.valid_shortcode?("wave123")
    end

    test "accepts shortcodes with underscores" do
      assert NIP30.valid_shortcode?("my_emoji")
      assert NIP30.valid_shortcode?("my_emoji_123")
      assert NIP30.valid_shortcode?("_leading")
      assert NIP30.valid_shortcode?("trailing_")
    end

    test "rejects shortcodes with hyphens" do
      refute NIP30.valid_shortcode?("my-emoji")
    end

    test "rejects shortcodes with spaces" do
      refute NIP30.valid_shortcode?("has space")
    end

    test "rejects shortcodes with special characters" do
      refute NIP30.valid_shortcode?("emoji!")
      refute NIP30.valid_shortcode?("emoji@")
      refute NIP30.valid_shortcode?("emoji.dot")
    end

    test "rejects empty string" do
      refute NIP30.valid_shortcode?("")
    end
  end

  describe "build_tags/1" do
    test "builds tags from map" do
      emojis = %{"wave" => "https://example.com/wave.png"}

      [tag] = NIP30.build_tags(emojis)

      assert %Tag{type: :emoji, data: "wave", info: ["https://example.com/wave.png"]} = tag
    end

    test "builds tags from list of tuples" do
      emojis = [{"wave", "https://example.com/wave.png"}]

      [tag] = NIP30.build_tags(emojis)

      assert %Tag{type: :emoji, data: "wave", info: ["https://example.com/wave.png"]} = tag
    end

    test "builds tags from keyword list" do
      emojis = [wave: "https://example.com/wave.png"]

      [tag] = NIP30.build_tags(emojis)

      assert %Tag{type: :emoji, data: "wave", info: ["https://example.com/wave.png"]} = tag
    end

    test "builds multiple tags" do
      emojis = %{
        "wave" => "https://example.com/wave.png",
        "smile" => "https://example.com/smile.png"
      }

      tags = NIP30.build_tags(emojis)

      assert length(tags) == 2
      assert Enum.all?(tags, &(&1.type == :emoji))
    end
  end

  describe "has_emojis?/1" do
    test "returns true when content has shortcodes" do
      assert NIP30.has_emojis?("Hello :wave:!")
    end

    test "returns false when content has no shortcodes" do
      refute NIP30.has_emojis?("No emojis here")
    end

    test "returns false for empty string" do
      refute NIP30.has_emojis?("")
    end

    test "returns true for multiple shortcodes" do
      assert NIP30.has_emojis?(":start: and :end:")
    end
  end
end
