defmodule Nostr.Event.Contacts do
  @moduledoc """
  Contact list

  Defined in NIP 02
  https://github.com/nostr-protocol/nips/blob/master/02.md
  """
  @moduledoc tags: [:event, :nip02], nip: 02

  defstruct [:event, :user, :contacts]

  @typedoc "Contact structure returned from parsing"
  @type contact() :: %{
          :user => <<_::32, _::_*8>>,
          optional(:relay) => URI.t(),
          optional(:petname) => String.t()
        }

  @typedoc "Contact input for creating a contact list"
  @type contact_input() :: %{
          :user => binary(),
          optional(:relay) => String.t(),
          optional(:petname) => String.t()
        }

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          user: <<_::32, _::_*8>>,
          contacts: [contact()]
        }

  @doc """
  Create new Contact List (follow list) Nostr event

  ## Arguments:

    - `contacts` list of contacts to follow
    - `opts` other optional event arguments (`pubkey`, `created_at`, `tags`)

  ## Examples

      iex> contacts = [
      ...>   %{user: "pubkey1", relay: "wss://relay.com", petname: "alice"},
      ...>   %{user: "pubkey2", relay: "wss://relay.com"},
      ...>   %{user: "pubkey3"}
      ...> ]
      iex> Nostr.Event.Contacts.create(contacts)

  """
  @spec create(contacts :: [contact_input()], opts :: Keyword.t()) :: t()
  def create(contacts, opts \\ []) do
    tags = Enum.map(contacts, &contact_to_tag/1)
    opts = Keyword.merge(opts, tags: tags, content: "")

    3
    |> Nostr.Event.create(opts)
    |> parse()
  end

  @doc "Parses a kind 3 event into a `Contacts` struct, extracting the contact list."
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

  defp contact_to_tag(%{user: user, relay: relay, petname: petname}) do
    Nostr.Tag.create(:p, user, [relay, petname])
  end

  defp contact_to_tag(%{user: user, relay: relay}) do
    Nostr.Tag.create(:p, user, [relay])
  end

  defp contact_to_tag(%{user: user}) do
    Nostr.Tag.create(:p, user)
  end
end
