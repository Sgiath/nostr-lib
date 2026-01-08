defmodule Nostr.Event.Metadata do
  @moduledoc """
  User metadata (Kind 0)

  Implements NIP-01 (basic metadata), NIP-24 (extra metadata fields), NIP-30 (custom emoji),
  and NIP-39 (external identities).

  ## NIP-01 Fields
  - `name` - username
  - `about` - bio/description
  - `picture` - avatar URL
  - `nip05` - NIP-05 identifier

  ## NIP-24 Extra Fields
  - `display_name` - alternative, richer display name
  - `website` - web URL related to the user
  - `banner` - wide background picture URL (~1024x768)
  - `bot` - boolean indicating automated content
  - `birthday` - birth date with optional year/month/day

  ## NIP-30 Custom Emoji
  - `emojis` - map of shortcode => URL for custom emoji in `name` and `about`

  ## NIP-39 External Identities
  - `identities` - list of external identity verifications (github, twitter, mastodon, telegram)

  ## Examples

      # Create basic metadata
      Metadata.create("alice", "About me", "https://pic.com/a.jpg", "alice@example.com")

      # Create with NIP-24 fields
      Metadata.create("alice", "About me", "https://pic.com/a.jpg", "alice@example.com",
        display_name: "Alice Wonderland",
        website: "https://alice.example.com",
        banner: "https://pic.com/banner.jpg",
        bot: false,
        birthday: %{year: 1990, month: 1, day: 15}
      )

      # Create with custom emoji (NIP-30)
      Metadata.create("Alice :verified:", "About me", nil, nil,
        emojis: %{"verified" => "https://example.com/verified.png"}
      )

      # Create with external identities (NIP-39)
      Metadata.create("alice", "About me", nil, nil,
        identities: [
          %{platform: "github", identity: "alice", proof: "gist_id"},
          %{platform: "twitter", identity: "alice_btc", proof: "tweet_id"}
        ]
      )

  See:
  - https://github.com/nostr-protocol/nips/blob/master/01.md
  - https://github.com/nostr-protocol/nips/blob/master/24.md
  - https://github.com/nostr-protocol/nips/blob/master/30.md
  - https://github.com/nostr-protocol/nips/blob/master/39.md
  """
  @moduledoc tags: [:event, :nip01, :nip24, :nip30, :nip39], nip: [1, 24, 30, 39]

  defstruct [
    :event,
    :user,
    :name,
    :about,
    :picture,
    :nip05,
    # NIP-24 extra fields
    :display_name,
    :website,
    :banner,
    :bot,
    :birthday,
    # Remaining fields
    :other,
    # NIP-30 custom emoji
    :emojis,
    # NIP-39 external identities
    :identities
  ]

  @typedoc "Birthday with optional year/month/day"
  @type birthday() ::
          %{
            year: non_neg_integer() | nil,
            month: 1..12 | nil,
            day: 1..31 | nil
          }
          | nil

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          user: binary(),
          name: String.t() | nil,
          about: String.t() | nil,
          picture: URI.t() | nil,
          nip05: String.t() | nil,
          display_name: String.t() | nil,
          website: URI.t() | nil,
          banner: URI.t() | nil,
          bot: boolean() | nil,
          birthday: birthday(),
          other: map(),
          emojis: %{binary() => binary()},
          identities: [Nostr.NIP39.identity()]
        }

  # Fields to exclude from `other` map
  @known_fields ~w(name username about picture nip05 display_name displayName website banner bot birthday)

  @doc """
  Parse generic `Nostr.Event` to `Nostr.Event.Metadata` struct.

  Handles deprecated field normalization:
  - `displayName` → `display_name`
  - `username` → `name`
  """
  @spec parse(event :: Nostr.Event.t()) :: t() | {:error, String.t(), Nostr.Event.t()}
  def parse(%Nostr.Event{kind: 0} = event) do
    case JSON.decode(event.content) do
      {:ok, content} ->
        # Handle deprecated field normalization (NIP-24)
        name = content["name"] || content["username"]
        display_name = content["display_name"] || content["displayName"]

        %__MODULE__{
          event: event,
          user: event.pubkey,
          name: name,
          about: content["about"],
          picture: parse_url(content["picture"]),
          nip05: content["nip05"],
          # NIP-24 fields
          display_name: display_name,
          website: parse_url(content["website"]),
          banner: parse_url(content["banner"]),
          bot: content["bot"],
          birthday: parse_birthday(content["birthday"]),
          # Everything else
          other: Map.drop(content, @known_fields),
          # NIP-30 custom emoji from tags
          emojis: Nostr.NIP30.from_tags(event.tags),
          # NIP-39 external identities from tags
          identities: Nostr.NIP39.from_tags(event.tags)
        }

      {:error, _} ->
        {:error, "Cannot decode content field", event}
    end
  end

  defp parse_url(nil), do: nil
  defp parse_url(url) when is_binary(url), do: URI.parse(url)
  defp parse_url(_), do: nil

  defp parse_birthday(nil), do: nil

  defp parse_birthday(%{} = bd) do
    %{
      year: bd["year"],
      month: bd["month"],
      day: bd["day"]
    }
  end

  defp parse_birthday(_), do: nil

  @doc """
  Create new `Nostr.Event.Metadata` struct.

  ## Arguments

    - `name` - username
    - `about` - bio/description
    - `picture` - avatar URL (URI struct or String)
    - `nip05` - NIP-05 identifier
    - `opts` - keyword list of options

  ## Options

    Event options:
    - `:pubkey` - author pubkey
    - `:created_at` - timestamp
    - `:tags` - additional tags

    NIP-24 fields:
    - `:display_name` - alternative, richer display name
    - `:website` - web URL (String or URI)
    - `:banner` - background picture URL (String or URI)
    - `:bot` - boolean indicating automated content
    - `:birthday` - map with optional `:year`, `:month`, `:day` keys

    NIP-30 fields:
    - `:emojis` - map of shortcode => URL for custom emoji in `name` and `about`

    NIP-39 fields:
    - `:identities` - list of identity maps with `:platform`, `:identity`, `:proof` keys

  ## Examples

      Metadata.create("alice", "About me", "https://pic.com/a.jpg", "alice@example.com")

      Metadata.create("alice", "About me", "https://pic.com/a.jpg", "alice@example.com",
        display_name: "Alice Wonderland",
        website: "https://alice.example.com",
        banner: "https://pic.com/banner.jpg",
        bot: false,
        birthday: %{year: 1990, month: 1, day: 15}
      )

  """
  @spec create(
          name :: String.t() | nil,
          about :: String.t() | nil,
          picture :: URI.t() | String.t() | nil,
          nip05 :: String.t() | nil,
          opts :: Keyword.t()
        ) :: t()
  def create(name, about, picture, nip05, opts \\ [])

  def create(name, about, %URI{} = picture, nip05, opts),
    do: create(name, about, URI.to_string(picture), nip05, opts)

  def create(name, about, picture, nip05, opts) do
    content =
      %{}
      |> maybe_put("name", name)
      |> maybe_put("about", about)
      |> maybe_put("picture", picture)
      |> maybe_put("nip05", nip05)
      |> maybe_put("display_name", Keyword.get(opts, :display_name))
      |> maybe_put("website", uri_to_string(Keyword.get(opts, :website)))
      |> maybe_put("banner", uri_to_string(Keyword.get(opts, :banner)))
      |> maybe_put("bot", Keyword.get(opts, :bot))
      |> maybe_put_birthday(Keyword.get(opts, :birthday))
      |> JSON.encode!()

    # Build emoji tags from :emojis option
    emoji_tags = build_emoji_tags(Keyword.get(opts, :emojis))
    # Build identity tags from :identities option (NIP-39)
    identity_tags = build_identity_tags(Keyword.get(opts, :identities))
    existing_tags = Keyword.get(opts, :tags, [])

    opts =
      opts
      |> Keyword.put(:content, content)
      |> Keyword.put(:tags, emoji_tags ++ identity_tags ++ existing_tags)

    0
    |> Nostr.Event.create(opts)
    |> parse()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_put_birthday(map, nil), do: map

  defp maybe_put_birthday(map, %{} = birthday) do
    bd =
      %{}
      |> maybe_put("year", birthday[:year])
      |> maybe_put("month", birthday[:month])
      |> maybe_put("day", birthday[:day])

    if map_size(bd) > 0 do
      Map.put(map, "birthday", bd)
    else
      map
    end
  end

  defp uri_to_string(nil), do: nil
  defp uri_to_string(%URI{} = uri), do: URI.to_string(uri)
  defp uri_to_string(url) when is_binary(url), do: url

  defp build_emoji_tags(nil), do: []
  defp build_emoji_tags(emojis), do: Nostr.NIP30.build_tags(emojis)

  defp build_identity_tags(nil), do: []
  defp build_identity_tags(identities), do: Nostr.NIP39.build_tags(identities)
end
