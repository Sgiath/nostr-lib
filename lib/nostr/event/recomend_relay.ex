defmodule Nostr.Event.RecommendRelay do
  @moduledoc """
  Recommend server

  Defined in NIP 01
  https://github.com/nostr-protocol/nips/blob/master/01.md
  """

  defstruct [:event, :user, :relay]

  def parse(%Nostr.Event{kind: 2} = event) do
    %__MODULE__{
      event: event,
      user: event.pubkey,
      relay: URI.parse(event.content)
    }
  end
end
