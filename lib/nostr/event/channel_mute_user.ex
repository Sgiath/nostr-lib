defmodule Nostr.Event.ChannelMuteUser do
  @moduledoc """
  Channel mute user

  Defined in NIP 28
  https://github.com/nostr-protocol/nips/blob/master/28.md
  """
  @moduledoc tags: [:event, :nip28], nip: 28

  defstruct [:event, :user, :reason, :other]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          user: <<_::32, _::_*8>>,
          reason: String.t(),
          other: map()
        }

  @spec parse(event :: Nostr.Event.t()) :: __MODULE__.t()
  def parse(%Nostr.Event{kind: 44} = event) do
    with {:ok, pubkey} <- get_user(event),
         {:ok, content} <- Jason.decode(event.content, keys: :atoms) do
      %__MODULE__{
        event: event,
        user: pubkey,
        reason: content.reason,
        other: Map.drop(content, [:reason])
      }
    else
      {:error, %Jason.DecodeError{}} -> {:error, "Cannot decode content field", event}
      {:error, error} -> {:error, error, event}
    end
  end

  defp get_user(%Nostr.Event{tags: tags}) do
    case Enum.find(tags, &(&1.type == :p)) do
      %Nostr.Tag{data: pubkey} -> {:ok, pubkey}
      nil -> {:error, "Cannot find user to mute"}
    end
  end
end
