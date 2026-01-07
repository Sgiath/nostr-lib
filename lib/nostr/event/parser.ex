defmodule Nostr.Event.Parser do
  @moduledoc """
  Internal module for parsing raw event data into `Nostr.Event` structs.

  This module handles two types of parsing:
  - `parse/1` - Converts raw JSON maps to generic `Nostr.Event` structs
  - `parse_specific/1` - Converts `Nostr.Event` to type-specific structs based on event kind

  ## Event Kind Routing

  Specific event kinds are routed to their dedicated modules:
  - Kind 0: `Nostr.Event.Metadata` (NIP-01)
  - Kind 1: `Nostr.Event.Note` (NIP-01)
  - Kind 2: `Nostr.Event.RecommendRelay` (NIP-01)
  - Kind 3: `Nostr.Event.Contacts` (NIP-02)
  - Kind 4: `Nostr.Event.DirectMessage` (NIP-04)
  - Kind 5: `Nostr.Event.Deletion` (NIP-09)
  - Kind 6: `Nostr.Event.Repost` (NIP-18)
  - Kind 7: `Nostr.Event.Reaction` (NIP-25)
  - Kind 8: `Nostr.Event.BadgeAward` (NIP-58)
  - Kinds 40-44: Channel operations (NIP-28)
  - Kind 1063: `Nostr.Event.FileMetadata`
  - Kind 1984: `Nostr.Event.Report`
  - Kind 22242: `Nostr.Event.ClientAuth` (NIP-42)

  Event kind ranges (NIP-16):
  - 1000-9999: `Nostr.Event.Regular`
  - 10000-19999: `Nostr.Event.Replaceable`
  - 20000-29999: `Nostr.Event.Ephemeral`
  - 30000-39999: `Nostr.Event.ParameterizedReplaceable` (NIP-33)

  Unknown kinds fall back to `Nostr.Event.Unknown`.
  """

  alias Nostr.Event

  @doc """
  Parses a JSON string or map into a `Nostr.Event` struct.

  Converts Unix timestamps to `DateTime` and parses tags into `Nostr.Tag` structs.
  """
  @spec parse(String.t() | map()) :: Nostr.Event.t() | {:error, String.t(), term()}
  def parse(event) when is_binary(event) do
    case JSON.decode!(event) do
      {:ok, event} -> parse(event)
      {:error, %JSON.DecodeError{}} -> {:error, "Cannot decode event", event}
    end
  end

  def parse(event) when is_map(event) do
    %Nostr.Event{
      id: event["id"],
      pubkey: event["pubkey"],
      kind: event["kind"],
      tags: Enum.map(event["tags"], &Nostr.Tag.parse/1),
      created_at: DateTime.from_unix!(event["created_at"]),
      content: event["content"],
      sig: event["sig"]
    }
  end

  @doc """
  Converts a generic `Nostr.Event` to a type-specific struct based on event kind.

  Returns a specialized struct (e.g., `Nostr.Event.Note`, `Nostr.Event.Metadata`)
  that may contain parsed content and additional type-specific fields.
  """
  @spec parse_specific(Nostr.Event.t()) :: struct()
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
