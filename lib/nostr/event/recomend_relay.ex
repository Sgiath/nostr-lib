defmodule Nostr.Event.RecommendRelay do
  @moduledoc """
  Recommend server

  Defined in NIP 01
  https://github.com/nostr-protocol/nips/blob/master/01.md
  """
  @moduledoc tags: [:event, :nip01], nip: 01

  defstruct [:event, :user, :relay]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          user: <<_::32, _::_*8>>,
          relay: URI.t()
        }

  @spec parse(event :: Nostr.Event.t()) :: __MODULE__.t()
  def parse(%Nostr.Event{kind: 2} = event) do
    %__MODULE__{
      event: event,
      user: event.pubkey,
      relay: URI.parse(event.content)
    }
  end
end
