defmodule Nostr.Event.EmojiList do
  @moduledoc """
  Emojis List (Kind 10030)

  A list of user preferred custom emojis and pointers to emoji sets. Contains
  `emoji` tags (NIP-30 format) and `a` tags for emoji sets (kind:30030).

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  alias Nostr.Event
  alias Nostr.NIP51
  alias Nostr.Tag

  defstruct [:event, emojis: [], emoji_sets: []]

  @type emoji_entry() :: %{
          shortcode: binary(),
          url: binary()
        }

  @type t() :: %__MODULE__{
          event: Event.t(),
          emojis: [emoji_entry()],
          emoji_sets: [binary()]
        }

  @doc """
  Parses a kind 10030 event into an `EmojiList` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 10_030} = event) do
    emojis =
      event
      |> NIP51.get_tags_by_type(:emoji)
      |> Enum.map(&parse_emoji_tag/1)

    %__MODULE__{
      event: event,
      emojis: emojis,
      emoji_sets: NIP51.get_tag_values(event, :a)
    }
  end

  @doc """
  Creates a new emoji list (kind 10030).

  ## Arguments

    - `items` - Map or keyword list with emoji items
    - `opts` - Optional event arguments (`pubkey`, `created_at`)

  ## Item Keys

    - `:emojis` - List of emoji entries (shortcode + url)
    - `:emoji_sets` - List of emoji set addresses (kind:30030)

  ## Emoji Entry Formats

  Emojis can be specified as:
  - `{"shortcode", "https://url.to/emoji.png"}` - Tuple format
  - `%{shortcode: "name", url: "https://..."}` - Map format

  ## Example

      EmojiList.create(%{
        emojis: [
          {"soapbox", "https://example.com/soapbox.png"},
          %{shortcode: "ditto", url: "https://example.com/ditto.gif"}
        ],
        emoji_sets: ["30030:pubkey:my-emojis"]
      })
  """
  @spec create(map() | Keyword.t(), Keyword.t()) :: t()
  def create(items, opts \\ [])

  def create(items, opts) when is_list(items), do: create(Map.new(items), opts)

  def create(items, opts) when is_map(items) do
    emoji_tags = items |> Map.get(:emojis, []) |> Enum.map(&build_emoji_tag/1)
    set_tags = items |> Map.get(:emoji_sets, []) |> Enum.map(&Tag.create(:a, &1))
    tags = emoji_tags ++ set_tags

    opts = Keyword.merge(opts, tags: tags, content: "")

    10_030
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
end
