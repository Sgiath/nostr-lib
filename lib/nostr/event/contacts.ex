defmodule Nostr.Event.Contacts do
  @moduledoc """
  Contact list

  Defined in NIP 02
  https://github.com/nostr-protocol/nips/blob/master/02.md
  """
  @moduledoc tags: [:event, :nip02], nip: 02

  defstruct [:event, :user, :contacts]

  @type contact() :: %{
          :user => <<_::32, _::_*8>>,
          optional(:relay) => URI.t(),
          optional(:petname) => String.t()
        }

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          user: <<_::32, _::_*8>>,
          contacts: [contact()]
        }

  @spec parse(event :: Nostr.Event.t()) :: __MODULE__.t()
  def parse(%Nostr.Event{kind: 3} = event) do
    %__MODULE__{
      event: event,
      user: event.pubkey,
      contacts: get_contacts(event)
    }
  end

  defp get_contacts(%Nostr.Event{tags: tags}) do
    tags
    |> Enum.filter(fn %Nostr.Tag{type: type} -> type == :p end)
    |> Enum.map(&parse_contact/1)
  end

  defp parse_contact(%Nostr.Tag{type: :p, data: pubkey, info: [relay, petname]}) do
    %{user: pubkey, relay: URI.parse(relay), petname: petname}
  end

  defp parse_contact(%Nostr.Tag{type: :p, data: pubkey, info: [relay]}) do
    %{user: pubkey, relay: URI.parse(relay)}
  end

  defp parse_contact(%Nostr.Tag{type: :p, data: pubkey, info: []}) do
    %{user: pubkey}
  end
end
