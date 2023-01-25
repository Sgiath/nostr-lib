defmodule Nostr.Event.Metadata do
  @moduledoc """
  Set metadata

  Defined in NIP 01
  https://github.com/nostr-protocol/nips/blob/master/01.md
  """
  @moduledoc tags: [:event, :nip01], nip: 01

  defstruct [:event, :user, :name, :about, :picture, :nip05, :other]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          user: <<_::32, _::_*8>>,
          name: String.t(),
          about: String.t(),
          picture: URI.t(),
          nip05: String.t(),
          other: map()
        }

  @spec parse(Nostr.Event.t()) :: __MODULE__.t()
  def parse(%Nostr.Event{kind: 0} = event) do
    case Jason.decode(event.content, keys: :atoms) do
      {:ok, content} ->
        %__MODULE__{
          event: event,
          user: event.pubkey,
          name: Map.get(content, :name),
          about: Map.get(content, :about),
          picture: Map.get(content, :picture),
          nip05: Map.get(content, :nip05),
          other: Map.drop(content, [:name, :about, :picture, :nip05])
        }

      {:error, %Jason.DecodeError{}} ->
        {:error, "Cannot decode content field", event}
    end
  end
end
