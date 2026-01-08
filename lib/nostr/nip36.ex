defmodule Nostr.NIP36 do
  @moduledoc """
  NIP-36: Sensitive Content / Content Warning

  The `content-warning` tag enables users to specify if event content needs approval
  before being shown. Clients can hide the content until the user acts on it.

  ## Tag Format

      ["content-warning", "<optional reason>"]

  ## Examples

      # Extract warning from tags
      NIP36.from_tags(event.tags)
      # => "Spoilers" | true | nil

      # Build a warning tag
      NIP36.to_tag("NSFW")
      # => %Tag{type: :"content-warning", data: "NSFW"}

      # Check if event has warning
      NIP36.has_warning?(event)
      # => true | false

  See: https://github.com/nostr-protocol/nips/blob/master/36.md
  """
  @moduledoc tags: [:nip36], nip: 36

  alias Nostr.{Event, Tag}

  @tag_type :"content-warning"

  @typedoc """
  Content warning value.

  - `nil` - no content warning
  - `true` - content warning present but no reason given
  - `binary()` - content warning with reason string
  """
  @type warning() :: binary() | true | nil

  @doc """
  Extracts content warning from a list of tags.

  Returns:
  - The reason string if present and non-empty
  - `true` if the tag is present but has no reason
  - `nil` if no content-warning tag exists

  ## Examples

      iex> tags = [%Tag{type: :"content-warning", data: "Spoilers"}]
      iex> NIP36.from_tags(tags)
      "Spoilers"

      iex> tags = [%Tag{type: :"content-warning", data: ""}]
      iex> NIP36.from_tags(tags)
      true

      iex> NIP36.from_tags([])
      nil

  """
  @spec from_tags([Tag.t()]) :: warning()
  def from_tags(tags) when is_list(tags) do
    case Enum.find(tags, &(&1.type == @tag_type)) do
      %Tag{data: reason} when is_binary(reason) and reason != "" -> reason
      %Tag{} -> true
      nil -> nil
    end
  end

  @doc """
  Builds a content-warning tag.

  ## Examples

      iex> NIP36.to_tag("NSFW")
      %Tag{type: :"content-warning", data: "NSFW", info: []}

      iex> NIP36.to_tag(true)
      %Tag{type: :"content-warning", data: "", info: []}

      iex> NIP36.to_tag(nil)
      nil

  """
  @spec to_tag(warning()) :: Tag.t() | nil
  def to_tag(nil), do: nil
  def to_tag(true), do: Tag.create(@tag_type, "")
  def to_tag(reason) when is_binary(reason), do: Tag.create(@tag_type, reason)

  @doc """
  Checks if an event or list of tags has a content warning.

  ## Examples

      iex> NIP36.has_warning?(%Event{tags: [%Tag{type: :"content-warning", data: ""}]})
      true

      iex> NIP36.has_warning?([%Tag{type: :p, data: "pubkey"}])
      false

  """
  @spec has_warning?(Event.t() | [Tag.t()]) :: boolean()
  def has_warning?(%Event{tags: tags}), do: has_warning?(tags)

  def has_warning?(tags) when is_list(tags) do
    Enum.any?(tags, &(&1.type == @tag_type))
  end

  @doc """
  Adds a content warning tag to an event.

  If the event already has a content-warning tag, it is replaced.

  ## Examples

      iex> event = %Event{tags: []}
      iex> NIP36.add_warning(event, "Spoilers").tags
      [%Tag{type: :"content-warning", data: "Spoilers", info: []}]

      iex> event = %Event{tags: []}
      iex> NIP36.add_warning(event).tags
      [%Tag{type: :"content-warning", data: "", info: []}]

  """
  @spec add_warning(Event.t(), binary() | true) :: Event.t()
  def add_warning(event, reason \\ true)

  def add_warning(%Event{tags: tags} = event, reason) do
    # Remove existing content-warning tag if present
    filtered_tags = Enum.reject(tags, &(&1.type == @tag_type))
    new_tag = to_tag(reason)
    %{event | tags: filtered_tags ++ [new_tag]}
  end

  @doc """
  Removes content warning from an event.

  ## Examples

      iex> tags = [%Tag{type: :"content-warning", data: "test"}]
      iex> event = %Event{tags: tags}
      iex> NIP36.remove_warning(event).tags
      []

  """
  @spec remove_warning(Event.t()) :: Event.t()
  def remove_warning(%Event{tags: tags} = event) do
    %{event | tags: Enum.reject(tags, &(&1.type == @tag_type))}
  end
end
