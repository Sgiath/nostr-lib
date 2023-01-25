defmodule Nostr.Event.ChannelMetadata do
  @moduledoc """
  Channel creation

  Defined in NIP 28
  https://github.com/nostr-protocol/nips/blob/master/28.md
  """

  defstruct [:event, :channel, :name, :about, :picture, :relay]

  def parse(%Nostr.Event{kind: 41} = event) do
    content = Jason.decode!(event.content)
    %Nostr.Tag{data: channel, info: [relay]} = Enum.find(event.tags, &(&1.type == :e))

    %__MODULE__{
      event: event,
      channel: channel,
      relay: URI.parse(relay),
      name: Map.get(content, "name"),
      about: Map.get(content, "about"),
      picture: Map.get(content, "picture")
    }
  end
end
