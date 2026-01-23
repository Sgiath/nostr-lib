defmodule Nostr.NIP30 do
  @moduledoc """
  Custom Emoji helpers (NIP-30)

  Custom emoji may be added to kind 0, kind 1, kind 7, and kind 30315 events
  by including emoji tags in the form: `["emoji", shortcode, image-url]`

  Shortcodes must be alphanumeric characters and underscores only.
  Clients parse `:shortcode:` patterns in content to display custom emoji.

  ## Examples

      # Create emoji tags from a map
      NIP30.build_tags(%{"wave" => "https://example.com/wave.png"})

      # Extract emoji map from event tags
      NIP30.from_tags(event.tags)
      # => %{"wave" => "https://example.com/wave.png"}

      # Find shortcodes in content
      NIP30.extract_shortcodes("Hello :wave: world!")
      # => ["wave"]

  Defined in NIP 30
  https://github.com/nostr-protocol/nips/blob/master/30.md
  """
  @moduledoc tags: [:nip30], nip: 30

  alias Nostr.Tag

  # Valid shortcode pattern: alphanumeric + underscore only
  @shortcode_regex ~r/^[a-zA-Z0-9_]+$/

  # Pattern to find :shortcode: in content
  @emoji_pattern ~r/:([a-zA-Z0-9_]+):/

  @doc """
  Creates a single emoji tag.

  ## Examples

      iex> Nostr.NIP30.to_tag("wave", "https://example.com/wave.png")
      %Nostr.Tag{type: :emoji, data: "wave", info: ["https://example.com/wave.png"]}

  """
  @spec to_tag(binary(), binary()) :: Tag.t()
  def to_tag(shortcode, url) when is_binary(shortcode) and is_binary(url) do
    Tag.create(:emoji, shortcode, [url])
  end

  @doc """
  Extracts emoji tags from a list of tags into a map of shortcode => url.

  ## Examples

      iex> tags = [
      ...>   %Nostr.Tag{type: :emoji, data: "wave", info: ["https://example.com/wave.png"]},
      ...>   %Nostr.Tag{type: :p, data: "pubkey123", info: []}
      ...> ]
      iex> Nostr.NIP30.from_tags(tags)
      %{"wave" => "https://example.com/wave.png"}

  """
  @spec from_tags([Tag.t()]) :: %{binary() => binary()}
  def from_tags(tags) when is_list(tags) do
    tags
    |> Enum.filter(fn %Tag{type: type} -> type == :emoji end)
    |> Enum.reduce(%{}, fn %Tag{data: shortcode, info: info}, acc ->
      case info do
        [url | _rest] when is_binary(url) -> Map.put(acc, shortcode, url)
        _no_url -> acc
      end
    end)
  end

  @doc """
  Extracts all `:shortcode:` patterns from content text.

  Returns a list of shortcodes (without the colons).

  ## Examples

      iex> Nostr.NIP30.extract_shortcodes("Hello :wave: and :smile:!")
      ["wave", "smile"]

      iex> Nostr.NIP30.extract_shortcodes("No emojis here")
      []

  """
  @spec extract_shortcodes(binary()) :: [binary()]
  def extract_shortcodes(content) when is_binary(content) do
    @emoji_pattern
    |> Regex.scan(content)
    |> Enum.map(fn [_full_match, shortcode] -> shortcode end)
  end

  @doc """
  Validates if a shortcode has valid format (alphanumeric + underscore only).

  ## Examples

      iex> Nostr.NIP30.valid_shortcode?("wave")
      true

      iex> Nostr.NIP30.valid_shortcode?("my_emoji_123")
      true

      iex> Nostr.NIP30.valid_shortcode?("invalid-emoji")
      false

      iex> Nostr.NIP30.valid_shortcode?("has space")
      false

  """
  @spec valid_shortcode?(binary()) :: boolean()
  def valid_shortcode?(shortcode) when is_binary(shortcode) do
    Regex.match?(@shortcode_regex, shortcode)
  end

  @doc """
  Builds emoji tags from a map or list of emoji definitions.

  Accepts:
  - Map: `%{"shortcode" => "url", ...}`
  - Keyword list: `[shortcode: "url", ...]`
  - List of tuples: `[{"shortcode", "url"}, ...]`

  ## Examples

      iex> Nostr.NIP30.build_tags(%{"wave" => "https://example.com/wave.png"})
      [%Nostr.Tag{type: :emoji, data: "wave", info: ["https://example.com/wave.png"]}]

      iex> Nostr.NIP30.build_tags([{"smile", "https://example.com/smile.png"}])
      [%Nostr.Tag{type: :emoji, data: "smile", info: ["https://example.com/smile.png"]}]

  """
  @spec build_tags(map() | Keyword.t() | [{binary(), binary()}]) :: [Tag.t()]
  def build_tags(emojis) when is_map(emojis) do
    emojis
    |> Enum.map(fn {shortcode, url} -> to_tag(to_string(shortcode), url) end)
  end

  def build_tags(emojis) when is_list(emojis) do
    emojis
    |> Enum.map(fn
      {shortcode, url} when is_atom(shortcode) -> to_tag(Atom.to_string(shortcode), url)
      {shortcode, url} -> to_tag(shortcode, url)
    end)
  end

  @doc """
  Checks if content contains any `:shortcode:` patterns.

  ## Examples

      iex> Nostr.NIP30.has_emojis?("Hello :wave:!")
      true

      iex> Nostr.NIP30.has_emojis?("No emojis here")
      false

  """
  @spec has_emojis?(binary()) :: boolean()
  def has_emojis?(content) when is_binary(content) do
    Regex.match?(@emoji_pattern, content)
  end
end
