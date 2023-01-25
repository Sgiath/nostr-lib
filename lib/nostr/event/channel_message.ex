defmodule Nostr.Event.ChannelMessage do
  @moduledoc """
  Channel creation

  Defined in NIP 28
  https://github.com/nostr-protocol/nips/blob/master/28.md
  """

  defstruct [:event, :channel, :message, :type, :reply_to, :relay]

  def parse(%Nostr.Event{kind: 42} = event) do
    %Nostr.Tag{data: channel, info: [relay, type]} = Enum.find(event.tags, &(&1.type == :e))
    %Nostr.Tag{data: reply_to} = Enum.find(event.tags, &(&1.type == :p))

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
