defmodule Nostr.Event.ChannelCreation do
  @moduledoc """
  Channel creation

  Defined in NIP 28
  https://github.com/nostr-protocol/nips/blob/master/28.md
  """
  @moduledoc tags: [:event, :nip28], nip: 28

  defstruct [:event, :channel, :name, :about, :picture, :other]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          channel: <<_::32, _::_*8>>,
          name: String.t(),
          about: String.t(),
          picture: URI.t(),
          other: map()
        }

  @spec parse(event :: Nostr.Event.t()) :: __MODULE__.t()
  def parse(%Nostr.Event{kind: 40} = event) do
    case Jason.decode(event.content, keys: :atoms) do
      {:ok, content} ->
        %__MODULE__{
          event: event,
          channel: event.id,
          name: content.name,
          about: content.about,
          picture: URI.parse(content.picture),
          other: Map.drop(content, [:name, :about, :picture])
        }

      {:error, %Jason.DecodeError{}} ->
        {:error, "Cannot decode content field", event}
    end
  end
end
