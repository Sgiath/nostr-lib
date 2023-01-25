defmodule Nostr.Event.ClientAuth do
  @moduledoc """
  Client authentication

  Defined in NIP 42
  https://github.com/nostr-protocol/nips/blob/master/42.md
  """

  defstruct [:event, :relay, :challenge]

  def parse(%Nostr.Event{kind: 22242} = event) do
    %__MODULE__{
      event: event,
      relay: Enum.find(event.tags, &(&1.type == :relay)).data,
      challenge: Enum.find(event.tags, &(&1.type == :challenge)).data
    }
  end
end
