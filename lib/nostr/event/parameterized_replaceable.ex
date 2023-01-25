defmodule Nostr.Event.ParameterizedReplaceable do
  @moduledoc """
  Parameterized replaceable event

  Defined in NIP 33
  https://github.com/nostr-protocol/nips/blob/master/33.md
  """
  @moduledoc tags: [:event, :nip33], nip: 33

  defstruct [:event, :user, :d]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          user: <<_::32, _::_*8>>,
          d: String.t()
        }

  @spec parse(event :: Nostr.Event.t()) :: __MODULE__.t()
  def parse(%Nostr.Event{kind: kind} = event) when kind >= 30_000 and kind < 40_000 do
    %__MODULE__{
      event: event,
      user: event.pubkey,
      d: get_d(event)
    }
  end

  defp get_d(%Nostr.Event{tags: tags}) do
    case Enum.find(tags, &(&1.type == :d)) do
      %Nostr.Tag{data: nil} -> ""
      %Nostr.Tag{data: d} -> d
      nil -> ""
    end
  end
end
