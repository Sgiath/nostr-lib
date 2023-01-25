defmodule Nostr.Event.Deletion do
  @moduledoc """
  Event deletion

  Defined in NIP 09
  https://github.com/nostr-protocol/nips/blob/master/09.md
  """

  defstruct [:event, :user, :to_delete]

  def parse(%Nostr.Event{kind: 5} = event) do
    %__MODULE__{
      event: event,
      user: event.pubkey,
      to_delete: Enum.map(event.tags, &parse_tag/1)
    }
  end

  defp parse_tag(%Nostr.Tag{type: :e, data: id}), do: id
end
