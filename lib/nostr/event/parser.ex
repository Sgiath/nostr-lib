defmodule Nostr.Event.Parser do
  @moduledoc false

  alias Nostr.Event

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

  def parse_specific(%Event{kind: 0} = event) do
    Event.Metadata.parse(event)
  end

  def parse_specific(%Event{kind: 1} = event) do
    Event.Note.parse(event)
  end

  def parse_specific(%Event{kind: 2} = event) do
    Event.RecommendRelay.parse(event)
  end

  def parse_specific(%Event{kind: 3} = event) do
    Event.Contacts.parse(event)
  end

  def parse_specific(%Event{kind: 4} = event) do
    Event.DirectMessage.parse(event)
  end

  def parse_specific(%Event{kind: 5} = event) do
    Event.Deletion.parse(event)
  end

  def parse_specific(%Event{kind: 6} = event) do
    Event.Repost.parse(event)
  end

  def parse_specific(%Event{kind: 7} = event) do
    Event.Reaction.parse(event)
  end

  def parse_specific(%Event{kind: 8} = event) do
    Event.BadgeAward.parse(event)
  end

  def parse_specific(%Event{kind: 40} = event) do
    Event.ChannelCreation.parse(event)
  end

  def parse_specific(%Event{kind: 41} = event) do
    Event.ChannelMetadata.parse(event)
  end

  def parse_specific(%Event{kind: 42} = event) do
    Event.ChannelMessage.parse(event)
  end

  def parse_specific(%Event{kind: 43} = event) do
    Event.ChannelHideMessage.parse(event)
  end

  def parse_specific(%Event{kind: 44} = event) do
    Event.ChannelMuteUser.parse(event)
  end

  def parse_specific(%Event{kind: 1063} = event) do
    Event.FileMetadata.parse(event)
  end

  def parse_specific(%Event{kind: 1984} = event) do
    Event.Report.parse(event)
  end

  def parse_specific(%Event{kind: 22_242} = event) do
    Event.ClientAuth.parse(event)
  end

  def parse_specific(%Event{kind: kind} = event) when kind >= 1000 and kind < 10_000 do
    Event.Regular.parse(event)
  end

  def parse_specific(%Event{kind: kind} = event) when kind >= 10_000 and kind < 20_000 do
    Event.Replaceable.parse(event)
  end

  def parse_specific(%Event{kind: kind} = event) when kind >= 20_000 and kind < 30_000 do
    Event.Ephemeral.parse(event)
  end

  def parse_specific(%Event{kind: kind} = event) when kind >= 30_000 and kind < 40_000 do
    Event.ParameterizedReplaceable.parse(event)
  end

  def parse_specific(%Nostr.Event{} = event) do
    %Event.Unknown{event: event}
  end
end
