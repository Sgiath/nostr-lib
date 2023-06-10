defmodule Nostr.Event.BadgeAward do
  @moduledoc """
  Badge award

  Defined in NIP 58
  https://github.com/nostr-protocol/nips/blob/master/58.md
  """
  @moduledoc tags: [:event, :nip58], nip: 58

  defstruct [:event, :badge, :awardees]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          badge: <<_::32, _::_*8>>,
          awardees: [<<_::32, _::_*8>>]
        }

  @spec parse(event :: Nostr.Event.t()) :: __MODULE__.t()
  def parse(%Nostr.Event{kind: 1} = event) do
    %__MODULE__{
      event: event,
      badge: get_badge(event),
      awardees: get_awardees(event)
    }
  end

  defp get_badge(%Nostr.Event{tags: tags}) do
    Enum.find_value(tags, fn
      %Nostr.Tag{type: :a, data: id} -> id
      _otherwise -> false
    end)
  end

  defp get_awardees(%Nostr.Event{tags: tags}) do
    tags
    |> Enum.filter(fn %Nostr.Tag{type: type} -> type == :p end)
    |> Enum.map(& &1.data)
  end
end
