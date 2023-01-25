defmodule Nostr.Event.Regular do
  @moduledoc """
  Regular event

  Defined in NIP 16
  https://github.com/nostr-protocol/nips/blob/master/16.md
  """
  @moduledoc tags: [:event, :nip16], nip: 16

  defstruct [:event]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t()
        }

  @spec parse(event :: Nostr.Event.t()) :: __MODULE__.t()
  def parse(%Nostr.Event{kind: kind} = event) when kind >= 1000 and kind < 10_000 do
    %__MODULE__{event: event}
  end
end
