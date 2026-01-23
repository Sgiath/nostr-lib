defmodule Nostr.NIP36Test do
  use ExUnit.Case, async: true

  alias Nostr.Event.Article
  alias Nostr.Event.Note
  alias Nostr.NIP36
  alias Nostr.Tag
  alias Nostr.Test.Fixtures

  describe "from_tags/1" do
    test "returns reason string when content-warning tag has reason" do
      tags = [Tag.create(:"content-warning", "Spoilers ahead")]
      assert NIP36.from_tags(tags) == "Spoilers ahead"
    end

    test "returns true when content-warning tag has empty reason" do
      tags = [Tag.create(:"content-warning", "")]
      assert NIP36.from_tags(tags) == true
    end

    test "returns nil when no content-warning tag exists" do
      tags = [Tag.create(:p, "pubkey")]
      assert NIP36.from_tags(tags) == nil
    end

    test "returns nil for empty tags" do
      assert NIP36.from_tags([]) == nil
    end
  end

  describe "to_tag/1" do
    test "creates tag with reason string" do
      tag = NIP36.to_tag("NSFW")
      assert tag.type == :"content-warning"
      assert tag.data == "NSFW"
    end

    test "creates tag with empty reason for true" do
      tag = NIP36.to_tag(true)
      assert tag.type == :"content-warning"
      assert tag.data == ""
    end

    test "returns nil for nil" do
      assert NIP36.to_tag(nil) == nil
    end
  end

  describe "has_warning?/1" do
    test "returns true when event has content-warning tag" do
      event = Fixtures.signed_event(tags: [Tag.create(:"content-warning", "test")])
      assert NIP36.has_warning?(event) == true
    end

    test "returns true when tags list has content-warning tag" do
      tags = [Tag.create(:"content-warning", "")]
      assert NIP36.has_warning?(tags) == true
    end

    test "returns false when event has no content-warning tag" do
      event = Fixtures.signed_event(tags: [Tag.create(:p, "pubkey")])
      assert NIP36.has_warning?(event) == false
    end

    test "returns false for empty tags" do
      assert NIP36.has_warning?([]) == false
    end
  end

  describe "add_warning/2" do
    test "adds content-warning tag with reason" do
      event = Fixtures.signed_event(tags: [])
      result = NIP36.add_warning(event, "Spoilers")

      cw_tags = Enum.filter(result.tags, &(&1.type == :"content-warning"))
      assert length(cw_tags) == 1
      [tag] = cw_tags
      assert tag.data == "Spoilers"
    end

    test "adds content-warning tag with no reason" do
      event = Fixtures.signed_event(tags: [])
      result = NIP36.add_warning(event)

      cw_tags = Enum.filter(result.tags, &(&1.type == :"content-warning"))
      assert length(cw_tags) == 1
      [tag] = cw_tags
      assert tag.data == ""
    end

    test "replaces existing content-warning tag" do
      event = Fixtures.signed_event(tags: [Tag.create(:"content-warning", "old")])
      result = NIP36.add_warning(event, "new")

      cw_tags = Enum.filter(result.tags, &(&1.type == :"content-warning"))
      assert length(cw_tags) == 1
      [tag] = cw_tags
      assert tag.data == "new"
    end

    test "preserves other tags" do
      event = Fixtures.signed_event(tags: [Tag.create(:p, "pubkey")])
      result = NIP36.add_warning(event, "test")

      assert NIP36.has_warning?(result)
      assert Enum.any?(result.tags, &(&1.type == :p))
    end
  end

  describe "remove_warning/1" do
    test "removes content-warning tag" do
      event = Fixtures.signed_event(tags: [Tag.create(:"content-warning", "test")])
      result = NIP36.remove_warning(event)

      refute Enum.any?(result.tags, &(&1.type == :"content-warning"))
    end

    test "preserves other tags" do
      event =
        Fixtures.signed_event(
          tags: [
            Tag.create(:p, "pubkey"),
            Tag.create(:"content-warning", "test")
          ]
        )

      result = NIP36.remove_warning(event)

      refute Enum.any?(result.tags, &(&1.type == :"content-warning"))
      assert Enum.any?(result.tags, &(&1.type == :p))
    end
  end

  describe "Note integration" do
    test "parses note with content-warning tag" do
      tags = [Tag.create(:"content-warning", "Spoilers")]
      event = Fixtures.signed_event(kind: 1, content: "test", tags: tags)
      note = Note.parse(event)

      assert note.content_warning == "Spoilers"
    end

    test "parses note with content-warning tag (no reason)" do
      tags = [Tag.create(:"content-warning", "")]
      event = Fixtures.signed_event(kind: 1, content: "test", tags: tags)
      note = Note.parse(event)

      assert note.content_warning == true
    end

    test "parses note without content-warning" do
      event = Fixtures.signed_event(kind: 1, content: "test")
      note = Note.parse(event)

      assert note.content_warning == nil
    end

    test "creates note with content warning reason" do
      note = Note.create("Sensitive content", content_warning: "NSFW")

      assert note.content_warning == "NSFW"
      assert NIP36.has_warning?(note.event)
    end

    test "creates note with content warning (no reason)" do
      note = Note.create("Sensitive content", content_warning: true)

      assert note.content_warning == true
      assert NIP36.has_warning?(note.event)
    end
  end

  describe "Article integration" do
    test "parses article with content-warning tag" do
      tags = [
        Tag.create(:d, "test-article"),
        Tag.create(:"content-warning", "Violence")
      ]

      event = Fixtures.signed_event(kind: 30_023, content: "# Article", tags: tags)
      article = Article.parse(event)

      assert article.content_warning == "Violence"
    end

    test "creates article with content warning" do
      article = Article.create("# Content", "test-slug", content_warning: "Explicit")

      assert article.content_warning == "Explicit"
      assert NIP36.has_warning?(article.event)
    end

    test "creates draft with content warning" do
      draft = Article.create_draft("# Content", "test-slug", content_warning: "NSFW")

      assert draft.content_warning == "NSFW"
      assert NIP36.has_warning?(draft.event)
    end

    test "publish preserves content warning" do
      draft = Article.create_draft("# Content", "test-slug", content_warning: "Sensitive")
      published = Article.publish(draft)

      assert published.content_warning == "Sensitive"
      assert NIP36.has_warning?(published.event)
    end
  end
end
