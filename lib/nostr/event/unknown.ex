defmodule Nostr.Event.Unknown do
  @moduledoc """
  Unknown event kind wrapper (NIP-31)

  Wraps events of unknown kinds and extracts the `alt` tag if present,
  providing a human-readable description for clients that don't understand
  the event kind.

  ## Usage

  When creating custom event kinds that aren't meant to be read as text,
  include an `alt` tag with a short human-readable plaintext summary:

      Unknown.create(30078, alt: "Application-specific data for MyApp", content: "...")

  See: https://github.com/nostr-protocol/nips/blob/master/31.md
  """
  @moduledoc tags: [:event, :nip31], nip: 31

  alias Nostr.Tag

  defstruct [:event, :alt]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          alt: String.t() | nil
        }

  @doc """
  Parse an event to extract the alt tag.
  """
  @spec parse(Nostr.Event.t()) :: t()
  def parse(%Nostr.Event{} = event) do
    %__MODULE__{
      event: event,
      alt: parse_alt_tag(event.tags)
    }
  end

  @doc """
  Create a new event with an alt tag.

  ## Options

    - `:alt` - human-readable description (required for NIP-31 compliance)
    - `:pubkey` - author pubkey
    - `:created_at` - timestamp
    - `:tags` - additional tags
    - `:content` - event content

  ## Examples

      Unknown.create(30078, alt: "Application data event", content: "...")

      Unknown.create(30078,
        alt: "Custom protocol message",
        content: "...",
        tags: [Tag.create(:d, "identifier")]
      )

  """
  @spec create(kind :: non_neg_integer(), opts :: Keyword.t()) :: t()
  def create(kind, opts \\ []) do
    alt = Keyword.get(opts, :alt)
    alt_tag = if alt, do: [Tag.create(:alt, alt)], else: []
    existing_tags = Keyword.get(opts, :tags, [])

    opts = Keyword.put(opts, :tags, alt_tag ++ existing_tags)

    kind
    |> Nostr.Event.create(opts)
    |> parse()
  end

  defp parse_alt_tag(tags) do
    case Enum.find(tags, &(&1.type == :alt)) do
      %Tag{data: alt} -> alt
      nil -> nil
    end
  end
end
