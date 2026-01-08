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
  - Kind 13: `Nostr.Event.Seal` (NIP-59)
  - Kind 14: `Nostr.Event.PrivateMessage` (NIP-17)
  - Kind 15: `Nostr.Event.FileMessage` (NIP-17)
  - Kind 17: `Nostr.Event.ExternalReaction` (NIP-25)
  - Kinds 40-44: Channel operations (NIP-28)
  - Kind 9734: `Nostr.Event.ZapRequest` (NIP-57)
  - Kind 9735: `Nostr.Event.ZapReceipt` (NIP-57)
  - Kind 1111: `Nostr.Event.Comment` (NIP-22)
  - Kind 1040: `Nostr.Event.OpenTimestamps` (NIP-03)
  - Kind 1059: `Nostr.Event.GiftWrap` (NIP-59)
  - Kind 1063: `Nostr.Event.FileMetadata`
  - Kind 1984: `Nostr.Event.Report`
  - Kind 1985: `Nostr.Event.Label` (NIP-32)
  - Kind 10000: `Nostr.Event.ListMute` (NIP-51)
  - Kind 10001: `Nostr.Event.PinnedNotes` (NIP-51)
  - Kind 10002: `Nostr.Event.RelayList` (NIP-51/NIP-65)
  - Kind 10003: `Nostr.Event.Bookmarks` (NIP-51)
  - Kind 10004: `Nostr.Event.Communities` (NIP-51)
  - Kind 10005: `Nostr.Event.PublicChats` (NIP-51)
  - Kind 10006: `Nostr.Event.BlockedRelays` (NIP-51)
  - Kind 10007: `Nostr.Event.SearchRelays` (NIP-51)
  - Kind 10009: `Nostr.Event.SimpleGroups` (NIP-51)
  - Kind 10012: `Nostr.Event.RelayFeeds` (NIP-51)
  - Kind 10013: `Nostr.Event.PrivateContentRelayList` (NIP-37)
  - Kind 10015: `Nostr.Event.Interests` (NIP-51)
  - Kind 10020: `Nostr.Event.MediaFollows` (NIP-51)
  - Kind 10030: `Nostr.Event.EmojiList` (NIP-51)
  - Kind 10050: `Nostr.Event.DMRelayList` (NIP-17)
  - Kind 10101: `Nostr.Event.GoodWikiAuthors` (NIP-51)
  - Kind 10102: `Nostr.Event.GoodWikiRelays` (NIP-51)
  - Kind 22242: `Nostr.Event.ClientAuth` (NIP-42)
  - Kind 30000: `Nostr.Event.FollowSets` (NIP-51)
  - Kind 30002: `Nostr.Event.RelaySets` (NIP-51)
  - Kind 30003: `Nostr.Event.BookmarkSets` (NIP-51)
  - Kinds 30004-30006: `Nostr.Event.CurationSets` (NIP-51)
  - Kind 30007: `Nostr.Event.KindMuteSets` (NIP-51)
  - Kind 30015: `Nostr.Event.InterestSets` (NIP-51)
  - Kind 30023: `Nostr.Event.Article` (NIP-23)
  - Kind 30024: `Nostr.Event.Article` (NIP-23 draft)
  - Kind 30030: `Nostr.Event.EmojiSets` (NIP-51)
  - Kind 30063: `Nostr.Event.ReleaseArtifactSets` (NIP-51)
  - Kind 30267: `Nostr.Event.AppCurationSets` (NIP-51)
  - Kind 31234: `Nostr.Event.DraftWrap` (NIP-37)
  - Kind 31924: `Nostr.Event.Calendar` (NIP-51)
  - Kind 39089: `Nostr.Event.StarterPacks` (NIP-51)
  - Kind 39092: `Nostr.Event.MediaStarterPacks` (NIP-51)

  Event kind ranges (NIP-16):
  - 1000-9999: `Nostr.Event.Regular`
  - 10000-19999: `Nostr.Event.Replaceable`
  - 20000-29999: `Nostr.Event.Ephemeral`
  - 30000-39999: `Nostr.Event.ParameterizedReplaceable`

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

  # Basic event kinds (0-17)
  def parse_specific(%Event{kind: 0} = event), do: Event.Metadata.parse(event)
  def parse_specific(%Event{kind: 1} = event), do: Event.Note.parse(event)
  def parse_specific(%Event{kind: 2} = event), do: Event.RecommendRelay.parse(event)
  def parse_specific(%Event{kind: 3} = event), do: Event.Contacts.parse(event)
  def parse_specific(%Event{kind: 4} = event), do: Event.DirectMessage.parse(event)
  def parse_specific(%Event{kind: 5} = event), do: Event.Deletion.parse(event)
  def parse_specific(%Event{kind: 6} = event), do: Event.Repost.parse(event)
  def parse_specific(%Event{kind: 7} = event), do: Event.Reaction.parse(event)
  def parse_specific(%Event{kind: 8} = event), do: Event.BadgeAward.parse(event)
  def parse_specific(%Event{kind: 13} = event), do: Event.Seal.parse(event)
  def parse_specific(%Event{kind: 14} = event), do: Event.PrivateMessage.parse(event)
  def parse_specific(%Event{kind: 15} = event), do: Event.FileMessage.parse(event)
  def parse_specific(%Event{kind: 17} = event), do: Event.ExternalReaction.parse(event)

  # Channel operations (40-44, NIP-28)
  def parse_specific(%Event{kind: 40} = event), do: Event.ChannelCreation.parse(event)
  def parse_specific(%Event{kind: 41} = event), do: Event.ChannelMetadata.parse(event)
  def parse_specific(%Event{kind: 42} = event), do: Event.ChannelMessage.parse(event)
  def parse_specific(%Event{kind: 43} = event), do: Event.ChannelHideMessage.parse(event)
  def parse_specific(%Event{kind: 44} = event), do: Event.ChannelMuteUser.parse(event)

  # NIP-57 Zaps (9734-9735)
  def parse_specific(%Event{kind: 9734} = event), do: Event.ZapRequest.parse(event)
  def parse_specific(%Event{kind: 9735} = event), do: Event.ZapReceipt.parse(event)

  # Regular events (1000-9999)
  def parse_specific(%Event{kind: 1111} = event), do: Event.Comment.parse(event)
  def parse_specific(%Event{kind: 1040} = event), do: Event.OpenTimestamps.parse(event)
  def parse_specific(%Event{kind: 1059} = event), do: Event.GiftWrap.parse(event)
  def parse_specific(%Event{kind: 1063} = event), do: Event.FileMetadata.parse(event)
  def parse_specific(%Event{kind: 1984} = event), do: Event.Report.parse(event)
  def parse_specific(%Event{kind: 1985} = event), do: Event.Label.parse(event)

  # NIP-51 Standard Lists (10000-10102)
  def parse_specific(%Event{kind: 10_000} = event), do: Event.ListMute.parse(event)
  def parse_specific(%Event{kind: 10_001} = event), do: Event.PinnedNotes.parse(event)
  def parse_specific(%Event{kind: 10_002} = event), do: Event.RelayList.parse(event)
  def parse_specific(%Event{kind: 10_003} = event), do: Event.Bookmarks.parse(event)
  def parse_specific(%Event{kind: 10_004} = event), do: Event.Communities.parse(event)
  def parse_specific(%Event{kind: 10_005} = event), do: Event.PublicChats.parse(event)
  def parse_specific(%Event{kind: 10_006} = event), do: Event.BlockedRelays.parse(event)
  def parse_specific(%Event{kind: 10_007} = event), do: Event.SearchRelays.parse(event)
  def parse_specific(%Event{kind: 10_009} = event), do: Event.SimpleGroups.parse(event)
  def parse_specific(%Event{kind: 10_012} = event), do: Event.RelayFeeds.parse(event)
  def parse_specific(%Event{kind: 10_015} = event), do: Event.Interests.parse(event)
  def parse_specific(%Event{kind: 10_020} = event), do: Event.MediaFollows.parse(event)
  def parse_specific(%Event{kind: 10_030} = event), do: Event.EmojiList.parse(event)
  def parse_specific(%Event{kind: 10_013} = event), do: Event.PrivateContentRelayList.parse(event)
  def parse_specific(%Event{kind: 10_050} = event), do: Event.DMRelayList.parse(event)
  def parse_specific(%Event{kind: 10_101} = event), do: Event.GoodWikiAuthors.parse(event)
  def parse_specific(%Event{kind: 10_102} = event), do: Event.GoodWikiRelays.parse(event)

  # Other replaceable events
  def parse_specific(%Event{kind: 22_242} = event), do: Event.ClientAuth.parse(event)

  # NIP-51 Parameterized Sets (30000-39999)
  def parse_specific(%Event{kind: 30_000} = event), do: Event.FollowSets.parse(event)
  def parse_specific(%Event{kind: 30_002} = event), do: Event.RelaySets.parse(event)
  def parse_specific(%Event{kind: 30_003} = event), do: Event.BookmarkSets.parse(event)
  def parse_specific(%Event{kind: 30_004} = event), do: Event.CurationSets.parse(event)
  def parse_specific(%Event{kind: 30_005} = event), do: Event.CurationSets.parse(event)
  def parse_specific(%Event{kind: 30_006} = event), do: Event.CurationSets.parse(event)
  def parse_specific(%Event{kind: 30_007} = event), do: Event.KindMuteSets.parse(event)
  def parse_specific(%Event{kind: 30_015} = event), do: Event.InterestSets.parse(event)
  def parse_specific(%Event{kind: 30_023} = event), do: Event.Article.parse(event)
  def parse_specific(%Event{kind: 30_024} = event), do: Event.Article.parse(event)
  def parse_specific(%Event{kind: 30_030} = event), do: Event.EmojiSets.parse(event)
  def parse_specific(%Event{kind: 30_063} = event), do: Event.ReleaseArtifactSets.parse(event)
  def parse_specific(%Event{kind: 30_267} = event), do: Event.AppCurationSets.parse(event)
  def parse_specific(%Event{kind: 30_315} = event), do: Event.UserStatus.parse(event)
  def parse_specific(%Event{kind: 31_234} = event), do: Event.DraftWrap.parse(event)
  def parse_specific(%Event{kind: 31_924} = event), do: Event.Calendar.parse(event)
  def parse_specific(%Event{kind: 39_089} = event), do: Event.StarterPacks.parse(event)
  def parse_specific(%Event{kind: 39_092} = event), do: Event.MediaStarterPacks.parse(event)

  # Fallback ranges (NIP-16)
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
