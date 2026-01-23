defmodule Nostr.Event.RelayList do
  @moduledoc """
  Relay List Metadata (Kind 10002)

  Advertises relays where the user publishes to (write) and where they expect
  to receive mentions (read). This helps clients discover where to find a user's
  events and where to send tagged events.

  ## Relay Markers

  - No marker: Relay is used for both read and write
  - `read`: Relay is used only for receiving mentions
  - `write`: Relay is used only for publishing

  Defined in NIP 65
  https://github.com/nostr-protocol/nips/blob/master/65.md

  Also referenced in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51, :nip65], nip: 65

  alias Nostr.Event
  alias Nostr.NIP51
  alias Nostr.Tag

  defstruct [:event, relays: []]

  @type relay_entry() :: %{
          url: URI.t(),
          marker: :read | :write | :both
        }

  @type t() :: %__MODULE__{
          event: Event.t(),
          relays: [relay_entry()]
        }

  @doc """
  Parses a kind 10002 event into a `RelayList` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 10_002} = event) do
    relays =
      event
      |> NIP51.get_tags_by_type(:r)
      |> Enum.map(&parse_relay_tag/1)

    %__MODULE__{
      event: event,
      relays: relays
    }
  end

  @doc """
  Creates a new relay list metadata event (kind 10002).

  ## Arguments

    - `relays` - List of relay entries (see formats below)
    - `opts` - Optional event arguments (`pubkey`, `created_at`)

  ## Relay Entry Formats

  Relays can be specified as:
  - `"wss://relay.com"` - URL string (both read and write)
  - `{"wss://relay.com", :read}` - Tuple with marker
  - `{"wss://relay.com", :write}` - Tuple with marker
  - `{"wss://relay.com", :both}` - Tuple with marker (same as no marker)
  - `%{url: "wss://...", marker: :read}` - Map format

  ## Example

      iex> RelayList.create([
      ...>   "wss://relay1.com",
      ...>   {"wss://relay2.com", :write},
      ...>   {"wss://relay3.com", :read}
      ...> ])
  """
  @spec create([binary() | tuple() | map()], Keyword.t()) :: t()
  def create(relays, opts \\ []) when is_list(relays) do
    tags = Enum.map(relays, &build_relay_tag/1)
    opts = Keyword.merge(opts, tags: tags, content: "")

    10_002
    |> Event.create(opts)
    |> parse()
  end

  @doc """
  Returns relays marked for reading (includes :read and :both).
  """
  @spec read_relays(t()) :: [URI.t()]
  def read_relays(%__MODULE__{relays: relays}) do
    relays
    |> Enum.filter(fn %{marker: m} -> m in [:read, :both] end)
    |> Enum.map(fn %{url: url} -> url end)
  end

  @doc """
  Returns relays marked for writing (includes :write and :both).
  """
  @spec write_relays(t()) :: [URI.t()]
  def write_relays(%__MODULE__{relays: relays}) do
    relays
    |> Enum.filter(fn %{marker: m} -> m in [:write, :both] end)
    |> Enum.map(fn %{url: url} -> url end)
  end

  # Private functions

  defp parse_relay_tag(%Tag{data: url, info: []}) do
    %{url: URI.parse(url), marker: :both}
  end

  defp parse_relay_tag(%Tag{data: url, info: ["read" | _rest]}) do
    %{url: URI.parse(url), marker: :read}
  end

  defp parse_relay_tag(%Tag{data: url, info: ["write" | _rest]}) do
    %{url: URI.parse(url), marker: :write}
  end

  defp build_relay_tag(url) when is_binary(url) do
    Tag.create(:r, url)
  end

  defp build_relay_tag({url, :both}) when is_binary(url) do
    Tag.create(:r, url)
  end

  defp build_relay_tag({url, :read}) when is_binary(url) do
    Tag.create(:r, url, ["read"])
  end

  defp build_relay_tag({url, :write}) when is_binary(url) do
    Tag.create(:r, url, ["write"])
  end

  defp build_relay_tag(%{url: url, marker: :both}) do
    Tag.create(:r, to_string(url))
  end

  defp build_relay_tag(%{url: url, marker: marker}) when marker in [:read, :write] do
    Tag.create(:r, to_string(url), [Atom.to_string(marker)])
  end
end
