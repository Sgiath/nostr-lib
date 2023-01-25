defmodule Nostr.Event.Contacts do
  @moduledoc """
  Contact list

  Defined in NIP 02
  https://github.com/nostr-protocol/nips/blob/master/02.md
  """

  defstruct [:event, :user, :contacts]

  def parse(%Nostr.Event{kind: 3} = event) do
    %__MODULE__{
      event: event,
      user: event.pubkey,
      contacts: Enum.map(event.tags, &parse_contact/1)
    }
  end

  defp parse_contact(%Nostr.Tag{type: :p, data: pubkey, info: [relay, petname]}) do
    %{
      user: pubkey,
      relay: relay,
      petname: petname
    }
  end
end
