defmodule Nostr.Event.ClientAuth do
  @moduledoc """
  Client authentication

  Defined in NIP 42
  https://github.com/nostr-protocol/nips/blob/master/42.md
  """
  @moduledoc tags: [:event, :nip42], nip: 42

  defstruct [:event, :relay, :challenge]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          challenge: String.t(),
          relay: URI.t()
        }

  @doc """
  Create a new ClientAuth event for authentication.

  ## Arguments:

    - `relay` - the relay URL to authenticate with
    - `challenge` - the challenge string received from the relay
    - `opts` - other optional event arguments (`pubkey`, `created_at`, `tags`)

  ## Example:

      iex> auth = Nostr.Event.ClientAuth.create("wss://relay.example.com", "challenge123")
      iex> auth.relay
      "wss://relay.example.com"
      iex> auth.challenge
      "challenge123"
      iex> auth.event.kind
      22242

  """
  @spec create(relay :: String.t(), challenge :: String.t(), opts :: Keyword.t()) :: t()
  def create(relay, challenge, opts \\ []) do
    tags = [
      Nostr.Tag.create(:relay, relay),
      Nostr.Tag.create(:challenge, challenge)
    ]

    opts = Keyword.update(opts, :tags, tags, &(tags ++ &1))

    22_242
    |> Nostr.Event.create(opts)
    |> parse()
  end

  @doc "Parses a kind 22242 event into a `ClientAuth` struct with relay and challenge."
  @spec parse(event :: Nostr.Event.t()) :: __MODULE__.t()
  def parse(%Nostr.Event{kind: 22_242} = event) do
    %__MODULE__{
      event: event,
      relay: get_tag(event, :relay),
      challenge: get_tag(event, :challenge)
    }
  end

  defp get_tag(%Nostr.Event{tags: tags}, tag) do
    tags
    |> Enum.find(&(&1.type == tag))
    |> Map.get(:data)
  end
end
