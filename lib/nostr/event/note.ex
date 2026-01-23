defmodule Nostr.Event.Note do
  @moduledoc """
  Text notes and threads (Kind 1)

  Implements NIP-01 (basic notes), NIP-10 (threading), and NIP-14 (subject tags).

  ## NIP-10 Threading

  Notes can reference other notes using `e` tags with markers:
  - `root` - The root event of the thread
  - `reply` - The direct parent event being replied to

  For top-level replies (direct reply to root), only the `root` marker is used.
  For nested replies, both `root` and `reply` markers are used.

  ## NIP-14 Subject Tags

  Notes can have a subject tag for email-like threading display:

      Note.create("Hello!", subject: "Introduction")

  When replying, the subject is automatically replicated with "Re:" prefix.

  ## Quoting Events

  Notes can quote other events using `q` tags. Quoted events should be
  referenced in the content with NIP-21 URIs (e.g., `nostr:nevent1...`).

  ## Examples

      # Create a simple note
      Note.create("Hello world!")

      # Create a note with a subject
      Note.create("Let's discuss this", subject: "Meeting Notes")

      # Create a reply to a note
      Note.reply("I agree!", parent_note)

      # Create a note with a quote
      Note.quote("Check this out: nostr:nevent1...", %{id: "abc123"})

  See:
  - https://github.com/nostr-protocol/nips/blob/master/01.md
  - https://github.com/nostr-protocol/nips/blob/master/10.md
  - https://github.com/nostr-protocol/nips/blob/master/14.md
  - https://github.com/nostr-protocol/nips/blob/master/30.md
  - https://github.com/nostr-protocol/nips/blob/master/36.md
  """
  @moduledoc tags: [:event, :nip01, :nip10, :nip14, :nip30, :nip36], nip: [1, 10, 14, 30, 36]

  alias Nostr.Tag

  @typedoc "Event reference with optional relay and author hints"
  @type event_ref() :: %{
          id: binary(),
          relay: binary() | nil,
          pubkey: binary() | nil,
          marker: :root | :reply | nil
        }

  @typedoc "Quote reference (q tag)"
  @type quote_ref() :: %{
          id: binary(),
          relay: binary() | nil,
          pubkey: binary() | nil
        }

  defstruct [
    :event,
    :note,
    :author,
    # NIP-10 thread structure
    :root,
    :reply_to,
    :mentions,
    :quotes,
    :participants,
    # NIP-14 subject tag
    :subject,
    # NIP-30 custom emoji
    :emojis,
    # NIP-36 content warning
    :content_warning,
    # Legacy format indicator
    :is_legacy_format
  ]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          note: String.t(),
          author: binary(),
          root: event_ref() | nil,
          reply_to: event_ref() | nil,
          mentions: [event_ref()],
          quotes: [quote_ref()],
          participants: [binary()],
          subject: String.t() | nil,
          emojis: %{binary() => binary()},
          content_warning: Nostr.NIP36.warning(),
          is_legacy_format: boolean()
        }

  @doc """
  Parses a kind 1 event into a Note struct.

  Extracts thread structure from e tags (with NIP-10 markers if present),
  quote references from q tags, and participants from p tags.

  Events with marked e tags (root/reply) are parsed using the preferred NIP-10 format.
  Events without markers fall back to deprecated positional parsing.
  """
  @spec parse(event :: Nostr.Event.t()) :: t()
  def parse(%Nostr.Event{kind: 1} = event) do
    e_refs = parse_e_tags(event.tags)
    has_markers = Enum.any?(e_refs, &(&1.marker != nil))

    {root, reply_to, mentions, is_legacy} =
      if has_markers do
        resolve_thread_marked(e_refs)
      else
        resolve_thread_positional(e_refs)
      end

    %__MODULE__{
      event: event,
      note: event.content,
      author: event.pubkey,
      root: root,
      reply_to: reply_to,
      mentions: mentions,
      quotes: parse_q_tags(event.tags),
      participants: parse_p_tags(event.tags),
      subject: parse_subject_tag(event.tags),
      emojis: Nostr.NIP30.from_tags(event.tags),
      content_warning: Nostr.NIP36.from_tags(event.tags),
      is_legacy_format: is_legacy
    }
  end

  @doc """
  Create a new Note event.

  ## Options

    - `:pubkey` - author pubkey
    - `:created_at` - timestamp
    - `:tags` - additional tags
    - `:root` - thread root event reference (map with :id, optional :relay, :pubkey)
    - `:reply_to` - direct parent event reference
    - `:quotes` - list of quoted event references
    - `:participants` - list of pubkeys to notify
    - `:subject` - NIP-14 subject tag for email-like threading (should be < 80 chars)
    - `:emojis` - NIP-30 custom emoji map `%{"shortcode" => "url"}`
    - `:content_warning` - NIP-36 content warning (string reason or `true` for no reason)

  ## Examples

      Note.create("Hello world!")

      Note.create("Let's discuss this", subject: "Meeting Notes")

      Note.create("This is a reply!", root: %{id: "abc123", relay: "wss://relay.example.com"})

      Note.create("Hello :wave:!", emojis: %{"wave" => "https://example.com/wave.png"})

      Note.create("Sensitive content", content_warning: "Spoilers")

  """
  @spec create(note :: String.t(), opts :: Keyword.t()) :: t()
  def create(note, opts \\ []) do
    thread_tags = build_thread_tags(opts)
    existing_tags = Keyword.get(opts, :tags, [])
    all_tags = thread_tags ++ existing_tags

    opts =
      opts
      |> Keyword.put(:content, note)
      |> Keyword.put(:tags, all_tags)

    1
    |> Nostr.Event.create(opts)
    |> parse()
  end

  @doc """
  Create a reply to an existing note.

  For top-level replies (direct reply to root), only the root marker is used.
  For nested replies, both root and reply markers are used.

  Automatically collects participants from the parent note's author and participants.

  ## Examples

      # Reply to a root note
      Note.reply("I agree!", root_note)

      # Reply to a nested reply (preserves thread root)
      Note.reply("Me too!", nested_reply)

  """
  @spec reply(content :: String.t(), parent :: t() | map(), opts :: Keyword.t()) :: t()
  def reply(content, parent, opts \\ [])

  def reply(content, %__MODULE__{} = parent, opts) do
    root_ref = parent.root || to_ref(parent)
    reply_ref = if parent.root, do: to_ref(parent), else: nil

    participants =
      [parent.author | parent.participants || []]
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    # NIP-14: replicate subject with "Re:" prefix if not already present
    subject = derive_reply_subject(Keyword.get(opts, :subject), parent.subject)

    opts =
      opts
      |> Keyword.merge(
        root: root_ref,
        reply_to: reply_ref,
        participants: participants
      )
      |> maybe_put_subject(subject)

    create(content, opts)
  end

  def reply(content, %{id: _id} = parent_ref, opts) do
    opts = Keyword.merge(opts, root: parent_ref)
    create(content, opts)
  end

  @doc """
  Create a note that quotes another event.

  The quoted event should be referenced in the content with a NIP-21 URI.

  ## Examples

      Note.quote(
        "Check this out: nostr:nevent1...",
        %{id: "abc123", relay: "wss://relay.example.com", pubkey: "def456"}
      )

      Note.quote("Multiple quotes!", [%{id: "abc"}, %{id: "def"}])

  """
  @spec quote_event(
          content :: String.t(),
          quoted :: quote_ref() | [quote_ref()],
          opts :: Keyword.t()
        ) :: t()
  def quote_event(content, quoted, opts \\ []) do
    quotes = List.wrap(quoted)
    opts = Keyword.put(opts, :quotes, quotes)
    create(content, opts)
  end

  # Utility functions

  @doc "Check if this note is a reply (has root reference)"
  @spec reply?(t()) :: boolean()
  def reply?(%__MODULE__{root: root}), do: root != nil

  @doc "Check if this note is a top-level reply (direct reply to root, no intermediate parent)"
  @spec top_level_reply?(t()) :: boolean()
  def top_level_reply?(%__MODULE__{root: root, reply_to: nil}) when root != nil, do: true
  def top_level_reply?(_note), do: false

  @doc "Check if this note quotes other events"
  @spec has_quotes?(t()) :: boolean()
  def has_quotes?(%__MODULE__{quotes: [_first | _rest]}), do: true
  def has_quotes?(_note), do: false

  @doc "Get the thread root event ID"
  @spec thread_root_id(t()) :: binary() | nil
  def thread_root_id(%__MODULE__{root: %{id: id}}), do: id
  def thread_root_id(_note), do: nil

  @doc "Get the direct parent event ID (reply_to if present, otherwise root)"
  @spec parent_id(t()) :: binary() | nil
  def parent_id(%__MODULE__{reply_to: %{id: id}}), do: id
  def parent_id(%__MODULE__{root: %{id: id}}), do: id
  def parent_id(_note), do: nil

  # E-tag parsing

  defp parse_e_tags(tags) do
    tags
    |> Enum.filter(&(&1.type == :e))
    |> Enum.map(&parse_e_tag/1)
  end

  defp parse_e_tag(%Tag{data: id, info: info}) do
    %{
      id: id,
      relay: get_relay(info),
      pubkey: get_pubkey(info),
      marker: get_marker(info)
    }
  end

  defp get_relay([relay | _rest]) when is_binary(relay) and byte_size(relay) > 0, do: relay
  defp get_relay(_info), do: nil

  defp get_marker([_relay, "root" | _rest]), do: :root
  defp get_marker([_relay, "reply" | _rest]), do: :reply
  defp get_marker(_info), do: nil

  defp get_pubkey([_relay, _marker, pubkey | _rest])
       when is_binary(pubkey) and byte_size(pubkey) > 0, do: pubkey

  defp get_pubkey(_info), do: nil

  # Thread resolution - marked tags (preferred NIP-10 format)

  defp resolve_thread_marked(refs) do
    root = Enum.find(refs, &(&1.marker == :root))
    reply = Enum.find(refs, &(&1.marker == :reply))
    mentions = Enum.filter(refs, &(&1.marker == nil))
    {root, reply, mentions, false}
  end

  # Thread resolution - positional tags (deprecated NIP-10 format)

  defp resolve_thread_positional([]), do: {nil, nil, [], true}
  defp resolve_thread_positional([only]), do: {only, nil, [], true}
  defp resolve_thread_positional([root, reply]), do: {root, reply, [], true}

  defp resolve_thread_positional([root | rest]) do
    {mentions, [reply]} = Enum.split(rest, -1)
    {root, reply, mentions, true}
  end

  # Q-tag parsing

  defp parse_q_tags(tags) do
    tags
    |> Enum.filter(&(&1.type == :q))
    |> Enum.map(&parse_q_tag/1)
  end

  defp parse_q_tag(%Tag{data: id, info: info}) do
    %{
      id: id,
      relay: info |> Enum.at(0) |> empty_to_nil(),
      pubkey: info |> Enum.at(1) |> empty_to_nil()
    }
  end

  # P-tag parsing

  defp parse_p_tags(tags) do
    tags
    |> Enum.filter(&(&1.type == :p))
    |> Enum.map(& &1.data)
  end

  # Subject tag parsing (NIP-14)

  defp parse_subject_tag(tags) do
    case Enum.find(tags, &(&1.type == :subject)) do
      %Tag{data: subject} -> subject
      nil -> nil
    end
  end

  # Tag building

  defp build_thread_tags(opts) do
    root_tags = build_root_tag(Keyword.get(opts, :root))
    reply_tags = build_reply_tag(Keyword.get(opts, :reply_to))
    p_tags = build_p_tags(Keyword.get(opts, :participants, []))
    q_tags = build_q_tags(Keyword.get(opts, :quotes, []))
    subject_tags = build_subject_tag(Keyword.get(opts, :subject))
    emoji_tags = build_emoji_tags(Keyword.get(opts, :emojis))
    cw_tags = build_content_warning_tag(Keyword.get(opts, :content_warning))

    root_tags ++ reply_tags ++ p_tags ++ q_tags ++ subject_tags ++ emoji_tags ++ cw_tags
  end

  defp build_root_tag(nil), do: []

  defp build_root_tag(%{id: id} = ref) do
    info = build_e_tag_info(ref, "root")
    [Tag.create(:e, id, info)]
  end

  defp build_reply_tag(nil), do: []

  defp build_reply_tag(%{id: id} = ref) do
    info = build_e_tag_info(ref, "reply")
    [Tag.create(:e, id, info)]
  end

  defp build_e_tag_info(ref, marker) do
    relay = Map.get(ref, :relay) || ""
    pubkey = Map.get(ref, :pubkey)

    if pubkey do
      [relay, marker, pubkey]
    else
      [relay, marker]
    end
  end

  defp build_p_tags(pubkeys) do
    pubkeys
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&Tag.create(:p, &1))
  end

  defp build_q_tags(quotes) do
    Enum.map(quotes, fn
      %{id: id, relay: relay, pubkey: pubkey} when is_binary(relay) and is_binary(pubkey) ->
        Tag.create(:q, id, [relay, pubkey])

      %{id: id, relay: relay} when is_binary(relay) ->
        Tag.create(:q, id, [relay])

      %{id: id} ->
        Tag.create(:q, id)

      id when is_binary(id) ->
        Tag.create(:q, id)
    end)
  end

  defp build_subject_tag(nil), do: []
  defp build_subject_tag(subject) when is_binary(subject), do: [Tag.create(:subject, subject)]

  defp build_content_warning_tag(nil), do: []
  defp build_content_warning_tag(value), do: [Nostr.NIP36.to_tag(value)]

  defp build_emoji_tags(nil), do: []
  defp build_emoji_tags(emojis), do: Nostr.NIP30.build_tags(emojis)

  # NIP-14 subject handling

  defp derive_reply_subject(explicit, _parent_subject) when is_binary(explicit), do: explicit
  defp derive_reply_subject(_explicit, nil), do: nil

  defp derive_reply_subject(_explicit, parent_subject) when is_binary(parent_subject) do
    if String.starts_with?(parent_subject, "Re:") do
      parent_subject
    else
      "Re: " <> parent_subject
    end
  end

  defp maybe_put_subject(opts, nil), do: opts
  defp maybe_put_subject(opts, subject), do: Keyword.put(opts, :subject, subject)

  # Helpers

  defp to_ref(%__MODULE__{event: event}) do
    %{
      id: event.id,
      relay: nil,
      pubkey: event.pubkey
    }
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(nil), do: nil
  defp empty_to_nil(value), do: value
end
