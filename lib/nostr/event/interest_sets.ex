defmodule Nostr.Event.InterestSets do
  @moduledoc """
  Interest Sets (Kind 30015)

  Interest topics represented by a bunch of hashtags. This is an addressable
  event with a `d` tag identifier.

  Sets can have optional metadata: title, image, and description.

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  alias Nostr.Event
  alias Nostr.NIP51
  alias Nostr.Tag

  defstruct [:event, :identifier, :title, :image, :description, hashtags: []]

  @type t() :: %__MODULE__{
          event: Event.t(),
          identifier: binary(),
          title: binary() | nil,
          image: binary() | nil,
          description: binary() | nil,
          hashtags: [binary()]
        }

  @doc """
  Parses a kind 30015 event into an `InterestSets` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 30_015} = event) do
    metadata = NIP51.get_set_metadata(event)

    %__MODULE__{
      event: event,
      identifier: NIP51.get_identifier(event),
      title: metadata.title,
      image: metadata.image,
      description: metadata.description,
      hashtags: NIP51.get_tag_values(event, :t)
    }
  end

  @doc """
  Creates a new interest set (kind 30015).

  ## Arguments

    - `identifier` - Unique identifier for this set (used in `d` tag)
    - `hashtags` - List of hashtags (without #)
    - `opts` - Optional event arguments and set metadata

  ## Options

    - `:title` - Set title for display
    - `:image` - Set image URL
    - `:description` - Set description
    - `:pubkey` - Event author pubkey
    - `:created_at` - Event timestamp

  ## Example

      InterestSets.create("tech", ["programming", "opensource", "linux"],
        title: "Tech Interests",
        description: "Technology and software development topics"
      )
  """
  @spec create(binary(), [binary()], Keyword.t()) :: t()
  def create(identifier, hashtags, opts \\ []) when is_binary(identifier) and is_list(hashtags) do
    {title, opts} = Keyword.pop(opts, :title)
    {image, opts} = Keyword.pop(opts, :image)
    {description, opts} = Keyword.pop(opts, :description)

    tags =
      [Tag.create(:d, identifier)] ++
        build_metadata_tags(title, image, description) ++
        Enum.map(hashtags, &Tag.create(:t, &1))

    opts = Keyword.merge(opts, tags: tags, content: "")

    30_015
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
