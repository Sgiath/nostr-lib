defmodule Nostr.Event.Parser do
  @moduledoc false

  def parse(event) when is_binary(event) do
    case Jason.decode!(event, keys: :atoms) do
      {:ok, event} -> parse(event)
      {:error, %Jason.DecodeError{}} -> {:error, "Cannot decode event", event}
    end
  end

  def parse(event) when is_map(event) do
    %Nostr.Event{
      id: event.id,
      pubkey: event.pubkey,
      kind: event.kind,
      tags: Enum.map(event.tags, &Nostr.Tag.parse/1),
      created_at: DateTime.from_unix!(event.created_at),
      content: event.content,
      sig: event.sig
    }
  end

  def parse_specific(%Nostr.Event{kind: 0} = event) do
    Nostr.Event.Metadata.parse(event)
  end

  def parse_specific(%Nostr.Event{kind: 1} = event) do
    Nostr.Event.Note.parse(event)
  end

  def parse_specific(%Nostr.Event{kind: 2} = event) do
    Nostr.Event.RecommendRelay.parse(event)
  end

  def parse_specific(%Nostr.Event{kind: 3} = event) do
    Nostr.Event.Contacts.parse(event)
  end

  def parse_specific(%Nostr.Event{kind: 4} = event) do
    Nostr.Event.DirectMessage.parse(event)
  end

  def parse_specific(%Nostr.Event{kind: 5} = event) do
    Nostr.Event.Deletion.parse(event)
  end

  def parse_specific(%Nostr.Event{kind: 7} = event) do
    Nostr.Event.Reaction.parse(event)
  end

  def parse_specific(%Nostr.Event{kind: 40} = event) do
    Nostr.Event.ChannelCreation.parse(event)
  end

  def parse_specific(%Nostr.Event{kind: 41} = event) do
    Nostr.Event.ChannelMetadata.parse(event)
  end

  def parse_specific(%Nostr.Event{kind: 42} = event) do
    Nostr.Event.ChannelMessage.parse(event)
  end

  def parse_specific(%Nostr.Event{kind: 43} = event) do
    Nostr.Event.ChannelHideMessage.parse(event)
  end

  def parse_specific(%Nostr.Event{kind: 44} = event) do
    Nostr.Event.ChannelMuteUser.parse(event)
  end

  def parse_specific(%Nostr.Event{kind: 22242} = event) do
    Nostr.Event.ClientAuth.parse(event)
  end

  def parse_specific(%Nostr.Event{kind: kind} = event) when kind >= 1000 and kind < 10_000 do
    Nostr.Event.Regular.parse(event)
  end

  def parse_specific(%Nostr.Event{kind: kind} = event) when kind >= 10_000 and kind < 20_000 do
    Nostr.Event.Replaceable.parse(event)
  end

  def parse_specific(%Nostr.Event{kind: kind} = event) when kind >= 20_000 and kind < 30_000 do
    Nostr.Event.Ephemeral.parse(event)
  end

  def parse_specific(%Nostr.Event{kind: kind} = event) when kind >= 30_000 and kind < 40_000 do
    Nostr.Event.ParameterizedReplaceable.parse(event)
  end

  def parse_specific(%Nostr.Event{} = event) do
    %Nostr.Event.Unknown{event: event}
  end
end
