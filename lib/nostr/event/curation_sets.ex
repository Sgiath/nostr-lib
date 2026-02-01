defmodule Nostr.Event.CurationSets do
  @moduledoc """
  Curation Sets (Kinds 30004, 30005, 30006)

  Groups of content picked by users as interesting and/or belonging to the
  same category. These are addressable events with a `d` tag identifier.

  ## Kinds

  - **30004**: Article curation - `a` tags for kind:30023, `e` tags for kind:1
  - **30005**: Video curation - `e` tags for kind:21 videos
  - **30006**: Picture curation - `e` tags for kind:20 pictures

  Sets can have optional metadata: title, image, and description.

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  alias Nostr.Event
  alias Nostr.NIP51
  alias Nostr.Tag

  defstruct [:event, :kind, :identifier, :title, :image, :description, items: []]

  @type item() :: %{type: :e | :a, value: binary()}

  @type t() :: %__MODULE__{
          event: Event.t(),
          kind: 30_004 | 30_005 | 30_006,
          identifier: binary(),
          title: binary() | nil,
          image: binary() | nil,
          description: binary() | nil,
          items: [item()]
        }

  @article_kind 30_004
  @video_kind 30_005
  @picture_kind 30_006

  @doc """
  Parses a curation set event (kind 30004, 30005, or 30006).
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: kind} = event)
      when kind in [@article_kind, @video_kind, @picture_kind] do
    metadata = NIP51.get_set_metadata(event)

    items = parse_items(event, kind)

    %__MODULE__{
      event: event,
      kind: kind,
      identifier: NIP51.get_identifier(event),
      title: metadata.title,
      image: metadata.image,
      description: metadata.description,
      items: items
    }
  end

  @doc """
  Creates a new article curation set (kind 30004).

  ## Arguments

    - `identifier` - Unique identifier for this set
    - `items` - Map with `:articles` (a tags) and/or `:notes` (e tags)
    - `opts` - Optional metadata and event arguments

  ## Example

      CurationSets.create_articles("yaks", %{
        articles: ["30023:pubkey:yak-article"],
        notes: ["note_about_yaks_id"]
      },
        title: "Yaks",
        description: "Everything about yaks"
      )
  """
  @spec create_articles(binary(), map() | Keyword.t(), Keyword.t()) :: t()
  def create_articles(identifier, items, opts \\ []) do
    items = if is_list(items), do: Map.new(items), else: items

    a_tags =
      items
      |> Map.get(:articles, [])
      |> Enum.map(&Tag.create(:a, &1))

    e_tags =
      items
      |> Map.get(:notes, [])
      |> Enum.map(&Tag.create(:e, &1))

    create_set(@article_kind, identifier, a_tags ++ e_tags, opts)
  end

  @doc """
  Creates a new video curation set (kind 30005).

  ## Arguments

    - `identifier` - Unique identifier for this set
    - `video_ids` - List of kind:21 video event IDs
    - `opts` - Optional metadata and event arguments

  ## Example

      CurationSets.create_videos("tutorials", ["video1", "video2"],
        title: "Tutorial Videos"
      )
  """
  @spec create_videos(binary(), [binary()], Keyword.t()) :: t()
  def create_videos(identifier, video_ids, opts \\ []) when is_list(video_ids) do
    tags = Enum.map(video_ids, &Tag.create(:e, &1))
    create_set(@video_kind, identifier, tags, opts)
  end

  @doc """
  Creates a new picture curation set (kind 30006).

  ## Arguments

    - `identifier` - Unique identifier for this set
    - `picture_ids` - List of kind:20 picture event IDs
    - `opts` - Optional metadata and event arguments

  ## Example

      CurationSets.create_pictures("landscapes", ["pic1", "pic2"],
        title: "Beautiful Landscapes"
      )
  """
  @spec create_pictures(binary(), [binary()], Keyword.t()) :: t()
  def create_pictures(identifier, picture_ids, opts \\ []) when is_list(picture_ids) do
    tags = Enum.map(picture_ids, &Tag.create(:e, &1))
    create_set(@picture_kind, identifier, tags, opts)
  end

  # Private functions

  defp create_set(kind, identifier, content_tags, opts) do
    {title, opts} = Keyword.pop(opts, :title)
    {image, opts} = Keyword.pop(opts, :image)
    {description, opts} = Keyword.pop(opts, :description)

    tags =
      [Tag.create(:d, identifier)] ++
        build_metadata_tags(title, image, description) ++
        content_tags

    opts = Keyword.merge(opts, tags: tags, content: "")

    kind
    |> Event.create(opts)
    |> parse()
  end

  defp parse_items(event, @article_kind) do
    a_items =
      event
      |> NIP51.get_tag_values(:a)
      |> Enum.map(&%{type: :a, value: &1})

    e_items =
      event
      |> NIP51.get_tag_values(:e)
      |> Enum.map(&%{type: :e, value: &1})

    a_items ++ e_items
  end

  defp parse_items(event, _kind) do
    event
    |> NIP51.get_tag_values(:e)
    |> Enum.map(&%{type: :e, value: &1})
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
