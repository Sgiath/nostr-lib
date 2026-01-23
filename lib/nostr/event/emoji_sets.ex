defmodule Nostr.Event.EmojiSets do
  @moduledoc """
  Emoji Sets (Kind 30030)

  Categorized custom emoji groups. This is an addressable event with a `d` tag
  identifier. Contains `emoji` tags in NIP-30 format.

  Sets can have optional metadata: title, image, and description.

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  alias Nostr.Event
  alias Nostr.NIP51
  alias Nostr.Tag

  defstruct [:event, :identifier, :title, :image, :description, emojis: []]

  @type emoji_entry() :: %{
          shortcode: binary(),
          url: binary()
        }

  @type t() :: %__MODULE__{
          event: Event.t(),
          identifier: binary(),
          title: binary() | nil,
          image: binary() | nil,
          description: binary() | nil,
          emojis: [emoji_entry()]
        }

  @doc """
  Parses a kind 30030 event into an `EmojiSets` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 30_030} = event) do
    metadata = NIP51.get_set_metadata(event)

    emojis =
      event
      |> NIP51.get_tags_by_type(:emoji)
      |> Enum.map(&parse_emoji_tag/1)

    %__MODULE__{
      event: event,
      identifier: NIP51.get_identifier(event),
      title: metadata.title,
      image: metadata.image,
      description: metadata.description,
      emojis: emojis
    }
  end

  @doc """
  Creates a new emoji set (kind 30030).

  ## Arguments

    - `identifier` - Unique identifier for this set (used in `d` tag)
    - `emojis` - List of emoji entries
    - `opts` - Optional event arguments and set metadata

  ## Emoji Entry Formats

  Emojis can be specified as:
  - `{"shortcode", "https://url.to/emoji.png"}` - Tuple format
  - `%{shortcode: "name", url: "https://..."}` - Map format

  ## Options

    - `:title` - Set title for display
    - `:image` - Set image URL
    - `:description` - Set description
    - `:pubkey` - Event author pubkey
    - `:created_at` - Event timestamp

  ## Example

      EmojiSets.create("party-emojis", [
        {"party", "https://example.com/party.gif"},
        {"celebrate", "https://example.com/celebrate.png"}
      ],
        title: "Party Emojis",
        description: "Celebration themed custom emojis"
      )
  """
  @spec create(binary(), [tuple() | map()], Keyword.t()) :: t()
  def create(identifier, emojis, opts \\ []) when is_binary(identifier) and is_list(emojis) do
    {title, opts} = Keyword.pop(opts, :title)
    {image, opts} = Keyword.pop(opts, :image)
    {description, opts} = Keyword.pop(opts, :description)

    tags =
      [Tag.create(:d, identifier)] ++
        build_metadata_tags(title, image, description) ++
        Enum.map(emojis, &build_emoji_tag/1)

    opts = Keyword.merge(opts, tags: tags, content: "")

    30_030
    |> Event.create(opts)
    |> parse()
  end

  # Private functions

  defp parse_emoji_tag(%Tag{data: shortcode, info: [url | _rest]}) do
    %{shortcode: shortcode, url: url}
  end

  defp parse_emoji_tag(%Tag{data: shortcode, info: []}) do
    %{shortcode: shortcode, url: nil}
  end

  defp build_emoji_tag({shortcode, url}) do
    Tag.create(:emoji, shortcode, [url])
  end

  defp build_emoji_tag(%{shortcode: shortcode, url: url}) do
    Tag.create(:emoji, shortcode, [url])
  end

  defp build_metadata_tags(title, image, description) do
    []
    |> maybe_add_tag(:title, title)
    |> maybe_add_tag(:image, image)
    |> maybe_add_tag(:description, description)
  end

  defp maybe_add_tag(tags, _type, nil), do: tags
  defp maybe_add_tag(tags, type, value), do: tags ++ [Tag.create(type, value)]
end
