defmodule Nostr.Event.RelaySets do
  @moduledoc """
  Relay Sets (Kind 30002)

  User-defined relay groups the user can easily pick and choose from during
  various operations. This is an addressable event with a `d` tag identifier.

  Sets can have optional metadata: title, image, and description.

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  alias Nostr.{Event, Tag, NIP51}

  defstruct [:event, :identifier, :title, :image, :description, relays: []]

  @type t() :: %__MODULE__{
          event: Event.t(),
          identifier: binary(),
          title: binary() | nil,
          image: binary() | nil,
          description: binary() | nil,
          relays: [URI.t()]
        }

  @doc """
  Parses a kind 30002 event into a `RelaySets` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 30_002} = event) do
    metadata = NIP51.get_set_metadata(event)

    relays =
      event
      |> NIP51.get_tag_values(:relay)
      |> Enum.map(&URI.parse/1)

    %__MODULE__{
      event: event,
      identifier: NIP51.get_identifier(event),
      title: metadata.title,
      image: metadata.image,
      description: metadata.description,
      relays: relays
    }
  end

  @doc """
  Creates a new relay set (kind 30002).

  ## Arguments

    - `identifier` - Unique identifier for this set (used in `d` tag)
    - `relay_urls` - List of relay URLs to include in the set
    - `opts` - Optional event arguments and set metadata

  ## Options

    - `:title` - Set title for display
    - `:image` - Set image URL
    - `:description` - Set description
    - `:pubkey` - Event author pubkey
    - `:created_at` - Event timestamp

  ## Example

      RelaySets.create("high-quality", ["wss://relay1.com", "wss://relay2.com"],
        title: "High Quality Relays",
        description: "Relays with good uptime and moderation"
      )
  """
  @spec create(binary(), [binary()], Keyword.t()) :: t()
  def create(identifier, relay_urls, opts \\ [])
      when is_binary(identifier) and is_list(relay_urls) do
    {title, opts} = Keyword.pop(opts, :title)
    {image, opts} = Keyword.pop(opts, :image)
    {description, opts} = Keyword.pop(opts, :description)

    tags =
      [Tag.create(:d, identifier)] ++
        build_metadata_tags(title, image, description) ++
        Enum.map(relay_urls, &Tag.create(:relay, &1))

    opts = Keyword.merge(opts, tags: tags, content: "")

    30_002
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
