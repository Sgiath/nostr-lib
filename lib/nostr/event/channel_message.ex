defmodule Nostr.Event.ChannelMessage do
  @moduledoc """
  Channel creation

  Defined in NIP 28
  https://github.com/nostr-protocol/nips/blob/master/28.md
  """
  @moduledoc tags: [:event, :nip28], nip: 28

  defstruct [:event, :channel, :message, :type, :reply_to, :relay]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          channel: <<_::32, _::_*8>>,
          message: String.t(),
          type: :root | :reply,
          reply_to: nil | <<_::32, _::_*8>>,
          relay: URI.t()
        }

  @spec parse(event :: Nostr.Event.t()) :: __MODULE__.t()
  def parse(%Nostr.Event{kind: 42} = event) do
    with {:ok, channel, relay, type} <- get_channel_info(event),
         {:ok, reply_to} <- get_reply_to(event) do
      %__MODULE__{
        event: event,
        channel: channel,
        relay: URI.parse(relay),
        message: event.content,
        type: String.to_atom(type),
        reply_to: reply_to
      }
    end
  end

  defp get_channel_info(%Nostr.Event{tags: tags} = event) do
    case Enum.find(tags, &(&1.type == :e)) do
      %Nostr.Tag{data: channel, info: info} ->
        {:ok, channel, Enum.at(info, 0), Enum.at(info, 1)}

      nil ->
        {:error, "Cannot find channel ID", event}
    end
  end

  defp get_reply_to(%Nostr.Event{tags: tags}) do
    case Enum.find(tags, &(&1.type == :p)) do
      %Nostr.Tag{data: reply_to} -> {:ok, reply_to}
      nil -> {:ok, nil}
    end
  end
end
