defmodule Nostr.Event.Label do
  @moduledoc """
  Label (Kind 1985)

  Attach labels to events, pubkeys, relays, or topics for distributed moderation,
  content classification, license assignment, and other labeling use cases.

  ## Label Structure

  Labels use two tag types:
  - `L` tags define label namespaces (e.g., "license", "com.example.ontology")
  - `l` tags define actual labels with a namespace mark

  ## Target Types

  Labels can target:
  - Events (`e` tags)
  - Pubkeys (`p` tags)
  - Addressable events (`a` tags)
  - Relays (`r` tags)
  - Topics (`t` tags)

  ## Self-Labeling

  `L` and `l` tags can be added to non-1985 events for self-reporting.
  In that case, the labels refer to the event itself.

  Defined in NIP 32
  https://github.com/nostr-protocol/nips/blob/master/32.md
  """
  @moduledoc tags: [:event, :nip32], nip: 32

  alias Nostr.{Event, Tag}

  defstruct [
    :event,
    namespaces: [],
    labels: [],
    events: [],
    pubkeys: [],
    addresses: [],
    relays: [],
    topics: []
  ]

  @type t() :: %__MODULE__{
          event: Event.t(),
          namespaces: [binary()],
          labels: [{binary(), binary()}],
          events: [{binary(), binary() | nil}],
          pubkeys: [{binary(), binary() | nil}],
          addresses: [{binary(), binary() | nil}],
          relays: [binary()],
          topics: [binary()]
        }

  @doc """
  Parses a kind 1985 event into a `Label` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 1985} = event) do
    %__MODULE__{
      event: event,
      namespaces: get_namespaces(event),
      labels: get_labels(event),
      events: get_target_events(event),
      pubkeys: get_target_pubkeys(event),
      addresses: get_target_addresses(event),
      relays: get_target_relays(event),
      topics: get_target_topics(event)
    }
  end

  @doc """
  Creates a label event (kind 1985).

  ## Arguments

    - `labels` - List of labels. Each label can be:
      - `{label, namespace}` tuple
      - Just a string (uses "ugc" as default namespace)
    - `targets` - Map with target keys:
      - `:events` - List of event IDs or `{event_id, relay_hint}` tuples
      - `:pubkeys` - List of pubkeys or `{pubkey, relay_hint}` tuples
      - `:addresses` - List of addresses or `{address, relay_hint}` tuples
      - `:relays` - List of relay URLs
      - `:topics` - List of topics/hashtags
    - `opts` - Optional event arguments

  ## Options

    - `:content` - Explanation for the labeling
    - `:pubkey` - Event author pubkey
    - `:created_at` - Event timestamp

  ## Examples

      # Label an event with a license
      Label.create(
        [{"MIT", "license"}],
        %{events: ["abc123..."]}
      )

      # Label pubkeys with a topic association
      Label.create(
        [{"permies", "#t"}],
        %{pubkeys: [{"pubkey1", "wss://relay.example.com"}, "pubkey2"]}
      )

      # Moderation label with explanation
      Label.create(
        [{"approve", "nip28.moderation"}],
        %{events: ["event_id"]},
        content: "Reviewed and approved for channel"
      )
  """
  @spec create([{binary(), binary()} | binary()], map(), Keyword.t()) :: t()
  def create(labels, targets, opts \\ []) when is_list(labels) and is_map(targets) do
    {content, opts} = Keyword.pop(opts, :content, "")

    # Extract unique namespaces from labels
    namespaces =
      labels
      |> Enum.map(fn
        {_label, namespace} -> namespace
        _label -> "ugc"
      end)
      |> Enum.uniq()

    # Build namespace tags (L)
    namespace_tags = Enum.map(namespaces, &Tag.create(:L, &1))

    # Build label tags (l)
    label_tags =
      Enum.map(labels, fn
        {label, namespace} -> Tag.create(:l, label, [namespace])
        label -> Tag.create(:l, label, ["ugc"])
      end)

    # Build target tags
    event_tags = build_target_tags(:e, Map.get(targets, :events, []))
    pubkey_tags = build_target_tags(:p, Map.get(targets, :pubkeys, []))
    address_tags = build_target_tags(:a, Map.get(targets, :addresses, []))
    relay_tags = Enum.map(Map.get(targets, :relays, []), &Tag.create(:r, &1))
    topic_tags = Enum.map(Map.get(targets, :topics, []), &Tag.create(:t, &1))

    tags =
      namespace_tags ++
        label_tags ++
        event_tags ++
        pubkey_tags ++
        address_tags ++
        relay_tags ++
        topic_tags

    opts = Keyword.merge(opts, tags: tags, content: content)

    1985
    |> Event.create(opts)
    |> parse()
  end

  # Private functions

  defp get_namespaces(%Event{tags: tags}) do
    tags
    |> Enum.filter(fn %Tag{type: type} -> type == :L end)
    |> Enum.map(fn %Tag{data: data} -> data end)
  end

  defp get_labels(%Event{tags: tags}) do
    tags
    |> Enum.filter(fn %Tag{type: type} -> type == :l end)
    |> Enum.map(fn %Tag{data: data, info: info} ->
      namespace = List.first(info) || "ugc"
      {data, namespace}
    end)
  end

  defp get_target_events(%Event{tags: tags}) do
    tags
    |> Enum.filter(fn %Tag{type: type} -> type == :e end)
    |> Enum.map(fn %Tag{data: data, info: info} ->
      {data, normalize_empty(List.first(info))}
    end)
  end

  defp get_target_pubkeys(%Event{tags: tags}) do
    tags
    |> Enum.filter(fn %Tag{type: type} -> type == :p end)
    |> Enum.map(fn %Tag{data: data, info: info} ->
      {data, normalize_empty(List.first(info))}
    end)
  end

  defp get_target_addresses(%Event{tags: tags}) do
    tags
    |> Enum.filter(fn %Tag{type: type} -> type == :a end)
    |> Enum.map(fn %Tag{data: data, info: info} ->
      {data, normalize_empty(List.first(info))}
    end)
  end

  defp get_target_relays(%Event{tags: tags}) do
    tags
    |> Enum.filter(fn %Tag{type: type} -> type == :r end)
    |> Enum.map(fn %Tag{data: data} -> data end)
  end

  defp get_target_topics(%Event{tags: tags}) do
    tags
    |> Enum.filter(fn %Tag{type: type} -> type == :t end)
    |> Enum.map(fn %Tag{data: data} -> data end)
  end

  defp normalize_empty(""), do: nil
  defp normalize_empty(value), do: value

  defp build_target_tags(type, targets) do
    Enum.map(targets, fn
      {id, relay} when is_binary(relay) and relay != "" ->
        Tag.create(type, id, [relay])

      {id, _nil_or_empty} ->
        Tag.create(type, id)

      id when is_binary(id) ->
        Tag.create(type, id)
    end)
  end
end
