defmodule Nostr.Event.MediaStarterPacks do
  @moduledoc """
  Media Starter Packs (Kind 39092)

  Same as Starter Packs (kind 39089), but specific to multimedia (photos, short
  video) clients. This is an addressable event with a `d` tag identifier.

  Sets can have optional metadata: title, image, and description.

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  alias Nostr.Event
  alias Nostr.NIP51
  alias Nostr.Tag

  defstruct [:event, :identifier, :title, :image, :description, pubkeys: []]

  @type t() :: %__MODULE__{
          event: Event.t(),
          identifier: binary(),
          title: binary() | nil,
          image: binary() | nil,
          description: binary() | nil,
          pubkeys: [binary()]
        }

  @doc """
  Parses a kind 39092 event into a `MediaStarterPacks` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 39_092} = event) do
    metadata = NIP51.get_set_metadata(event)

    %__MODULE__{
      event: event,
      identifier: NIP51.get_identifier(event),
      title: metadata.title,
      image: metadata.image,
      description: metadata.description,
      pubkeys: NIP51.get_tag_values(event, :p)
    }
  end

  @doc """
  Creates a new media starter pack (kind 39092).

  ## Arguments

    - `identifier` - Unique identifier for this starter pack
    - `pubkeys` - List of pubkeys to include in the pack
    - `opts` - Optional event arguments and set metadata

  ## Options

    - `:title` - Starter pack title for display
    - `:image` - Starter pack image URL
    - `:description` - Starter pack description
    - `:pubkey` - Event author pubkey
    - `:created_at` - Event timestamp

  ## Example

      MediaStarterPacks.create("photographers", [
        "pubkey1",
        "pubkey2"
      ],
        title: "Top Photographers",
        description: "Amazing photography accounts to follow"
      )
  """
  @spec create(binary(), [binary()], Keyword.t()) :: t()
  def create(identifier, pubkeys, opts \\ []) when is_binary(identifier) and is_list(pubkeys) do
    {title, opts} = Keyword.pop(opts, :title)
    {image, opts} = Keyword.pop(opts, :image)
    {description, opts} = Keyword.pop(opts, :description)

    tags =
      [Tag.create(:d, identifier)] ++
        build_metadata_tags(title, image, description) ++
        Enum.map(pubkeys, &Tag.create(:p, &1))

    opts = Keyword.merge(opts, tags: tags, content: "")

    39_092
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
