defmodule Nostr.Event.Repost do
  @moduledoc """
  Repost

  DEPRECATED in favor of NIP-27

  Defined in NIP 18
  https://github.com/nostr-protocol/nips/blob/master/18.md
  """
  @moduledoc tags: [:event, :nip18], nip: 18, deprecated: "NIP-27"

  require Logger

  defstruct [:event, :post, :author, :relay, :content]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          post: <<_::32, _::_*8>>,
          author: nil | <<_::32, _::_*8>>,
          relay: URI.t(),
          content: nil | Nostr.Event.t()
        }

  @doc "Parses a kind 6 event into a `Repost` struct. Logs a deprecation warning."
  @spec parse(event :: Nostr.Event.t()) :: __MODULE__.t()
  def parse(%Nostr.Event{kind: 6} = event) do
    Logger.warning("Repost event is deprecated. Use NIP-27 instead")

    tag = get_post_tag(event)

    %__MODULE__{
      event: event,
      post: tag.data,
      relay: URI.parse(List.first(tag.info)),
      author: get_author_tag(event).data,
      content: get_content(event)
    }
  end

  defp get_post_tag(%Nostr.Event{tags: tags}) do
    Enum.find_value(tags, fn
      %Nostr.Tag{type: :e} = tag -> tag
      _otherwise -> false
    end)
  end

  defp get_author_tag(%Nostr.Event{tags: tags}) do
    Enum.find_value(tags, fn
      %Nostr.Tag{type: :p} = tag -> tag
      _otherwise -> false
    end)
  end

  defp get_content(%Nostr.Event{content: nil}), do: nil

  defp get_content(%Nostr.Event{content: content}) do
    content
    |> JSON.decode!()
    |> Nostr.Event.parse()
  end
end
