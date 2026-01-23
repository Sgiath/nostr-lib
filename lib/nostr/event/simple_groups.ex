defmodule Nostr.Event.SimpleGroups do
  @moduledoc """
  Simple Groups List (Kind 10009)

  A list of NIP-29 groups the user is in. Contains references to groups via
  `group` tags (group id + relay URL + optional name) and `r` tags for relays.

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  alias Nostr.Event
  alias Nostr.NIP51
  alias Nostr.Tag

  defstruct [:event, groups: [], relays: []]

  @type group_entry() :: %{
          id: binary(),
          relay: URI.t(),
          name: binary() | nil
        }

  @type t() :: %__MODULE__{
          event: Event.t(),
          groups: [group_entry()],
          relays: [URI.t()]
        }

  @doc """
  Parses a kind 10009 event into a `SimpleGroups` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 10_009} = event) do
    groups =
      event
      |> NIP51.get_tags_by_type(:group)
      |> Enum.map(&parse_group_tag/1)

    relays =
      event
      |> NIP51.get_tag_values(:r)
      |> Enum.map(&URI.parse/1)

    %__MODULE__{
      event: event,
      groups: groups,
      relays: relays
    }
  end

  @doc """
  Creates a new simple groups list (kind 10009).

  ## Arguments

    - `groups` - List of group entries (see formats below)
    - `opts` - Optional event arguments, including `:relays` for `r` tags

  ## Group Entry Formats

  Groups can be specified as:
  - `%{id: "group-id", relay: "wss://relay.com"}` - Map with id and relay
  - `%{id: "group-id", relay: "wss://relay.com", name: "Group Name"}` - With optional name
  - `{"group-id", "wss://relay.com"}` - Tuple format
  - `{"group-id", "wss://relay.com", "Group Name"}` - Tuple with name

  ## Options

    - `:relays` - List of relay URLs to include as `r` tags
    - `:pubkey` - Event author pubkey
    - `:created_at` - Event timestamp

  ## Example

      SimpleGroups.create([
        %{id: "group1", relay: "wss://relay.com"},
        {"group2", "wss://other-relay.com", "My Group"}
      ], relays: ["wss://relay.com", "wss://other-relay.com"])
  """
  @spec create([map() | tuple()], Keyword.t()) :: t()
  def create(groups, opts \\ []) when is_list(groups) do
    {relays, opts} = Keyword.pop(opts, :relays, [])

    group_tags = Enum.map(groups, &build_group_tag/1)
    relay_tags = Enum.map(relays, &Tag.create(:r, &1))
    tags = group_tags ++ relay_tags

    opts = Keyword.merge(opts, tags: tags, content: "")

    10_009
    |> Event.create(opts)
    |> parse()
  end

  # Private functions

  defp parse_group_tag(%Tag{data: id, info: []}) do
    %{id: id, relay: nil, name: nil}
  end

  defp parse_group_tag(%Tag{data: id, info: [relay]}) do
    %{id: id, relay: URI.parse(relay), name: nil}
  end

  defp parse_group_tag(%Tag{data: id, info: [relay, name | _rest]}) do
    %{id: id, relay: URI.parse(relay), name: name}
  end

  defp build_group_tag(%{id: id, relay: relay, name: name}) when is_binary(name) do
    Tag.create(:group, id, [to_string(relay), name])
  end

  defp build_group_tag(%{id: id, relay: relay}) do
    Tag.create(:group, id, [to_string(relay)])
  end

  defp build_group_tag({id, relay, name}) do
    Tag.create(:group, id, [relay, name])
  end

  defp build_group_tag({id, relay}) do
    Tag.create(:group, id, [relay])
  end
end
