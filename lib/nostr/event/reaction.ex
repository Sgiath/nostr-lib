defmodule Nostr.Event.Reaction do
  @moduledoc """
  Post reaction

  Defined in NIP 25
  https://github.com/nostr-protocol/nips/blob/master/25.md
  """
  @moduledoc tags: [:event, :nip25], nip: 25

  defstruct [:event, :user, :reaction, :author, :post]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          user: <<_::32, _::_*8>>,
          author: <<_::32, _::_*8>>,
          post: <<_::32, _::_*8>>,
          reaction: String.t()
        }

  @doc "Parses a kind 7 event into a `Reaction` struct, extracting the reacted post and author."
  @spec parse(event :: Nostr.Event.t()) :: __MODULE__.t()
  def parse(%Nostr.Event{kind: 7} = event) do
    with {:ok, author} <- get_author(event),
         {:ok, post} <- get_post(event) do
      %__MODULE__{
        event: event,
        user: event.pubkey,
        author: author,
        post: post,
        reaction: event.content
      }
    end
  end

  defp get_author(%Nostr.Event{tags: tags} = event) do
    case Enum.find(tags, &(&1.type == :p)) do
      %Nostr.Tag{data: pubkey} -> {:ok, pubkey}
      nil -> {:error, "Cannot find post author tag", event}
    end
  end

  defp get_post(%Nostr.Event{tags: tags} = event) do
    case Enum.find(tags, &(&1.type == :e)) do
      %Nostr.Tag{data: pubkey} -> {:ok, pubkey}
      nil -> {:error, "Cannot find post tag", event}
    end
  end
end
