defmodule Nostr.Event.ChannelMetadata do
  @moduledoc """
  Channel creation

  Defined in NIP 28
  https://github.com/nostr-protocol/nips/blob/master/28.md
  """
  @moduledoc tags: [:event, :nip28], nip: 28

  defstruct [:event, :channel, :name, :about, :picture, :relay, :other]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          channel: <<_::32, _::_*8>>,
          name: String.t(),
          about: String.t(),
          picture: URI.t(),
          relay: URI.t(),
          other: map()
        }

  @spec parse(event :: Nostr.Event.t()) :: __MODULE__.t()
  def parse(%Nostr.Event{kind: 41} = event) do
    with {:ok, channel, relay} <- get_channel_info(event),
         {:ok, content} <- Jason.decode(event.content, keys: :atoms) do
      %__MODULE__{
        event: event,
        channel: channel,
        relay: URI.parse(relay),
        name: Map.get(content, :name),
        about: Map.get(content, :about),
        picture: Map.get(content, :picture),
        other: Map.drop(content, [:name, :about, :picture])
      }
    else
      {:error, %Jason.DecodeError{}} -> {:error, "Cannot decode content field", event}
      {:error, error} -> {:error, error, event}
    end
  end

  defp get_channel_info(%Nostr.Event{tags: tags}) do
    case Enum.find(tags, &(&1.type == :e)) do
      %Nostr.Tag{data: channel, info: info} ->
        {:ok, channel, Enum.at(info, 0)}

      nil ->
        {:error, "Cannot find channel ID"}
    end
  end
end
