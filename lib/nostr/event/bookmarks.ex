defmodule Nostr.Event.Bookmarks do
  @moduledoc """
  Bookmarks (Kind 10003)

  An uncategorized, "global" list of things a user wants to save. Can include
  notes (kind:1) via `e` tags and articles (kind:30023) via `a` tags.

  Supports both public bookmarks (in tags) and private bookmarks (encrypted
  in content using NIP-44).

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  alias Nostr.Event
  alias Nostr.NIP51
  alias Nostr.Tag

  defstruct [
    :event,
    notes: [],
    articles: [],
    private_notes: :not_loaded,
    private_articles: :not_loaded
  ]

  @type t() :: %__MODULE__{
          event: Event.t(),
          notes: [binary()],
          articles: [binary()],
          private_notes: :not_loaded | [binary()],
          private_articles: :not_loaded | [binary()]
        }

  @doc """
  Parses a kind 10003 event into a `Bookmarks` struct.

  Public bookmarks are parsed from tags. Private bookmarks remain encrypted
  until `decrypt_private/2` is called.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 10_003} = event) do
    %__MODULE__{
      event: event,
      notes: NIP51.get_tag_values(event, :e),
      articles: NIP51.get_tag_values(event, :a)
    }
  end

  @doc """
  Decrypts the private bookmarks using your secret key.

  The secret key must match the event's pubkey (you can only decrypt your own
  bookmarks). Automatically detects NIP-44 vs legacy NIP-04 encryption.
  """
  @spec decrypt_private(t(), binary()) :: t()
  def decrypt_private(
        %__MODULE__{event: %Event{pubkey: pubkey, content: content}} = bookmarks,
        seckey
      ) do
    if pubkey != Nostr.Crypto.pubkey(seckey) do
      raise ArgumentError, "secret key doesn't match the event pubkey"
    end

    case NIP51.decrypt_private_items(content, seckey, pubkey) do
      {:ok, tags} ->
        private_notes = extract_tag_values(tags, :e)
        private_articles = extract_tag_values(tags, :a)

        %{
          bookmarks
          | private_notes: private_notes,
            private_articles: private_articles
        }

      {:error, reason} ->
        raise "Failed to decrypt private bookmarks: #{inspect(reason)}"
    end
  end

  @doc """
  Creates a new bookmarks event (kind 10003).

  ## Arguments

    - `items` - Map or keyword list with bookmark items
    - `opts` - Event options including `:seckey` for encrypting private items

  ## Item Keys

    - `:notes` - List of note event IDs to bookmark publicly
    - `:articles` - List of article addresses (kind:30023) to bookmark publicly
    - `:private_notes` - List of note event IDs to bookmark privately
    - `:private_articles` - List of article addresses to bookmark privately

  ## Options

    - `:seckey` - Required if any private items are specified
    - `:pubkey` - Event author pubkey
    - `:created_at` - Event timestamp

  ## Example

      Bookmarks.create(%{
        notes: ["abc123"],
        articles: ["30023:pubkey:identifier"],
        private_notes: ["secret_note_id"]
      }, seckey: my_secret_key)
  """
  @spec create(map() | Keyword.t(), Keyword.t()) :: t()
  def create(items, opts \\ [])

  def create(items, opts) when is_list(items), do: create(Map.new(items), opts)

  def create(items, opts) when is_map(items) do
    {seckey, opts} = Keyword.pop(opts, :seckey)

    # Build public tags
    e_tags =
      items
      |> Map.get(:notes, [])
      |> Enum.map(&Tag.create(:e, &1))

    a_tags =
      items
      |> Map.get(:articles, [])
      |> Enum.map(&Tag.create(:a, &1))

    public_tags = e_tags ++ a_tags

    # Build encrypted content for private items
    content = build_private_content(items, seckey, opts)

    opts = Keyword.merge(opts, tags: public_tags, content: content)

    10_003
    |> Event.create(opts)
    |> parse()
  end

  # Private functions

  defp build_private_content(items, seckey, opts) do
    private_e_tags =
      items
      |> Map.get(:private_notes, [])
      |> Enum.map(&Tag.create(:e, &1))

    private_a_tags =
      items
      |> Map.get(:private_articles, [])
      |> Enum.map(&Tag.create(:a, &1))

    private_tags = private_e_tags ++ private_a_tags

    case private_tags do
      [] ->
        ""

      _tags when is_nil(seckey) ->
        raise ArgumentError, "seckey required to encrypt private items"

      tags ->
        pubkey = Keyword.get_lazy(opts, :pubkey, fn -> Nostr.Crypto.pubkey(seckey) end)
        NIP51.encrypt_private_items(tags, seckey, pubkey)
    end
  end

  defp extract_tag_values(tags, type) do
    tags
    |> Enum.filter(fn %Tag{type: t} -> t == type end)
    |> Enum.map(fn %Tag{data: data} -> data end)
  end
end
