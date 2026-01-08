defmodule Nostr.Event.ArticleTest do
  use ExUnit.Case, async: true

  alias Nostr.Event
  alias Nostr.Event.Article
  alias Nostr.Test.Fixtures

  describe "parse/1" do
    test "parses article with all metadata" do
      tags = [
        Nostr.Tag.create(:d, "my-article"),
        Nostr.Tag.create("title", "My Article Title"),
        Nostr.Tag.create("image", "https://example.com/image.jpg"),
        Nostr.Tag.create("summary", "A brief summary"),
        Nostr.Tag.create("published_at", "1234567890"),
        Nostr.Tag.create(:t, "nostr"),
        Nostr.Tag.create(:t, "tutorial"),
        Nostr.Tag.create(:e, "abc123", ["wss://relay.example.com"]),
        Nostr.Tag.create(:a, "30023:pubkey:other-article", ["wss://relay.example.com"])
      ]

      event = Fixtures.signed_event(kind: 30_023, content: "# Hello\n\nWorld", tags: tags)
      article = Article.parse(event)

      assert %Article{} = article
      assert article.identifier == "my-article"
      assert article.title == "My Article Title"
      assert article.image == "https://example.com/image.jpg"
      assert article.summary == "A brief summary"
      assert article.published_at == ~U[2009-02-13 23:31:30Z]
      assert article.content == "# Hello\n\nWorld"
      assert article.hashtags == ["nostr", "tutorial"]
      assert article.draft? == false

      assert [%{id: "abc123", relay: "wss://relay.example.com"}] = article.event_refs

      assert [%{coordinates: "30023:pubkey:other-article", relay: "wss://relay.example.com"}] =
               article.addr_refs
    end

    test "parses article with minimal metadata" do
      tags = [Nostr.Tag.create(:d, "minimal")]
      event = Fixtures.signed_event(kind: 30_023, content: "Just content", tags: tags)
      article = Article.parse(event)

      assert article.identifier == "minimal"
      assert article.title == nil
      assert article.image == nil
      assert article.summary == nil
      assert article.published_at == nil
      assert article.hashtags == []
      assert article.draft? == false
    end

    test "parses draft article (kind 30024)" do
      tags = [
        Nostr.Tag.create(:d, "draft-article"),
        Nostr.Tag.create("title", "Draft Title")
      ]

      event = Fixtures.signed_event(kind: 30_024, content: "Work in progress", tags: tags)
      article = Article.parse(event)

      assert article.identifier == "draft-article"
      assert article.title == "Draft Title"
      assert article.draft? == true
    end

    test "returns error for wrong kind" do
      event = Fixtures.signed_event(kind: 1, content: "Not an article")

      assert {:error, "Event is not an article (expected kind 30023 or 30024)", _} =
               Article.parse(event)
    end
  end

  describe "create/3" do
    test "creates article with all options" do
      published_at = ~U[2024-01-15 12:00:00Z]

      article =
        Article.create("# Content", "my-slug",
          title: "My Title",
          image: "https://example.com/img.jpg",
          summary: "A summary",
          published_at: published_at,
          hashtags: ["elixir", "nostr"],
          event_refs: ["event1", {"event2", "wss://relay.example.com"}],
          addr_refs: ["30023:pub:id", {"30023:pub:id2", "wss://relay.example.com"}]
        )

      assert %Article{} = article
      assert article.event.kind == 30_023
      assert article.identifier == "my-slug"
      assert article.title == "My Title"
      assert article.image == "https://example.com/img.jpg"
      assert article.summary == "A summary"
      assert article.published_at == published_at
      assert article.content == "# Content"
      assert article.hashtags == ["elixir", "nostr"]
      assert article.draft? == false
      assert length(article.event_refs) == 2
      assert length(article.addr_refs) == 2
    end

    test "creates article with minimal options" do
      article = Article.create("Content", "slug")

      assert article.event.kind == 30_023
      assert article.identifier == "slug"
      assert article.content == "Content"
      assert article.title == nil
      assert article.hashtags == []
      assert article.draft? == false
    end
  end

  describe "create_draft/3" do
    test "creates draft article" do
      article = Article.create_draft("Draft content", "draft-slug", title: "Draft")

      assert article.event.kind == 30_024
      assert article.identifier == "draft-slug"
      assert article.title == "Draft"
      assert article.draft? == true
    end
  end

  describe "publish/1" do
    test "converts draft to published article" do
      draft = Article.create_draft("Content", "my-article", title: "Title")
      assert draft.draft? == true
      assert draft.event.kind == 30_024

      published = Article.publish(draft)
      assert published.draft? == false
      assert published.event.kind == 30_023
      assert published.published_at != nil
      assert published.title == "Title"
      assert published.identifier == "my-article"
    end

    test "sets published_at if not already set" do
      draft = Article.create_draft("Content", "article")
      assert draft.published_at == nil

      published = Article.publish(draft)
      assert %DateTime{} = published.published_at
    end

    test "preserves existing published_at" do
      original_time = ~U[2020-01-01 00:00:00Z]
      draft = Article.create_draft("Content", "article", published_at: original_time)

      published = Article.publish(draft)
      assert published.published_at == original_time
    end

    test "returns same article if already published" do
      article = Article.create("Content", "article")
      assert article.draft? == false

      same = Article.publish(article)
      assert same == article
    end
  end

  describe "draft?/1" do
    test "returns true for drafts" do
      draft = Article.create_draft("Content", "article")
      assert Article.draft?(draft) == true
    end

    test "returns false for published articles" do
      article = Article.create("Content", "article")
      assert Article.draft?(article) == false
    end
  end

  describe "coordinates/1" do
    test "returns coordinates for published article" do
      article = Article.create("Content", "my-article")
      # Need to sign the event to have a pubkey
      event = Nostr.Event.sign(article.event, Fixtures.seckey())
      article = %{article | event: event}

      coords = Article.coordinates(article)
      assert coords == "30023:#{Fixtures.pubkey()}:my-article"
    end

    test "returns coordinates for draft" do
      draft = Article.create_draft("Content", "draft-article")
      event = Nostr.Event.sign(draft.event, Fixtures.seckey())
      draft = %{draft | event: event}

      coords = Article.coordinates(draft)
      assert coords == "30024:#{Fixtures.pubkey()}:draft-article"
    end

    test "returns nil when pubkey is not set" do
      article = Article.create("Content", "article")
      assert Article.coordinates(article) == nil
    end
  end

  describe "parser integration" do
    test "parse_specific routes kind 30023 to Article" do
      tags = [Nostr.Tag.create(:d, "test")]
      event = Fixtures.signed_event(kind: 30_023, content: "Test", tags: tags)

      parsed = Event.Parser.parse_specific(event)
      assert %Article{} = parsed
      assert parsed.draft? == false
    end

    test "parse_specific routes kind 30024 to Article" do
      tags = [Nostr.Tag.create(:d, "test")]
      event = Fixtures.signed_event(kind: 30_024, content: "Test", tags: tags)

      parsed = Event.Parser.parse_specific(event)
      assert %Article{} = parsed
      assert parsed.draft? == true
    end
  end
end
