defmodule Nostr.Event.AppCurationSets do
  @moduledoc """
  App Curation Sets (Kind 30267)

  References to multiple software applications. This is an addressable event
  with a `d` tag identifier. Contains `a` tags pointing to software application
  events.

  Sets can have optional metadata: title, image, and description.

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  alias Nostr.Event
  alias Nostr.NIP51
  alias Nostr.Tag

  defstruct [:event, :identifier, :title, :image, :description, applications: []]

  @type t() :: %__MODULE__{
          event: Event.t(),
          identifier: binary(),
          title: binary() | nil,
          image: binary() | nil,
          description: binary() | nil,
          applications: [binary()]
        }

  @doc """
  Parses a kind 30267 event into an `AppCurationSets` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 30_267} = event) do
    metadata = NIP51.get_set_metadata(event)

    %__MODULE__{
      event: event,
      identifier: NIP51.get_identifier(event),
      title: metadata.title,
      image: metadata.image,
      description: metadata.description,
      applications: NIP51.get_tag_values(event, :a)
    }
  end

  @doc """
  Creates a new app curation set (kind 30267).

  ## Arguments

    - `identifier` - Unique identifier for this set (used in `d` tag)
    - `applications` - List of software application event addresses
    - `opts` - Optional event arguments and set metadata

  ## Options

    - `:title` - Set title for display
    - `:image` - Set image URL
    - `:description` - Set description
    - `:pubkey` - Event author pubkey
    - `:created_at` - Event timestamp

  ## Example

      AppCurationSets.create("nostr-apps", [
        "32267:pubkey:com.example.app1",
        "32267:pubkey:net.example.app2"
      ],
        title: "My Nostr Apps",
        description: "Recommended Nostr applications"
      )
  """
  @spec create(binary(), [binary()], Keyword.t()) :: t()
  def create(identifier, applications, opts \\ [])
      when is_binary(identifier) and is_list(applications) do
    {title, opts} = Keyword.pop(opts, :title)
    {image, opts} = Keyword.pop(opts, :image)
    {description, opts} = Keyword.pop(opts, :description)

    tags =
      [Tag.create(:d, identifier)] ++
        build_metadata_tags(title, image, description) ++
        Enum.map(applications, &Tag.create(:a, &1))

    opts = Keyword.merge(opts, tags: tags, content: "")

    30_267
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
