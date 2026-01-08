defmodule Nostr.Event.GoodWikiAuthors do
  @moduledoc """
  Good Wiki Authors List (Kind 10101)

  A list of NIP-54 user recommended wiki authors. Contains pubkeys via `p` tags.
  Used to help users discover trustworthy wiki contributors.

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  alias Nostr.{Event, Tag, NIP51}

  defstruct [:event, authors: []]

  @type t() :: %__MODULE__{
          event: Event.t(),
          authors: [binary()]
        }

  @doc """
  Parses a kind 10101 event into a `GoodWikiAuthors` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 10_101} = event) do
    %__MODULE__{
      event: event,
      authors: NIP51.get_tag_values(event, :p)
    }
  end

  @doc """
  Creates a new good wiki authors list (kind 10101).

  ## Arguments

    - `pubkeys` - List of pubkeys of recommended wiki authors
    - `opts` - Optional event arguments (`pubkey`, `created_at`)

  ## Example

      iex> GoodWikiAuthors.create(["author_pubkey_1", "author_pubkey_2"])
  """
  @spec create([binary()], Keyword.t()) :: t()
  def create(pubkeys, opts \\ []) when is_list(pubkeys) do
    tags = Enum.map(pubkeys, &Tag.create(:p, &1))
    opts = Keyword.merge(opts, tags: tags, content: "")

    10_101
    |> Event.create(opts)
    |> parse()
  end
end
