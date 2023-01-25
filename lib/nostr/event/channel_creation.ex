defmodule Nostr.Event.ChannelCreation do
  @moduledoc """
  Channel creation

  Defined in NIP 28
  https://github.com/nostr-protocol/nips/blob/master/28.md
  """

  defstruct [:event, :channel, :name, :about, :picture]

  def parse(%Nostr.Event{kind: 40} = event) do
    content = Jason.decode!(event.content)

    %__MODULE__{
      event: event,
      channel: event.id,
      name: Map.get(content, "name"),
      about: Map.get(content, "about"),
      picture: Map.get(content, "picture")
    }
  end
end
