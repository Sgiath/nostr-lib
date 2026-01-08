defmodule Nostr.Event.ListMute do
  @moduledoc """
  Mute List (Kind 10000)

  A list of things the user doesn't want to see in their feeds. Items can be
  stored publicly in tags or privately in encrypted content.

  ## Supported Item Types

  - `p` tags - Pubkeys of users to mute
  - `t` tags - Hashtags to mute
  - `word` tags - Lowercase strings/words to mute
  - `e` tags - Event IDs (threads) to mute

  ## Private Items

  Private mute items are encrypted in the event content using NIP-44 encryption
  (with NIP-04 fallback for reading legacy data). The encryption uses the author's
  own keypair (same key for sender and recipient).

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  alias Nostr.{Event, Tag, NIP51}

  defstruct [
    :event,
    pubkeys: [],
    hashtags: [],
    words: [],
    threads: [],
    private_pubkeys: :not_loaded,
    private_hashtags: :not_loaded,
    private_words: :not_loaded,
    private_threads: :not_loaded
  ]

  @type t() :: %__MODULE__{
          event: Event.t(),
          pubkeys: [binary()],
          hashtags: [binary()],
          words: [binary()],
          threads: [binary()],
          private_pubkeys: :not_loaded | [binary()],
          private_hashtags: :not_loaded | [binary()],
          private_words: :not_loaded | [binary()],
          private_threads: :not_loaded | [binary()]
        }

  @doc """
  Parses a kind 10000 event into a `ListMute` struct.

  Public items are parsed from tags. Private items remain encrypted until
  `decrypt_private/2` is called.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 10_000} = event) do
    %__MODULE__{
      event: event,
      pubkeys: NIP51.get_tag_values(event, :p),
      hashtags: NIP51.get_tag_values(event, :t),
      words: NIP51.get_tag_values(event, :word),
      threads: NIP51.get_tag_values(event, :e)
    }
  end

  @doc """
  Decrypts the private mute items using your secret key.

  The secret key must match the event's pubkey (you can only decrypt your own
  mute list). Automatically detects NIP-44 vs legacy NIP-04 encryption.

  ## Returns
    - Updated struct with private items populated
    - Raises if secret key doesn't match event pubkey
  """
  @spec decrypt_private(t(), binary()) :: t()
  def decrypt_private(
        %__MODULE__{event: %Event{pubkey: pubkey, content: content}} = mute_list,
        seckey
      ) do
    if pubkey != Nostr.Crypto.pubkey(seckey) do
      raise ArgumentError, "secret key doesn't match the event pubkey"
    end

    case NIP51.decrypt_private_items(content, seckey, pubkey) do
      {:ok, tags} ->
        private_pubkeys = extract_tag_values(tags, :p)
        private_hashtags = extract_tag_values(tags, :t)
        private_words = extract_tag_values(tags, :word)
        private_threads = extract_tag_values(tags, :e)

        %{
          mute_list
          | private_pubkeys: private_pubkeys,
            private_hashtags: private_hashtags,
            private_words: private_words,
            private_threads: private_threads
        }

      {:error, reason} ->
        raise "Failed to decrypt private items: #{inspect(reason)}"
    end
  end

  @doc """
  Creates a new mute list event (kind 10000).

  ## Arguments

    - `items` - Map or keyword list with mute items
    - `opts` - Event options including `:seckey` for encrypting private items

  ## Item Keys

    - `:pubkeys` - List of pubkeys to mute publicly
    - `:hashtags` - List of hashtags to mute publicly
    - `:words` - List of words to mute publicly
    - `:threads` - List of event IDs to mute publicly
    - `:private_pubkeys` - List of pubkeys to mute privately (encrypted)
    - `:private_hashtags` - List of hashtags to mute privately
    - `:private_words` - List of words to mute privately
    - `:private_threads` - List of event IDs to mute privately

  ## Options

    - `:seckey` - Required if any private items are specified
    - `:pubkey` - Event author pubkey (derived from seckey if not provided)
    - `:created_at` - Event timestamp

  ## Examples

      # Public-only mute list
      ListMute.create(%{pubkeys: ["abc123"], hashtags: ["spam"]})

      # With private items
      ListMute.create(
        %{
          pubkeys: ["abc123"],
          private_pubkeys: ["def456"],
          private_words: ["annoying"]
        },
        seckey: my_secret_key
      )
  """
  @spec create(map() | Keyword.t() | [binary()], Keyword.t()) :: t()
  def create(items, opts \\ [])

  # Backward compatibility: list of pubkey strings
  def create([first | _] = public_keys, opts) when is_binary(first) do
    create(%{pubkeys: public_keys}, opts)
  end

  # Keyword list to map conversion
  def create([{_, _} | _] = items, opts), do: create(Map.new(items), opts)

  # Empty list defaults to empty map
  def create([], opts), do: create(%{}, opts)

  def create(items, opts) when is_map(items) do
    {seckey, opts} = Keyword.pop(opts, :seckey)

    # Build public tags
    public_tags = build_public_tags(items)

    # Build encrypted content for private items
    content = build_private_content(items, seckey, opts)

    opts = Keyword.merge(opts, tags: public_tags, content: content)

    10_000
    |> Event.create(opts)
    |> parse()
  end

  # Deprecated function name for backward compatibility
  @doc false
  @deprecated "Use decrypt_private/2 instead"
  def decrypt_private_list(mute_list, seckey) do
    decrypt_private(mute_list, seckey)
  end

  # Private functions

  defp build_public_tags(items) do
    p_tags = items |> Map.get(:pubkeys, []) |> Enum.map(&Tag.create(:p, &1))
    t_tags = items |> Map.get(:hashtags, []) |> Enum.map(&Tag.create(:t, &1))
    word_tags = items |> Map.get(:words, []) |> Enum.map(&Tag.create(:word, &1))
    e_tags = items |> Map.get(:threads, []) |> Enum.map(&Tag.create(:e, &1))

    p_tags ++ t_tags ++ word_tags ++ e_tags
  end

  defp build_private_content(items, seckey, opts) do
    private_tags =
      build_private_tags(
        Map.get(items, :private_pubkeys, []),
        Map.get(items, :private_hashtags, []),
        Map.get(items, :private_words, []),
        Map.get(items, :private_threads, [])
      )

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

  defp build_private_tags(pubkeys, hashtags, words, threads) do
    p_tags = Enum.map(pubkeys, &Tag.create(:p, &1))
    t_tags = Enum.map(hashtags, &Tag.create(:t, &1))
    word_tags = Enum.map(words, &Tag.create(:word, &1))
    e_tags = Enum.map(threads, &Tag.create(:e, &1))

    p_tags ++ t_tags ++ word_tags ++ e_tags
  end

  defp extract_tag_values(tags, type) do
    tags
    |> Enum.filter(fn %Tag{type: t} -> t == type end)
    |> Enum.map(fn %Tag{data: data} -> data end)
  end
end
