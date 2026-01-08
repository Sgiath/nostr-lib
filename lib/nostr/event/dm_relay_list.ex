defmodule Nostr.Event.DMRelayList do
  @moduledoc """
  DM Relay List (Kind 10050)

  Indicates the user's preferred relays for receiving direct messages per NIP-17.
  This is a replaceable event that clients should publish to help others find
  where to send encrypted DMs.

  Defined in NIP 17
  https://github.com/nostr-protocol/nips/blob/master/17.md
  """
  @moduledoc tags: [:event, :nip17], nip: 17

  alias Nostr.Tag

  defstruct [:event, :relays]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          relays: [URI.t()]
        }

  @doc """
  Create a new DM relay list event

  ## Arguments

    - `relays` - list of relay URIs (strings)
    - `opts` - optional event arguments (`pubkey`, `created_at`)

  ## Example

      iex> list = Nostr.Event.DMRelayList.create(["wss://relay1.com", "wss://relay2.com"])
      iex> length(list.relays)
      2
      iex> list.event.kind
      10050
  """
  @spec create(relays :: [binary()], opts :: Keyword.t()) :: t()
  def create(relays, opts \\ []) when is_list(relays) do
    tags = Enum.map(relays, &Tag.create(:relay, &1))
    opts = Keyword.merge(opts, tags: tags, content: "")

    10050
    |> Nostr.Event.create(opts)
    |> parse()
  end

  @doc """
  Parse a kind 10050 event into a DMRelayList struct
  """
  @spec parse(Nostr.Event.t()) :: t()
  def parse(%Nostr.Event{kind: 10050} = event) do
    %__MODULE__{
      event: event,
      relays: get_relays(event)
    }
  end

  defp get_relays(%Nostr.Event{tags: tags}) do
    tags
    |> Enum.filter(fn %Tag{type: type} -> type == :relay end)
    |> Enum.map(fn %Tag{data: relay} -> URI.parse(relay) end)
  end
end
