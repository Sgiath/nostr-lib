defmodule Nostr.Event.Metadata do
  @moduledoc """
  Set metadata

  Defined in NIP 01
  https://github.com/nostr-protocol/nips/blob/master/01.md
  """

  defstruct [:event, :user, :name, :about, :picture, :nip05]

  def parse(%Nostr.Event{kind: 0} = event) do
    content = Jason.decode!(event.content)

    %__MODULE__{
      event: event,
      user: event.pubkey,
      name: Map.get(content, "name"),
      about: Map.get(content, "about"),
      picture: Map.get(content, "picture"),
      nip05: Map.get(content, "nip05")
    }
  end
end
