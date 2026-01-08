defmodule Nostr.Event.Comment do
  @moduledoc """
  Comment (Kind 1111)

  Threading comments for any Nostr event or external content. This is different
  from NIP-10 replies to kind:1 notes - use `Nostr.Event.Note.reply/3` for those.

  ## Tag Scopes

  Comments use uppercase tags for ROOT scope (the original item being commented on)
  and lowercase tags for PARENT scope (the direct parent in a thread).

  ### Root Scope (uppercase):
  - `E` - Event ID reference
  - `A` - Addressable event reference (kind:pubkey:d-tag)
  - `I` - External content identifier (URL, ISBN, etc.)
  - `K` - Root item kind (integer for events, string like "web" for external)
  - `P` - Root author pubkey

  ### Parent Scope (lowercase):
  - `e`, `a`, `i` - Same as above but for direct parent
  - `k` - Parent kind (e.g., "1111" for replies to comments)
  - `p` - Parent author pubkey

  For top-level comments, root and parent reference the same item.
  For replies to comments, root stays the original item, parent is the comment.

  Defined in NIP 22
  https://github.com/nostr-protocol/nips/blob/master/22.md
  """
  @moduledoc tags: [:event, :nip22], nip: 22

  alias Nostr.{Event, Tag}

  defstruct [
    :event,
    :content,
    # Root scope (what is being commented on)
    :root_ref,
    :root_kind,
    :root_author,
    # Parent scope (direct parent - same as root for top-level comments)
    :parent_ref,
    :parent_kind,
    :parent_author,
    # Optional
    quotes: [],
    mentions: []
  ]

  @type ref() :: %{
          type: :E | :A | :I | :e | :a | :i,
          id: binary(),
          relay: binary() | nil,
          pubkey: binary() | nil
        }

  @type author() :: %{pubkey: binary(), relay: binary() | nil}

  @type t() :: %__MODULE__{
          event: Event.t(),
          content: binary(),
          root_ref: ref(),
          root_kind: integer() | binary(),
          root_author: author(),
          parent_ref: ref(),
          parent_kind: integer() | binary(),
          parent_author: author(),
          quotes: [ref()],
          mentions: [author()]
        }

  @doc """
  Parses a kind 1111 event into a `Comment` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 1111} = event) do
    %__MODULE__{
      event: event,
      content: event.content,
      root_ref: parse_root_ref(event),
      root_kind: parse_kind(event, :K),
      root_author: parse_author(event, :P),
      parent_ref: parse_parent_ref(event),
      parent_kind: parse_kind(event, :k),
      parent_author: parse_author(event, :p),
      quotes: parse_quotes(event),
      mentions: parse_mentions(event)
    }
  end

  @doc """
  Creates a top-level comment on an event.

  ## Arguments

    - `content` - Comment text
    - `event_id` - ID of the event being commented on
    - `event_kind` - Kind of the event being commented on
    - `event_author` - Pubkey of the event author
    - `opts` - Optional arguments

  ## Options

    - `:relay` - Relay hint for the target event
    - `:pubkey` - Comment author pubkey
    - `:created_at` - Event timestamp
    - `:quotes` - List of quoted event tuples `{event_id, relay, pubkey}`
    - `:mentions` - List of mentioned pubkey tuples `{pubkey, relay}`

  ## Example

      Comment.comment_on_event(
        "Great article!",
        "abc123...",
        30023,
        "author_pubkey...",
        relay: "wss://relay.example.com"
      )
  """
  @spec comment_on_event(binary(), binary(), integer(), binary(), Keyword.t()) :: t()
  def comment_on_event(content, event_id, event_kind, event_author, opts \\ []) do
    {relay, opts} = Keyword.pop(opts, :relay)
    {quotes, opts} = Keyword.pop(opts, :quotes, [])
    {mentions, opts} = Keyword.pop(opts, :mentions, [])

    ref_info = build_ref_info(relay, event_author)

    tags =
      [
        Tag.create(:E, event_id, ref_info),
        Tag.create(:K, to_string(event_kind)),
        Tag.create(:P, event_author, if(relay, do: [relay], else: [])),
        Tag.create(:e, event_id, ref_info),
        Tag.create(:k, to_string(event_kind)),
        Tag.create(:p, event_author, if(relay, do: [relay], else: []))
      ] ++
        build_quote_tags(quotes) ++
        build_mention_tags(mentions)

    opts = Keyword.merge(opts, tags: tags, content: content)

    1111
    |> Event.create(opts)
    |> parse()
  end

  @doc """
  Creates a top-level comment on an addressable event.

  ## Arguments

    - `content` - Comment text
    - `address` - Address in format "kind:pubkey:d-tag"
    - `event_kind` - Kind of the addressable event
    - `event_author` - Pubkey of the event author
    - `opts` - Optional arguments (same as `comment_on_event/5`)

  ## Example

      Comment.comment_on_address(
        "Interesting perspective",
        "30023:pubkey123:my-article",
        30023,
        "pubkey123..."
      )
  """
  @spec comment_on_address(binary(), binary(), integer(), binary(), Keyword.t()) :: t()
  def comment_on_address(content, address, event_kind, event_author, opts \\ []) do
    {relay, opts} = Keyword.pop(opts, :relay)
    {quotes, opts} = Keyword.pop(opts, :quotes, [])
    {mentions, opts} = Keyword.pop(opts, :mentions, [])

    ref_info = build_ref_info(relay, event_author)

    tags =
      [
        Tag.create(:A, address, ref_info),
        Tag.create(:K, to_string(event_kind)),
        Tag.create(:P, event_author, if(relay, do: [relay], else: [])),
        Tag.create(:a, address, ref_info),
        Tag.create(:k, to_string(event_kind)),
        Tag.create(:p, event_author, if(relay, do: [relay], else: []))
      ] ++
        build_quote_tags(quotes) ++
        build_mention_tags(mentions)

    opts = Keyword.merge(opts, tags: tags, content: content)

    1111
    |> Event.create(opts)
    |> parse()
  end

  @doc """
  Creates a top-level comment on external content.

  ## Arguments

    - `content` - Comment text
    - `identifier` - External identifier (URL, ISBN, podcast GUID, etc.)
    - `kind_type` - Type string (e.g., "web", "podcast:item:guid", "isbn")
    - `opts` - Optional arguments

  ## Options

    - `:hint` - Hint for the identifier (e.g., URL for web content)
    - `:pubkey` - Comment author pubkey
    - `:created_at` - Event timestamp
    - `:quotes` - List of quoted event tuples
    - `:mentions` - List of mentioned pubkey tuples

  ## Example

      Comment.comment_on_external(
        "This is a great resource!",
        "https://example.com/article",
        "web"
      )
  """
  @spec comment_on_external(binary(), binary(), binary(), Keyword.t()) :: t()
  def comment_on_external(content, identifier, kind_type, opts \\ []) do
    {hint, opts} = Keyword.pop(opts, :hint)
    {quotes, opts} = Keyword.pop(opts, :quotes, [])
    {mentions, opts} = Keyword.pop(opts, :mentions, [])

    i_info = if hint, do: [hint], else: []

    tags =
      [
        Tag.create(:I, identifier, i_info),
        Tag.create(:K, kind_type),
        Tag.create(:i, identifier, i_info),
        Tag.create(:k, kind_type)
      ] ++
        build_quote_tags(quotes) ++
        build_mention_tags(mentions)

    opts = Keyword.merge(opts, tags: tags, content: content)

    1111
    |> Event.create(opts)
    |> parse()
  end

  @doc """
  Creates a reply to another comment.

  The root scope is inherited from the parent comment, while parent scope
  references the comment being replied to.

  ## Arguments

    - `content` - Reply text
    - `parent` - The `Comment` struct being replied to
    - `opts` - Optional arguments

  ## Options

    - `:relay` - Relay hint for the parent comment
    - `:pubkey` - Reply author pubkey
    - `:created_at` - Event timestamp
    - `:quotes` - List of quoted event tuples
    - `:mentions` - List of mentioned pubkey tuples

  ## Example

      Comment.reply("I agree!", parent_comment, relay: "wss://relay.example.com")
  """
  @spec reply(binary(), t(), Keyword.t()) :: t()
  def reply(content, %__MODULE__{} = parent, opts \\ []) do
    {relay, opts} = Keyword.pop(opts, :relay)
    {quotes, opts} = Keyword.pop(opts, :quotes, [])
    {mentions, opts} = Keyword.pop(opts, :mentions, [])

    parent_event = parent.event
    parent_id = parent_event.id
    parent_author = parent_event.pubkey

    # Root scope stays the same as parent's root
    root_tags = build_root_tags_from_parent(parent)

    # Parent scope references the comment being replied to
    parent_ref_info = build_ref_info(relay, parent_author)

    parent_tags = [
      Tag.create(:e, parent_id, parent_ref_info),
      Tag.create(:k, "1111"),
      Tag.create(:p, parent_author, if(relay, do: [relay], else: []))
    ]

    tags =
      root_tags ++
        parent_tags ++
        build_quote_tags(quotes) ++
        build_mention_tags(mentions)

    opts = Keyword.merge(opts, tags: tags, content: content)

    1111
    |> Event.create(opts)
    |> parse()
  end

  # Private functions

  defp parse_root_ref(event) do
    cond do
      ref = find_first_tag(event, :E) -> build_ref(:E, ref)
      ref = find_first_tag(event, :A) -> build_ref(:A, ref)
      ref = find_first_tag(event, :I) -> build_ref(:I, ref)
      true -> nil
    end
  end

  defp parse_parent_ref(event) do
    cond do
      ref = find_first_tag(event, :e) -> build_ref(:e, ref)
      ref = find_first_tag(event, :a) -> build_ref(:a, ref)
      ref = find_first_tag(event, :i) -> build_ref(:i, ref)
      true -> nil
    end
  end

  defp build_ref(type, %Tag{data: data, info: info}) do
    %{
      type: type,
      id: data,
      relay: normalize_empty(Enum.at(info, 0)),
      pubkey: normalize_empty(Enum.at(info, 1))
    }
  end

  defp normalize_empty(""), do: nil
  defp normalize_empty(value), do: value

  defp parse_kind(event, tag_type) do
    case find_first_tag(event, tag_type) do
      %Tag{data: kind_str} -> parse_kind_value(kind_str)
      nil -> nil
    end
  end

  defp parse_kind_value(kind_str) do
    case Integer.parse(kind_str) do
      {kind, ""} -> kind
      _ -> kind_str
    end
  end

  defp parse_author(event, tag_type) do
    case find_first_tag(event, tag_type) do
      %Tag{data: pubkey, info: info} ->
        %{pubkey: pubkey, relay: normalize_empty(Enum.at(info, 0))}

      nil ->
        nil
    end
  end

  defp parse_quotes(event) do
    event.tags
    |> Enum.filter(fn %Tag{type: type} -> type == :q end)
    |> Enum.map(fn %Tag{data: data, info: info} ->
      %{
        type: :q,
        id: data,
        relay: normalize_empty(Enum.at(info, 0)),
        pubkey: normalize_empty(Enum.at(info, 1))
      }
    end)
  end

  defp parse_mentions(event) do
    # Find the parent author p tag first
    parent_author =
      case find_first_tag(event, :p) do
        %Tag{data: pubkey} -> pubkey
        nil -> nil
      end

    # Other p tags (after the first one) are mentions
    event.tags
    |> Enum.filter(fn %Tag{type: type} -> type == :p end)
    |> Enum.drop(1)
    |> Enum.reject(fn %Tag{data: pubkey} -> pubkey == parent_author end)
    |> Enum.map(fn %Tag{data: pubkey, info: info} ->
      %{pubkey: pubkey, relay: normalize_empty(Enum.at(info, 0))}
    end)
  end

  defp find_first_tag(event, type) do
    Enum.find(event.tags, fn %Tag{type: t} -> t == type end)
  end

  defp build_ref_info(nil, nil), do: []
  defp build_ref_info(relay, nil), do: [relay]
  defp build_ref_info(nil, pubkey), do: ["", pubkey]
  defp build_ref_info(relay, pubkey), do: [relay, pubkey]

  defp build_quote_tags(quotes) do
    Enum.map(quotes, fn
      {event_id, relay, pubkey} ->
        Tag.create(:q, event_id, build_ref_info(relay, pubkey))

      {event_id, relay} ->
        Tag.create(:q, event_id, if(relay, do: [relay], else: []))

      event_id when is_binary(event_id) ->
        Tag.create(:q, event_id)
    end)
  end

  defp build_mention_tags(mentions) do
    Enum.map(mentions, fn
      {pubkey, relay} ->
        Tag.create(:p, pubkey, if(relay, do: [relay], else: []))

      pubkey when is_binary(pubkey) ->
        Tag.create(:p, pubkey)
    end)
  end

  defp build_root_tags_from_parent(%__MODULE__{
         root_ref: root_ref,
         root_kind: root_kind,
         root_author: root_author
       }) do
    ref_tag =
      case root_ref.type do
        :E -> Tag.create(:E, root_ref.id, build_ref_info(root_ref.relay, root_ref.pubkey))
        :A -> Tag.create(:A, root_ref.id, build_ref_info(root_ref.relay, root_ref.pubkey))
        :I -> Tag.create(:I, root_ref.id, if(root_ref.relay, do: [root_ref.relay], else: []))
      end

    kind_tag = Tag.create(:K, to_string(root_kind))

    author_tag =
      if root_author do
        Tag.create(
          :P,
          root_author.pubkey,
          if(root_author.relay, do: [root_author.relay], else: [])
        )
      end

    [ref_tag, kind_tag | if(author_tag, do: [author_tag], else: [])]
  end
end
