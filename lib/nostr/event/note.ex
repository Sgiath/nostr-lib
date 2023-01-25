defmodule Nostr.Event.Note do
  @moduledoc """
  Text note

  Defined in NIP 01
  https://github.com/nostr-protocol/nips/blob/master/01.md
  """
  @moduledoc tags: [:event, :nip01], nip: 01

  defstruct [:event, :note, :author, :reply_to, :reply_to_authors]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          author: <<_::32, _::_*8>>,
          note: String.t(),
          reply_to: [<<_::32, _::_*8>>],
          reply_to_authors: [<<_::32, _::_*8>>]
        }

  @spec parse(event :: Nostr.Event.t()) :: __MODULE__.t()
  def parse(%Nostr.Event{kind: 1} = event) do
    %__MODULE__{
      event: event,
      author: event.pubkey,
      note: event.content,
      reply_to: get_reply_events(event),
      reply_to_authors: get_reply_pubkeys(event)
    }
  end

  defp get_reply_events(%Nostr.Event{tags: tags}) do
    tags
    |> Enum.filter(fn %Nostr.Tag{type: type} -> type == :e end)
    |> Enum.map(fn %Nostr.Tag{type: :e, data: event_id} -> event_id end)
  end

  defp get_reply_pubkeys(%Nostr.Event{tags: tags}) do
    tags
    |> Enum.filter(fn %Nostr.Tag{type: type} -> type == :p end)
    |> Enum.map(fn %Nostr.Tag{type: :p, data: pubkey} -> pubkey end)
  end
end
