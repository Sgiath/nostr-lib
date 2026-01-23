defmodule Nostr.Event.MediaFollows do
  @moduledoc """
  Media Follows List (Kind 10020)

  A multimedia (photos, short video) follow list. Similar to the main follow
  list (kind:3) but specifically for media-focused clients. Contains pubkeys
  via `p` tags with optional relay hints and petnames.

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  alias Nostr.Event
  alias Nostr.NIP51
  alias Nostr.Tag

  defstruct [:event, follows: []]

  @type follow_entry() :: %{
          pubkey: binary(),
          relay: URI.t() | nil,
          petname: binary() | nil
        }

  @type t() :: %__MODULE__{
          event: Event.t(),
          follows: [follow_entry()]
        }

  @doc """
  Parses a kind 10020 event into a `MediaFollows` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 10_020} = event) do
    follows =
      event
      |> NIP51.get_tags_by_type(:p)
      |> Enum.map(&parse_follow_tag/1)

    %__MODULE__{
      event: event,
      follows: follows
    }
  end

  @doc """
  Creates a new media follows list (kind 10020).

  ## Arguments

    - `follows` - List of follow entries (see formats below)
    - `opts` - Optional event arguments (`pubkey`, `created_at`)

  ## Follow Entry Formats

  Follows can be specified as:
  - `"pubkey"` - Just the pubkey
  - `{"pubkey", "wss://relay.com"}` - With relay hint
  - `{"pubkey", "wss://relay.com", "petname"}` - With relay and petname
  - `%{pubkey: "...", relay: "...", petname: "..."}` - Map format

  ## Example

      MediaFollows.create([
        "pubkey1",
        {"pubkey2", "wss://relay.com"},
        %{pubkey: "pubkey3", relay: "wss://other.com", petname: "Alice"}
      ])
  """
  @spec create([binary() | tuple() | map()], Keyword.t()) :: t()
  def create(follows, opts \\ []) when is_list(follows) do
    tags = Enum.map(follows, &build_follow_tag/1)
    opts = Keyword.merge(opts, tags: tags, content: "")

    10_020
    |> Event.create(opts)
    |> parse()
  end

  # Private functions

  defp parse_follow_tag(%Tag{data: pubkey, info: []}) do
    %{pubkey: pubkey, relay: nil, petname: nil}
  end

  defp parse_follow_tag(%Tag{data: pubkey, info: [relay]}) do
    relay_uri = if relay == "", do: nil, else: URI.parse(relay)
    %{pubkey: pubkey, relay: relay_uri, petname: nil}
  end

  defp parse_follow_tag(%Tag{data: pubkey, info: [relay, petname | _rest]}) do
    relay_uri = if relay == "", do: nil, else: URI.parse(relay)
    %{pubkey: pubkey, relay: relay_uri, petname: petname}
  end

  defp build_follow_tag(pubkey) when is_binary(pubkey) do
    Tag.create(:p, pubkey)
  end

  defp build_follow_tag({pubkey, relay}) do
    Tag.create(:p, pubkey, [relay])
  end

  defp build_follow_tag({pubkey, relay, petname}) do
    Tag.create(:p, pubkey, [relay, petname])
  end

  defp build_follow_tag(%{pubkey: pubkey, relay: nil, petname: nil}) do
    Tag.create(:p, pubkey)
  end

  defp build_follow_tag(%{pubkey: pubkey, relay: relay, petname: nil}) do
    Tag.create(:p, pubkey, [to_string(relay)])
  end

  defp build_follow_tag(%{pubkey: pubkey, relay: relay, petname: petname}) do
    relay_str = if relay, do: to_string(relay), else: ""
    Tag.create(:p, pubkey, [relay_str, petname])
  end

  defp build_follow_tag(%{pubkey: pubkey}) do
    Tag.create(:p, pubkey)
  end
end
