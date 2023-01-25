defmodule Nostr.Event.Reaction do
  @moduledoc """
  Post reaction

  Defined in NIP 25
  https://github.com/nostr-protocol/nips/blob/master/25.md
  """

  defstruct [:event, :user, :reaction, :author, :post]

  def parse(%Nostr.Event{kind: 7} = event) do
    %__MODULE__{
      event: event,
      user: event.pubkey,
      author: parse_author(event.tags),
      post: parse_post(event.tags),
      reaction: event.content
    }
  end

  defp parse_author(tags) do
    Enum.find_value(tags, fn
      %Nostr.Tag{type: :p, data: data} -> data
      _otherwise -> false
    end)
  end

  defp parse_post(tags) do
    Enum.find_value(tags, fn
      %Nostr.Tag{type: :e, data: data} -> data
      _otherwise -> false
    end)
  end
end
