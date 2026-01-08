defmodule Nostr.Event.BookmarkSets do
  @moduledoc """
  Bookmark Sets (Kind 30003)

  User-defined bookmark categories for when bookmarks must be in labeled
  separate groups. This is an addressable event with a `d` tag identifier.

  Contains notes (kind:1) via `e` tags and articles (kind:30023) via `a` tags.
  Sets can have optional metadata: title, image, and description.

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  alias Nostr.{Event, Tag, NIP51}

  defstruct [:event, :identifier, :title, :image, :description, notes: [], articles: []]

  @type t() :: %__MODULE__{
          event: Event.t(),
          identifier: binary(),
          title: binary() | nil,
          image: binary() | nil,
          description: binary() | nil,
          notes: [binary()],
          articles: [binary()]
        }

  @doc """
  Parses a kind 30003 event into a `BookmarkSets` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 30_003} = event) do
    metadata = NIP51.get_set_metadata(event)

    %__MODULE__{
      event: event,
      identifier: NIP51.get_identifier(event),
      title: metadata.title,
      image: metadata.image,
      description: metadata.description,
      notes: NIP51.get_tag_values(event, :e),
      articles: NIP51.get_tag_values(event, :a)
    }
  end

  @doc """
  Creates a new bookmark set (kind 30003).

  ## Arguments

    - `identifier` - Unique identifier for this set (used in `d` tag)
    - `items` - Map or keyword list with bookmark items
    - `opts` - Optional event arguments and set metadata

  ## Item Keys

    - `:notes` - List of note event IDs
    - `:articles` - List of article addresses (kind:30023)

  ## Options

    - `:title` - Set title for display
    - `:image` - Set image URL
    - `:description` - Set description
    - `:pubkey` - Event author pubkey
    - `:created_at` - Event timestamp

  ## Example

      BookmarkSets.create("bitcoin-articles", %{
        notes: ["note_id_1"],
        articles: ["30023:pubkey:bitcoin-intro"]
      },
        title: "Bitcoin Articles",
        description: "My favorite Bitcoin content"
      )
  """
  @spec create(binary(), map() | Keyword.t(), Keyword.t()) :: t()
  def create(identifier, items, opts \\ [])

  def create(identifier, items, opts) when is_list(items) do
    create(identifier, Map.new(items), opts)
  end

  def create(identifier, items, opts) when is_binary(identifier) and is_map(items) do
    {title, opts} = Keyword.pop(opts, :title)
    {image, opts} = Keyword.pop(opts, :image)
    {description, opts} = Keyword.pop(opts, :description)

    e_tags = items |> Map.get(:notes, []) |> Enum.map(&Tag.create(:e, &1))
    a_tags = items |> Map.get(:articles, []) |> Enum.map(&Tag.create(:a, &1))

    tags =
      [Tag.create(:d, identifier)] ++
        build_metadata_tags(title, image, description) ++
        e_tags ++
        a_tags

    opts = Keyword.merge(opts, tags: tags, content: "")

    30_003
    |> Event.create(opts)
    |> parse()
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
