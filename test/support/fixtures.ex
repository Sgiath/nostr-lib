defmodule Nostr.Test.Fixtures do
  @moduledoc """
  Test fixtures for Nostr library tests.
  """

  # Valid test keypair (DO NOT USE IN PRODUCTION)
  @seckey "1111111111111111111111111111111111111111111111111111111111111111"
  @pubkey "4f355bdcb7cc0af728ef3cceb9615d90684bb5b2ca5f859ab0f0b704075871aa"

  # Another keypair for multi-party tests
  @seckey2 "2222222222222222222222222222222222222222222222222222222222222222"
  @pubkey2 "466d7fcae563e5cb09a0d1870bb580344804617879a14949cf22285f1bae3f27"

  def seckey, do: @seckey
  def pubkey, do: @pubkey
  def seckey2, do: @seckey2
  def pubkey2, do: @pubkey2

  @doc "Creates a valid signed event for testing"
  def signed_event(opts \\ []) do
    kind = Keyword.get(opts, :kind, 1)
    content = Keyword.get(opts, :content, "test content")
    tags = Keyword.get(opts, :tags, [])
    seckey = Keyword.get(opts, :seckey, @seckey)
    created_at = Keyword.get(opts, :created_at, ~U[2024-01-01 00:00:00Z])

    kind
    |> Nostr.Event.create(content: content, tags: tags, created_at: created_at)
    |> Nostr.Event.sign(seckey)
  end

  @doc "Creates a raw event map (as received from JSON)"
  def raw_event_map(opts \\ []) do
    event = signed_event(opts)

    %{
      "id" => event.id,
      "pubkey" => event.pubkey,
      "kind" => event.kind,
      "tags" =>
        Enum.map(event.tags, fn tag -> [Atom.to_string(tag.type), tag.data | tag.info] end),
      "created_at" => DateTime.to_unix(event.created_at),
      "content" => event.content,
      "sig" => event.sig
    }
  end

  @doc "Creates a raw event map with tampered ID"
  def tampered_id_event do
    event = raw_event_map()
    Map.put(event, "id", "0000000000000000000000000000000000000000000000000000000000000000")
  end

  @doc "Creates a raw event map with tampered signature"
  def tampered_sig_event do
    event = raw_event_map()
    # Change last character of signature
    tampered_sig = String.slice(event["sig"], 0..-2//1) <> "0"
    Map.put(event, "sig", tampered_sig)
  end

  @doc "Creates a raw event map with tampered content"
  def tampered_content_event do
    event = raw_event_map()
    Map.put(event, "content", "tampered content")
  end
end
