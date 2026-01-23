defmodule Nostr.Event.Calendar do
  @moduledoc """
  Calendar (Kind 31924)

  A set of calendar events categorized in any way. This is an addressable event
  with a `d` tag identifier. Contains `a` tags pointing to calendar event events.

  Sets can have optional metadata: title, image, and description.

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  alias Nostr.Event
  alias Nostr.NIP51
  alias Nostr.Tag

  defstruct [:event, :identifier, :title, :image, :description, calendar_events: []]

  @type t() :: %__MODULE__{
          event: Event.t(),
          identifier: binary(),
          title: binary() | nil,
          image: binary() | nil,
          description: binary() | nil,
          calendar_events: [binary()]
        }

  @doc """
  Parses a kind 31924 event into a `Calendar` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 31_924} = event) do
    metadata = NIP51.get_set_metadata(event)

    %__MODULE__{
      event: event,
      identifier: NIP51.get_identifier(event),
      title: metadata.title,
      image: metadata.image,
      description: metadata.description,
      calendar_events: NIP51.get_tag_values(event, :a)
    }
  end

  @doc """
  Creates a new calendar (kind 31924).

  ## Arguments

    - `identifier` - Unique identifier for this calendar (used in `d` tag)
    - `calendar_events` - List of calendar event addresses
    - `opts` - Optional event arguments and set metadata

  ## Options

    - `:title` - Calendar title for display
    - `:image` - Calendar image URL
    - `:description` - Calendar description
    - `:pubkey` - Event author pubkey
    - `:created_at` - Event timestamp

  ## Example

      Calendar.create("tech-meetups", [
        "31922:pubkey:meetup-1",
        "31923:pubkey:conference-2024"
      ],
        title: "Tech Meetups",
        description: "Local technology meetups and conferences"
      )
  """
  @spec create(binary(), [binary()], Keyword.t()) :: t()
  def create(identifier, calendar_events, opts \\ [])
      when is_binary(identifier) and is_list(calendar_events) do
    {title, opts} = Keyword.pop(opts, :title)
    {image, opts} = Keyword.pop(opts, :image)
    {description, opts} = Keyword.pop(opts, :description)

    tags =
      [Tag.create(:d, identifier)] ++
        build_metadata_tags(title, image, description) ++
        Enum.map(calendar_events, &Tag.create(:a, &1))

    opts = Keyword.merge(opts, tags: tags, content: "")

    31_924
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
