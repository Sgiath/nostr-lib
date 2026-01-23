defmodule Nostr.Event.FollowSets do
  @moduledoc """
  Follow Sets (Kind 30000)

  Categorized groups of users a client may choose to check out in different
  circumstances. This is an addressable event with a `d` tag identifier.

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
  Parses a kind 30000 event into a `FollowSets` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 30_000} = event) do
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
  Creates a new follow set (kind 30000).

  ## Arguments

    - `identifier` - Unique identifier for this set (used in `d` tag)
    - `pubkeys` - List of pubkeys to include in the set
    - `opts` - Optional event arguments and set metadata

  ## Options

    - `:title` - Set title for display
    - `:image` - Set image URL
    - `:description` - Set description
    - `:pubkey` - Event author pubkey
    - `:created_at` - Event timestamp

  ## Example

      FollowSets.create("developers", ["pubkey1", "pubkey2"],
        title: "Nostr Developers",
        description: "People building on Nostr"
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

    30_000
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
