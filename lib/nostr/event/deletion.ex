defmodule Nostr.Event.Deletion do
  @moduledoc """
  Event deletion

  Defined in NIP 09
  https://github.com/nostr-protocol/nips/blob/master/09.md
  """
  @moduledoc tags: [:event, :nip09], nip: 09

  defstruct [:event, :user, :to_delete]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          user: <<_::32, _::_*8>>,
          to_delete: [<<_::32, _::_*8>>]
        }

  @spec parse(event :: Nostr.Event.t()) :: __MODULE__.t()
  def parse(%Nostr.Event{kind: 5} = event) do
    %__MODULE__{
      event: event,
      user: event.pubkey,
      to_delete: get_to_delete(event)
    }
  end

  defp get_to_delete(%Nostr.Event{tags: tags}) do
    tags
    |> Enum.filter(fn %Nostr.Tag{type: type} -> type == :e end)
    |> Enum.map(&parse_tag/1)
  end

  defp parse_tag(%Nostr.Tag{type: :e, data: id}), do: id
end
