defmodule Nostr.Event.ChannelHideMessage do
  @moduledoc """
  Channel hide message

  Defined in NIP 28
  https://github.com/nostr-protocol/nips/blob/master/28.md
  """
  @moduledoc tags: [:event, :nip28], nip: 28

  defstruct [:event, :reason, :message_id, :other]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          message_id: <<_::32, _::_*8>>,
          reason: String.t(),
          other: map()
        }

  @spec parse(event :: Nostr.Event.t()) :: __MODULE__.t()
  def parse(%Nostr.Event{kind: 43} = event) do
    with {:ok, message_id} <- get_message_id(event),
         {:ok, content} <- JSON.decode(event.content) do
      %__MODULE__{
        event: event,
        message_id: message_id,
        reason: content["reason"],
        other: Map.drop(content, ["reason"])
      }
    else
      {:error, %JSON.DecodeError{}} -> {:error, "Cannot decode content field", event}
      {:error, error} -> {:error, error, event}
    end
  end

  defp get_message_id(%Nostr.Event{tags: tags}) do
    case Enum.find(tags, &(&1.type == :e)) do
      %Nostr.Tag{data: message_id} -> {:ok, message_id}
      nil -> {:error, "Cannot find message ID to hide"}
    end
  end
end
