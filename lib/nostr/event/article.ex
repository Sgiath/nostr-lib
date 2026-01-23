defmodule Nostr.Event.Article do
  @moduledoc """
  Long-form content (Kind 30023 for published, Kind 30024 for drafts).

  Implements NIP-23: https://github.com/nostr-protocol/nips/blob/master/23.md

  Articles are addressable events containing Markdown content with optional metadata
  like title, summary, image, and publication date. Also supports NIP-36 content warnings.

  ## Examples

      # Create a published article
      Article.create("# My Article\\n\\nContent here...", "my-article",
        title: "My Article",
        summary: "A brief description",
        image: "https://example.com/image.jpg",
        hashtags: ["nostr", "tutorial"]
      )

      # Create a draft
      Article.create_draft("Work in progress...", "draft-article",
        title: "Draft Title"
      )

      # Publish a draft
      Article.publish(draft_article)

  See:
  - https://github.com/nostr-protocol/nips/blob/master/23.md
  - https://github.com/nostr-protocol/nips/blob/master/36.md
  """
  @moduledoc tags: [:event, :nip23, :nip36], nip: [23, 36]

  alias Nostr.Event
  alias Nostr.Tag

  @kind_published 30_023
  @kind_draft 30_024

  @typedoc "Event reference from e tag"
  @type event_ref() :: %{
          id: binary(),
          relay: binary() | nil
        }

  @typedoc "Addressable event reference from a tag"
  @type addr_ref() :: %{
          coordinates: binary(),
          relay: binary() | nil
        }

  @type t() :: %__MODULE__{
          event: Event.t(),
          identifier: binary(),
          title: binary() | nil,
          image: binary() | nil,
          summary: binary() | nil,
          published_at: DateTime.t() | nil,
          content: binary(),
          hashtags: [binary()],
          event_refs: [event_ref()],
          addr_refs: [addr_ref()],
          content_warning: Nostr.NIP36.warning(),
          draft?: boolean()
        }

  defstruct [
    :event,
    :identifier,
    :title,
    :image,
    :summary,
    :published_at,
    :content,
    :content_warning,
    hashtags: [],
    event_refs: [],
    addr_refs: [],
    draft?: false
  ]

  @doc """
  Parses a kind 30023 or 30024 event into an Article struct.
  """
  @spec parse(Event.t()) :: t() | {:error, String.t(), Event.t()}
  def parse(%Event{kind: kind} = event) when kind in [@kind_published, @kind_draft] do
    %__MODULE__{
      event: event,
      identifier: get_identifier(event),
      title: get_tag_value(event, "title"),
      image: get_tag_value(event, "image"),
      summary: get_tag_value(event, "summary"),
      published_at: get_published_at(event),
      content: event.content,
      hashtags: get_hashtags(event),
      event_refs: get_event_refs(event),
      addr_refs: get_addr_refs(event),
      content_warning: Nostr.NIP36.from_tags(event.tags),
      draft?: kind == @kind_draft
    }
  end

  def parse(%Event{} = event) do
    {:error, "Event is not an article (expected kind 30023 or 30024)", event}
  end

  @doc """
  Creates a published article (kind 30023).

  ## Options

  - `:title` - Article title
  - `:image` - URL to header image
  - `:summary` - Brief description
  - `:published_at` - DateTime of first publication (defaults to now)
  - `:hashtags` - List of topic hashtags
  - `:event_refs` - List of referenced event IDs or `{id, relay}` tuples
  - `:addr_refs` - List of referenced addressable event coordinates or `{coord, relay}` tuples
  - `:content_warning` - NIP-36 content warning (string reason or `true` for no reason)

  ## Examples

      Article.create("# Hello\\n\\nWorld", "hello-world", title: "Hello")

      Article.create("Sensitive content", "nsfw-article", content_warning: "NSFW")

  """
  @spec create(binary(), binary(), keyword()) :: t()
  def create(content, identifier, opts \\ []) do
    opts = Keyword.put(opts, :draft, false)
    do_create(content, identifier, opts)
  end

  @doc """
  Creates a draft article (kind 30024).

  Takes the same options as `create/3`.
  """
  @spec create_draft(binary(), binary(), keyword()) :: t()
  def create_draft(content, identifier, opts \\ []) do
    opts = Keyword.put(opts, :draft, true)
    do_create(content, identifier, opts)
  end

  @doc """
  Converts a draft article to a published article (kind 30024 -> 30023).

  Sets `published_at` to the current time if not already set.
  """
  @spec publish(t()) :: t()
  def publish(%__MODULE__{draft?: true} = article) do
    published_at = article.published_at || DateTime.utc_now()

    tags =
      build_tags(
        article.identifier,
        title: article.title,
        image: article.image,
        summary: article.summary,
        published_at: published_at,
        hashtags: article.hashtags,
        event_refs: Enum.map(article.event_refs, &event_ref_to_tuple/1),
        addr_refs: Enum.map(article.addr_refs, &addr_ref_to_tuple/1),
        content_warning: article.content_warning
      )

    event =
      @kind_published
      |> Event.create(tags: tags, content: article.content)
      |> parse()

    %{event | published_at: published_at}
  end

  def publish(%__MODULE__{draft?: false} = article), do: article

  @doc """
  Returns true if this is a draft article.
  """
  @spec draft?(t()) :: boolean()
  def draft?(%__MODULE__{draft?: draft}), do: draft

  @doc """
  Returns the article's address coordinates for use in `a` tags.

  Format: `30023:<pubkey>:<identifier>` or `30024:<pubkey>:<identifier>`
  """
  @spec coordinates(t()) :: binary() | nil
  def coordinates(%__MODULE__{event: %Event{pubkey: nil}}), do: nil

  def coordinates(%__MODULE__{event: event, identifier: identifier, draft?: draft?}) do
    kind = if draft?, do: @kind_draft, else: @kind_published
    "#{kind}:#{event.pubkey}:#{identifier}"
  end

  # Private functions

  defp do_create(content, identifier, opts) do
    draft? = Keyword.get(opts, :draft, false)
    kind = if draft?, do: @kind_draft, else: @kind_published

    tags = build_tags(identifier, opts)

    kind
    |> Event.create(tags: tags, content: content)
    |> parse()
  end

  defp build_tags(identifier, opts) do
    title = Keyword.get(opts, :title)
    image = Keyword.get(opts, :image)
    summary = Keyword.get(opts, :summary)
    published_at = Keyword.get(opts, :published_at)
    hashtags = Keyword.get(opts, :hashtags, [])
    event_refs = Keyword.get(opts, :event_refs, [])
    addr_refs = Keyword.get(opts, :addr_refs, [])
    content_warning = Keyword.get(opts, :content_warning)

    [Tag.create(:d, identifier)] ++
      maybe_tag("title", title) ++
      maybe_tag("image", image) ++
      maybe_tag("summary", summary) ++
      maybe_published_at_tag(published_at) ++
      maybe_content_warning_tag(content_warning) ++
      Enum.map(hashtags, &Tag.create(:t, &1)) ++
      Enum.map(event_refs, &build_event_ref_tag/1) ++
      Enum.map(addr_refs, &build_addr_ref_tag/1)
  end

  defp maybe_tag(_type, nil), do: []
  defp maybe_tag(type, value), do: [Tag.create(type, value)]

  defp maybe_published_at_tag(nil), do: []

  defp maybe_published_at_tag(%DateTime{} = dt) do
    [Tag.create("published_at", Integer.to_string(DateTime.to_unix(dt)))]
  end

  defp maybe_content_warning_tag(nil), do: []
  defp maybe_content_warning_tag(value), do: [Nostr.NIP36.to_tag(value)]

  defp build_event_ref_tag({id, relay}) when is_binary(relay), do: Tag.create(:e, id, [relay])
  defp build_event_ref_tag(id) when is_binary(id), do: Tag.create(:e, id)

  defp build_addr_ref_tag({coord, relay}) when is_binary(relay),
    do: Tag.create(:a, coord, [relay])

  defp build_addr_ref_tag(coord) when is_binary(coord), do: Tag.create(:a, coord)

  defp event_ref_to_tuple(%{id: id, relay: nil}), do: id
  defp event_ref_to_tuple(%{id: id, relay: relay}), do: {id, relay}

  defp addr_ref_to_tuple(%{coordinates: coord, relay: nil}), do: coord
  defp addr_ref_to_tuple(%{coordinates: coord, relay: relay}), do: {coord, relay}

  defp get_identifier(%Event{tags: tags}) do
    case Enum.find(tags, &(&1.type == :d)) do
      %Tag{data: id} -> id
      nil -> ""
    end
  end

  defp get_tag_value(%Event{tags: tags}, type) do
    case Enum.find(tags, &(to_string(&1.type) == type)) do
      %Tag{data: value} -> value
      nil -> nil
    end
  end

  defp get_published_at(%Event{tags: tags}) do
    case Enum.find(tags, &(to_string(&1.type) == "published_at")) do
      %Tag{data: timestamp} ->
        case Integer.parse(timestamp) do
          {unix, ""} -> DateTime.from_unix!(unix)
          _parse_fail -> nil
        end

      nil ->
        nil
    end
  end

  defp get_hashtags(%Event{tags: tags}) do
    tags
    |> Enum.filter(&(&1.type == :t))
    |> Enum.map(& &1.data)
  end

  defp get_event_refs(%Event{tags: tags}) do
    tags
    |> Enum.filter(&(&1.type == :e))
    |> Enum.map(fn %Tag{data: id, info: info} ->
      %{id: id, relay: List.first(info)}
    end)
  end

  defp get_addr_refs(%Event{tags: tags}) do
    tags
    |> Enum.filter(&(&1.type == :a))
    |> Enum.map(fn %Tag{data: coord, info: info} ->
      %{coordinates: coord, relay: List.first(info)}
    end)
  end
end
