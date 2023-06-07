defmodule Nostr.Event.ClientAuth do
  @moduledoc """
  Client authentication

  Defined in NIP 42
  https://github.com/nostr-protocol/nips/blob/master/42.md
  """
  @moduledoc tags: [:event, :nip42], nip: 42

  defstruct [:event, :relay, :challenge]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          challenge: String.t(),
          relay: URI.t()
        }

  @spec parse(event :: Nostr.Event.t()) :: __MODULE__.t()
  def parse(%Nostr.Event{kind: 22_242} = event) do
    %__MODULE__{
      event: event,
      relay: get_tag(event, :relay),
      challenge: get_tag(event, :challenge)
    }
  end

  defp get_tag(%Nostr.Event{tags: tags}, tag) do
    tags
    |> Enum.find(&(&1.type == tag))
    |> Map.get(:data)
  end
end
