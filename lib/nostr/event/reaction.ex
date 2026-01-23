defmodule Nostr.Event.Reaction do
  @moduledoc """
  Post reaction (kind 7) and external content reaction (kind 17).

  Defined in NIP-25: https://github.com/nostr-protocol/nips/blob/master/25.md

  ## Reaction Content

  - `+` or empty string - interpreted as "like" or "upvote"
  - `-` - interpreted as "dislike" or "downvote"
  - emoji or NIP-30 custom emoji - displayed as emoji reaction

  ## Tags

  Kind 7 (nostr event reactions):
  - `e` tag (required) - event ID being reacted to, with optional relay hint and pubkey hint
  - `p` tag (recommended) - pubkey of event author
  - `a` tag (for addressable events) - coordinates of the event (kind:pubkey:d-tag)
  - `k` tag (optional) - kind number of the reacted event
  - `emoji` tag (for custom emoji) - NIP-30 custom emoji definition

  Kind 17 (external content reactions):
  - `k` + `i` tags per NIP-73 for external content reference
  """
  @moduledoc tags: [:event, :nip25], nip: 25

  defstruct [
    :event,
    :user,
    :reaction,
    :author,
    :post,
    :relay_hint,
    :kind,
    :address,
    :emoji_url
  ]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          user: binary(),
          author: binary() | nil,
          post: binary() | nil,
          relay_hint: binary() | nil,
          kind: non_neg_integer() | nil,
          address: binary() | nil,
          emoji_url: binary() | nil,
          reaction: String.t()
        }

  @doc """
  Parses a kind 7 event into a `Reaction` struct.

  Per NIP-25, if multiple `e` or `p` tags exist, the last one is the target.
  """
  @spec parse(event :: Nostr.Event.t()) :: t() | {:error, String.t(), Nostr.Event.t()}
  def parse(%Nostr.Event{kind: 7} = event) do
    case get_post(event) do
      {:ok, event_id, relay_hint} ->
        %__MODULE__{
          event: event,
          user: event.pubkey,
          author: get_author(event),
          post: event_id,
          relay_hint: relay_hint,
          kind: get_kind(event),
          address: get_address(event),
          emoji_url: get_emoji_url(event),
          reaction: event.content
        }

      {:error, _reason, _event} = error ->
        error
    end
  end

  @doc """
  Creates a new reaction event (kind 7).

  ## Arguments

  - `event_id` - the ID of the event being reacted to
  - `reaction` - the reaction content (`+`, `-`, emoji, or `:shortcode:`)
  - `opts` - keyword options:
    - `:pubkey` - pubkey of the reactor (required for unsigned events)
    - `:author` - pubkey of the event author (recommended)
    - `:relay_hint` - relay URL where the reacted event can be found
    - `:kind` - kind number of the reacted event
    - `:address` - for addressable events, the `kind:pubkey:d-tag` coordinates
    - `:emoji_url` - URL for custom emoji (when reaction is `:shortcode:`)
    - `:tags` - additional tags to include
    - `:created_at` - timestamp (defaults to now)

  ## Examples

      # Simple like
      Reaction.create("event_id", "+", author: "author_pubkey")

      # Reaction with relay hint
      Reaction.create("event_id", "+",
        author: "author_pubkey",
        relay_hint: "wss://relay.example.com",
        kind: 1
      )

      # Custom emoji reaction
      Reaction.create("event_id", ":soapbox:",
        author: "author_pubkey",
        emoji_url: "https://example.com/soapbox.png"
      )
  """
  @spec create(event_id :: binary(), reaction :: String.t(), opts :: Keyword.t()) :: t()
  def create(event_id, reaction \\ "+", opts \\ []) do
    author = Keyword.get(opts, :author)
    relay_hint = Keyword.get(opts, :relay_hint)
    kind = Keyword.get(opts, :kind)
    address = Keyword.get(opts, :address)
    emoji_url = Keyword.get(opts, :emoji_url)
    extra_tags = Keyword.get(opts, :tags, [])

    tags = build_tags(event_id, author, relay_hint, kind, address, emoji_url, reaction)
    event_opts = Keyword.merge(opts, content: reaction, tags: tags ++ extra_tags)

    7
    |> Nostr.Event.create(event_opts)
    |> parse()
  end

  defp build_tags(event_id, author, relay_hint, kind, address, emoji_url, reaction) do
    e_tag = build_e_tag(event_id, relay_hint, author)
    p_tag = if author, do: [build_p_tag(author, relay_hint)], else: []
    k_tag = if kind, do: [Nostr.Tag.create(:k, Integer.to_string(kind))], else: []
    a_tag = if address, do: [build_a_tag(address, relay_hint, author)], else: []
    emoji_tag = build_emoji_tag(reaction, emoji_url)

    [e_tag] ++ p_tag ++ k_tag ++ a_tag ++ emoji_tag
  end

  defp build_e_tag(event_id, relay_hint, author) do
    info =
      case {relay_hint, author} do
        {nil, nil} -> []
        {relay, nil} -> [relay]
        {nil, pubkey} -> ["", pubkey]
        {relay, pubkey} -> [relay, pubkey]
      end

    Nostr.Tag.create(:e, event_id, info)
  end

  defp build_p_tag(pubkey, relay_hint) do
    info = if relay_hint, do: [relay_hint], else: []
    Nostr.Tag.create(:p, pubkey, info)
  end

  defp build_a_tag(address, relay_hint, author) do
    info =
      case {relay_hint, author} do
        {nil, nil} -> []
        {relay, nil} -> [relay]
        {nil, pubkey} -> ["", pubkey]
        {relay, pubkey} -> [relay, pubkey]
      end

    Nostr.Tag.create(:a, address, info)
  end

  defp build_emoji_tag(reaction, emoji_url) do
    with true <- is_binary(emoji_url),
         [_full_match, shortcode] <- Regex.run(~r/^:([a-zA-Z0-9_]+):$/, reaction) do
      [Nostr.Tag.create(:emoji, shortcode, [emoji_url])]
    else
      _other -> []
    end
  end

  # Get last p tag's pubkey (per NIP-25, target should be last)
  defp get_author(%Nostr.Event{tags: tags}) do
    tags
    |> Enum.filter(&(&1.type == :p))
    |> List.last()
    |> case do
      %Nostr.Tag{data: pubkey} -> pubkey
      nil -> nil
    end
  end

  # Get last e tag's event ID and relay hint (per NIP-25, target should be last)
  defp get_post(%Nostr.Event{tags: tags} = event) do
    tags
    |> Enum.filter(&(&1.type == :e))
    |> List.last()
    |> case do
      %Nostr.Tag{data: event_id, info: info} ->
        relay_hint = List.first(info)
        {:ok, event_id, relay_hint}

      nil ->
        {:error, "Cannot find post tag", event}
    end
  end

  # Get k tag value as integer
  defp get_kind(%Nostr.Event{tags: tags}) do
    case Enum.find(tags, &(&1.type == :k)) do
      %Nostr.Tag{data: kind_str} -> String.to_integer(kind_str)
      nil -> nil
    end
  end

  # Get a tag for addressable events
  defp get_address(%Nostr.Event{tags: tags}) do
    case Enum.find(tags, &(&1.type == :a)) do
      %Nostr.Tag{data: address} -> address
      nil -> nil
    end
  end

  # Get emoji URL from emoji tag when content is :shortcode:
  defp get_emoji_url(%Nostr.Event{tags: tags, content: content}) do
    with [_full_match, shortcode] <- Regex.run(~r/^:([a-zA-Z0-9_]+):$/, content),
         %Nostr.Tag{data: ^shortcode, info: [url | _rest]} <-
           Enum.find(tags, &(&1.type == :emoji && &1.data == shortcode)) do
      url
    else
      _other -> nil
    end
  end
end
