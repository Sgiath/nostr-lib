defmodule Nostr.Event.ExternalReaction do
  @moduledoc """
  External content reaction (kind 17).

  Defined in NIP-25: https://github.com/nostr-protocol/nips/blob/master/25.md

  Used when reacting to non-nostr content like websites, podcasts, videos, etc.
  Uses NIP-73 external content `k` + `i` tags to reference the content.

  ## Examples

  Reacting to a website:
  ```json
  {
    "kind": 17,
    "content": "⭐",
    "tags": [
      ["k", "web"],
      ["i", "https://example.com"]
    ]
  }
  ```

  Reacting to a podcast:
  ```json
  {
    "kind": 17,
    "content": "+",
    "tags": [
      ["k", "podcast:guid"],
      ["i", "podcast:guid:917393e3-1b1e-5cef-ace4-edaa54e1f810", "https://fountain.fm/..."]
    ]
  }
  ```
  """
  @moduledoc tags: [:event, :nip25, :nip73], nip: 25

  defstruct [:event, :user, :reaction, :content_type, :identifiers, :emoji_url]

  @type external_id() :: %{id: binary(), hint: binary() | nil}

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          user: binary(),
          reaction: String.t(),
          content_type: binary() | nil,
          identifiers: [external_id()],
          emoji_url: binary() | nil
        }

  @doc """
  Parses a kind 17 event into an `ExternalReaction` struct.
  """
  @spec parse(event :: Nostr.Event.t()) :: t() | {:error, String.t(), Nostr.Event.t()}
  def parse(%Nostr.Event{kind: 17} = event) do
    case get_identifiers(event) do
      [] ->
        {:error, "Cannot find external content identifier (i tag)", event}

      identifiers ->
        %__MODULE__{
          event: event,
          user: event.pubkey,
          reaction: event.content,
          content_type: get_content_type(event),
          identifiers: identifiers,
          emoji_url: get_emoji_url(event)
        }
    end
  end

  @doc """
  Creates a new external content reaction event (kind 17).

  ## Arguments

  - `content_type` - the type of content (e.g., "web", "podcast:guid")
  - `identifier` - the content identifier (URL, GUID, etc.)
  - `reaction` - the reaction content (`+`, `-`, emoji, or `:shortcode:`)
  - `opts` - keyword options:
    - `:pubkey` - pubkey of the reactor (required for unsigned events)
    - `:hint` - optional hint URL for the identifier
    - `:emoji_url` - URL for custom emoji (when reaction is `:shortcode:`)
    - `:tags` - additional tags to include
    - `:created_at` - timestamp (defaults to now)

  ## Examples

      # React to a website
      ExternalReaction.create("web", "https://example.com", "⭐")

      # React to a podcast with hint
      ExternalReaction.create(
        "podcast:guid",
        "podcast:guid:917393e3-1b1e-5cef-ace4-edaa54e1f810",
        "+",
        hint: "https://fountain.fm/show/QRT0l2EfrKXNGDlRrmjL"
      )
  """
  @spec create(
          content_type :: binary(),
          identifier :: binary(),
          reaction :: String.t(),
          opts :: Keyword.t()
        ) :: t()
  def create(content_type, identifier, reaction \\ "+", opts \\ []) do
    hint = Keyword.get(opts, :hint)
    emoji_url = Keyword.get(opts, :emoji_url)
    extra_tags = Keyword.get(opts, :tags, [])

    tags = build_tags(content_type, identifier, hint, emoji_url, reaction)
    event_opts = Keyword.merge(opts, content: reaction, tags: tags ++ extra_tags)

    17
    |> Nostr.Event.create(event_opts)
    |> parse()
  end

  defp build_tags(content_type, identifier, hint, emoji_url, reaction) do
    k_tag = [Nostr.Tag.create(:k, content_type)]
    i_tag = [build_i_tag(identifier, hint)]
    emoji_tag = build_emoji_tag(reaction, emoji_url)

    k_tag ++ i_tag ++ emoji_tag
  end

  defp build_i_tag(identifier, nil), do: Nostr.Tag.create(:i, identifier)
  defp build_i_tag(identifier, hint), do: Nostr.Tag.create(:i, identifier, [hint])

  defp build_emoji_tag(reaction, emoji_url) do
    with true <- is_binary(emoji_url),
         [_, shortcode] <- Regex.run(~r/^:([a-zA-Z0-9_]+):$/, reaction) do
      [Nostr.Tag.create(:emoji, shortcode, [emoji_url])]
    else
      _ -> []
    end
  end

  # Get k tag value (content type)
  defp get_content_type(%Nostr.Event{tags: tags}) do
    case Enum.find(tags, &(&1.type == :k)) do
      %Nostr.Tag{data: content_type} -> content_type
      nil -> nil
    end
  end

  # Get all i tags (identifiers with optional hints)
  defp get_identifiers(%Nostr.Event{tags: tags}) do
    tags
    |> Enum.filter(&(&1.type == :i))
    |> Enum.map(fn %Nostr.Tag{data: id, info: info} ->
      %{id: id, hint: List.first(info)}
    end)
  end

  # Get emoji URL from emoji tag when content is :shortcode:
  defp get_emoji_url(%Nostr.Event{tags: tags, content: content}) do
    with [_, shortcode] <- Regex.run(~r/^:([a-zA-Z0-9_]+):$/, content),
         %Nostr.Tag{data: ^shortcode, info: [url | _]} <-
           Enum.find(tags, &(&1.type == :emoji && &1.data == shortcode)) do
      url
    else
      _ -> nil
    end
  end
end
