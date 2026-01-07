defmodule Nostr.Event.Ephemeral do
  @moduledoc """
  Ephemeral event

  Defined in NIP 16
  https://github.com/nostr-protocol/nips/blob/master/16.md
  """
  @moduledoc tags: [:event, :nip16], nip: 16

  defstruct [:event, :user]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          user: <<_::32, _::_*8>>
        }

  @doc "Parses a kind 20000-29999 event into an `Ephemeral` struct (not stored by relays)."
  @spec parse(event :: Nostr.Event.t()) :: __MODULE__.t()
  def parse(%Nostr.Event{kind: kind} = event) when kind >= 20_000 and kind < 30_000 do
    %__MODULE__{event: event, user: event.pubkey}
  end
end
