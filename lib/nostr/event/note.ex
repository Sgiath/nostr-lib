defmodule Nostr.Event.Note do
  @moduledoc """
  Text note

  Defined in NIP 01
  https://github.com/nostr-protocol/nips/blob/master/01.md
  """

  defstruct [:event, :note, :author]

  def parse(%Nostr.Event{kind: 1} = event) do
    %__MODULE__{
      event: event,
      author: event.pubkey,
      note: event.content
    }
  end
end
