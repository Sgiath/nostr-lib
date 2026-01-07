defmodule Nostr.Event.RecommendRelay do
  @moduledoc """
  Recommend server

  DEPRECATED - This event kind is no longer recommended

  Defined in NIP 01
  https://github.com/nostr-protocol/nips/blob/master/01.md
  """
  @moduledoc tags: [:event, :nip01],
             nip: 01,
             deprecated: "This event kind is no longer recommended"

  require Logger

  defstruct [:event, :user, :relay]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          user: <<_::32, _::_*8>>,
          relay: URI.t()
        }

  @doc "Parses a kind 2 event into a `RecommendRelay` struct with the relay URL. Logs a deprecation warning."
  @spec parse(event :: Nostr.Event.t()) :: __MODULE__.t()
  def parse(%Nostr.Event{kind: 2} = event) do
    Logger.warning("RecommendRelay event (kind 2) is deprecated")

    %__MODULE__{
      event: event,
      user: event.pubkey,
      relay: URI.parse(event.content)
    }
  end
end
