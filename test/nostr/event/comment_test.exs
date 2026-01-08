defmodule Nostr.Event.CommentTest do
  use ExUnit.Case, async: true
  doctest Nostr.Event.Comment

  alias Nostr.{Event, Tag}
  alias Nostr.Event.Comment
  alias Nostr.Test.Fixtures

  describe "parse/1" do
    test "parses comment on event (E tag root)" do
      event = %Event{
        kind: 1111,
        content: "Great article!",
        tags: [
          %Tag{type: :E, data: "abc123", info: ["wss://relay.example.com", "author_pubkey"]},
          %Tag{type: :K, data: "30023", info: []},
          %Tag{type: :P, data: "author_pubkey", info: ["wss://relay.example.com"]},
          %Tag{type: :e, data: "abc123", info: ["wss://relay.example.com", "author_pubkey"]},
          %Tag{type: :k, data: "30023", info: []},
          %Tag{type: :p, data: "author_pubkey", info: ["wss://relay.example.com"]}
        ],
        pubkey: "commenter_pubkey",
        created_at: DateTime.utc_now(),
        id: nil,
        sig: nil
      }

      comment = Comment.parse(event)

      assert comment.content == "Great article!"
      assert comment.root_ref.type == :E
      assert comment.root_ref.id == "abc123"
      assert comment.root_ref.relay == "wss://relay.example.com"
      assert comment.root_ref.pubkey == "author_pubkey"
      assert comment.root_kind == 30023
      assert comment.root_author.pubkey == "author_pubkey"
      assert comment.parent_ref.type == :e
      assert comment.parent_ref.id == "abc123"
      assert comment.parent_kind == 30023
      assert comment.parent_author.pubkey == "author_pubkey"
    end

    test "parses comment on addressable event (A tag root)" do
      event = %Event{
        kind: 1111,
        content: "Nice guide!",
        tags: [
          %Tag{type: :A, data: "30023:author123:my-guide", info: ["wss://relay.example.com"]},
          %Tag{type: :K, data: "30023", info: []},
          %Tag{type: :P, data: "author123", info: []},
          %Tag{type: :a, data: "30023:author123:my-guide", info: ["wss://relay.example.com"]},
          %Tag{type: :k, data: "30023", info: []},
          %Tag{type: :p, data: "author123", info: []}
        ],
        pubkey: "commenter_pubkey",
        created_at: DateTime.utc_now(),
        id: nil,
        sig: nil
      }

      comment = Comment.parse(event)

      assert comment.root_ref.type == :A
      assert comment.root_ref.id == "30023:author123:my-guide"
      assert comment.root_kind == 30023
      assert comment.parent_ref.type == :a
    end

    test "parses comment on external content (I tag root)" do
      event = %Event{
        kind: 1111,
        content: "Interesting article!",
        tags: [
          %Tag{type: :I, data: "https://example.com/article", info: []},
          %Tag{type: :K, data: "web", info: []},
          %Tag{type: :i, data: "https://example.com/article", info: []},
          %Tag{type: :k, data: "web", info: []}
        ],
        pubkey: "commenter_pubkey",
        created_at: DateTime.utc_now(),
        id: nil,
        sig: nil
      }

      comment = Comment.parse(event)

      assert comment.root_ref.type == :I
      assert comment.root_ref.id == "https://example.com/article"
      assert comment.root_kind == "web"
      assert comment.parent_ref.type == :i
      assert comment.parent_kind == "web"
      assert comment.root_author == nil
      assert comment.parent_author == nil
    end

    test "parses reply to comment (parent kind 1111)" do
      event = %Event{
        kind: 1111,
        content: "I agree!",
        tags: [
          %Tag{
            type: :E,
            data: "original_event_id",
            info: ["wss://relay.example.com", "original_author"]
          },
          %Tag{type: :K, data: "30023", info: []},
          %Tag{type: :P, data: "original_author", info: []},
          %Tag{
            type: :e,
            data: "parent_comment_id",
            info: ["wss://relay.example.com", "commenter"]
          },
          %Tag{type: :k, data: "1111", info: []},
          %Tag{type: :p, data: "commenter", info: []}
        ],
        pubkey: "replier_pubkey",
        created_at: DateTime.utc_now(),
        id: nil,
        sig: nil
      }

      comment = Comment.parse(event)

      # Root scope points to original event
      assert comment.root_ref.type == :E
      assert comment.root_ref.id == "original_event_id"
      assert comment.root_kind == 30023

      # Parent scope points to comment being replied to
      assert comment.parent_ref.type == :e
      assert comment.parent_ref.id == "parent_comment_id"
      assert comment.parent_kind == 1111
      assert comment.parent_author.pubkey == "commenter"
    end

    test "parses quotes (q tags)" do
      event = %Event{
        kind: 1111,
        content: "See also this: nostr:nevent1...",
        tags: [
          %Tag{type: :E, data: "abc123", info: []},
          %Tag{type: :K, data: "1", info: []},
          %Tag{type: :P, data: "author1", info: []},
          %Tag{type: :e, data: "abc123", info: []},
          %Tag{type: :k, data: "1", info: []},
          %Tag{type: :p, data: "author1", info: []},
          %Tag{
            type: :q,
            data: "quoted_event_id",
            info: ["wss://relay.example.com", "quoted_author"]
          }
        ],
        pubkey: "commenter_pubkey",
        created_at: DateTime.utc_now(),
        id: nil,
        sig: nil
      }

      comment = Comment.parse(event)

      assert length(comment.quotes) == 1
      [quote] = comment.quotes
      assert quote.id == "quoted_event_id"
      assert quote.relay == "wss://relay.example.com"
      assert quote.pubkey == "quoted_author"
    end

    test "parses mentions (additional p tags)" do
      event = %Event{
        kind: 1111,
        content: "@user mentioned",
        tags: [
          %Tag{type: :E, data: "abc123", info: []},
          %Tag{type: :K, data: "1", info: []},
          %Tag{type: :P, data: "author1", info: []},
          %Tag{type: :e, data: "abc123", info: []},
          %Tag{type: :k, data: "1", info: []},
          %Tag{type: :p, data: "author1", info: []},
          %Tag{type: :p, data: "mentioned_user", info: ["wss://relay.example.com"]}
        ],
        pubkey: "commenter_pubkey",
        created_at: DateTime.utc_now(),
        id: nil,
        sig: nil
      }

      comment = Comment.parse(event)

      assert length(comment.mentions) == 1
      [mention] = comment.mentions
      assert mention.pubkey == "mentioned_user"
      assert mention.relay == "wss://relay.example.com"
    end
  end

  describe "comment_on_event/5" do
    test "creates top-level comment on event" do
      comment =
        Comment.comment_on_event(
          "Great post!",
          "event_id_123",
          30023,
          "author_pubkey",
          relay: "wss://relay.example.com"
        )

      assert comment.content == "Great post!"
      assert comment.event.kind == 1111

      # Root scope
      assert comment.root_ref.type == :E
      assert comment.root_ref.id == "event_id_123"
      assert comment.root_ref.relay == "wss://relay.example.com"
      assert comment.root_ref.pubkey == "author_pubkey"
      assert comment.root_kind == 30023
      assert comment.root_author.pubkey == "author_pubkey"

      # Parent scope (same as root for top-level comments)
      assert comment.parent_ref.type == :e
      assert comment.parent_ref.id == "event_id_123"
      assert comment.parent_kind == 30023
      assert comment.parent_author.pubkey == "author_pubkey"
    end

    test "creates comment without relay hint" do
      comment =
        Comment.comment_on_event(
          "Nice!",
          "event_id_123",
          1,
          "author_pubkey"
        )

      assert comment.root_ref.relay == nil
      assert comment.root_ref.pubkey == "author_pubkey"
    end

    test "creates comment with quotes" do
      comment =
        Comment.comment_on_event(
          "Related: ...",
          "event_id_123",
          1,
          "author_pubkey",
          quotes: [{"quoted_id", "wss://relay.example.com", "quoted_author"}]
        )

      assert length(comment.quotes) == 1
      [quote] = comment.quotes
      assert quote.id == "quoted_id"
    end

    test "creates comment with mentions" do
      comment =
        Comment.comment_on_event(
          "Hey @user!",
          "event_id_123",
          1,
          "author_pubkey",
          mentions: [{"mentioned_pubkey", "wss://relay.example.com"}]
        )

      assert length(comment.mentions) == 1
    end
  end

  describe "comment_on_address/5" do
    test "creates top-level comment on addressable event" do
      comment =
        Comment.comment_on_address(
          "Great article!",
          "30023:author123:my-article",
          30023,
          "author123",
          relay: "wss://relay.example.com"
        )

      assert comment.content == "Great article!"
      assert comment.event.kind == 1111

      assert comment.root_ref.type == :A
      assert comment.root_ref.id == "30023:author123:my-article"
      assert comment.root_kind == 30023
      assert comment.root_author.pubkey == "author123"

      assert comment.parent_ref.type == :a
      assert comment.parent_ref.id == "30023:author123:my-article"
    end
  end

  describe "comment_on_external/4" do
    test "creates top-level comment on external URL" do
      comment =
        Comment.comment_on_external(
          "Great resource!",
          "https://example.com/article",
          "web"
        )

      assert comment.content == "Great resource!"
      assert comment.event.kind == 1111

      assert comment.root_ref.type == :I
      assert comment.root_ref.id == "https://example.com/article"
      assert comment.root_kind == "web"
      assert comment.root_author == nil

      assert comment.parent_ref.type == :i
      assert comment.parent_ref.id == "https://example.com/article"
      assert comment.parent_kind == "web"
    end

    test "creates comment on external content with hint" do
      comment =
        Comment.comment_on_external(
          "Great episode!",
          "podcast:guid:12345",
          "podcast:item:guid",
          hint: "https://podcast.example.com/feed"
        )

      assert comment.root_ref.id == "podcast:guid:12345"
      assert comment.root_ref.relay == "https://podcast.example.com/feed"
      assert comment.root_kind == "podcast:item:guid"
    end
  end

  describe "reply/3" do
    test "creates reply to existing comment" do
      # First create a parent comment on an event
      parent =
        Comment.comment_on_event(
          "Original comment",
          "original_event_id",
          30023,
          "original_author",
          relay: "wss://relay.example.com",
          pubkey: Fixtures.pubkey()
        )

      # Sign the parent to give it an ID
      parent_event =
        parent.event
        |> Event.sign(Fixtures.seckey())

      parent = %{parent | event: parent_event}

      # Now create a reply
      reply =
        Comment.reply(
          "I agree!",
          parent,
          relay: "wss://relay2.example.com"
        )

      assert reply.content == "I agree!"
      assert reply.event.kind == 1111

      # Root scope stays the same as parent's root (original event)
      assert reply.root_ref.type == :E
      assert reply.root_ref.id == "original_event_id"
      assert reply.root_kind == 30023
      assert reply.root_author.pubkey == "original_author"

      # Parent scope points to the comment being replied to
      assert reply.parent_ref.type == :e
      assert reply.parent_ref.id == parent_event.id
      assert reply.parent_kind == 1111
      assert reply.parent_author.pubkey == parent_event.pubkey
    end

    test "creates nested reply chain" do
      # Create root comment on external content
      root_comment =
        Comment.comment_on_external(
          "First comment",
          "https://example.com/article",
          "web",
          pubkey: Fixtures.pubkey()
        )

      root_event = Event.sign(root_comment.event, Fixtures.seckey())
      root_comment = %{root_comment | event: root_event}

      # First reply
      reply1 =
        Comment.reply("Reply 1", root_comment, pubkey: Fixtures.pubkey())

      reply1_event = Event.sign(reply1.event, Fixtures.seckey())
      reply1 = %{reply1 | event: reply1_event}

      # Nested reply
      reply2 = Comment.reply("Reply 2", reply1)

      # Root should still point to original external content
      assert reply2.root_ref.type == :I
      assert reply2.root_ref.id == "https://example.com/article"
      assert reply2.root_kind == "web"

      # Parent should point to reply1
      assert reply2.parent_ref.type == :e
      assert reply2.parent_ref.id == reply1_event.id
      assert reply2.parent_kind == 1111
    end
  end

  describe "roundtrip" do
    test "create -> sign -> serialize -> parse" do
      comment =
        Comment.comment_on_event(
          "Test comment",
          "event123",
          1,
          "author_pubkey",
          relay: "wss://relay.example.com",
          pubkey: Fixtures.pubkey()
        )

      # Sign and serialize
      signed_event = Event.sign(comment.event, Fixtures.seckey())
      json = JSON.encode!(signed_event)

      # Parse back
      parsed_event = Nostr.Event.Parser.parse(JSON.decode!(json))
      parsed_comment = Comment.parse(parsed_event)

      assert parsed_comment.content == "Test comment"
      assert parsed_comment.root_ref.type == :E
      assert parsed_comment.root_ref.id == "event123"
      assert parsed_comment.root_kind == 1
      assert parsed_comment.parent_ref.type == :e
      assert parsed_comment.parent_kind == 1
    end
  end

  describe "parser integration" do
    test "Parser.parse_specific routes kind 1111 to Comment" do
      event = %Event{
        kind: 1111,
        content: "Test",
        tags: [
          %Tag{type: :E, data: "abc", info: []},
          %Tag{type: :K, data: "1", info: []},
          %Tag{type: :P, data: "pub", info: []},
          %Tag{type: :e, data: "abc", info: []},
          %Tag{type: :k, data: "1", info: []},
          %Tag{type: :p, data: "pub", info: []}
        ],
        pubkey: "test",
        created_at: DateTime.utc_now(),
        id: nil,
        sig: nil
      }

      result = Nostr.Event.Parser.parse_specific(event)

      assert %Comment{} = result
      assert result.content == "Test"
    end
  end
end
