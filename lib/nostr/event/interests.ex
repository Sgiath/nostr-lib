defmodule Nostr.Event.Interests do
  @moduledoc """
  Interests List (Kind 10015)

  A list of topics a user may be interested in. Contains hashtags via `t` tags
  and pointers to interest sets (kind:30015) via `a` tags.

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  alias Nostr.Event
  alias Nostr.NIP51
  alias Nostr.Tag

  defstruct [:event, hashtags: [], interest_sets: []]

  @type t() :: %__MODULE__{
          event: Event.t(),
          hashtags: [binary()],
          interest_sets: [binary()]
        }

  @doc """
  Parses a kind 10015 event into an `Interests` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 10_015} = event) do
    %__MODULE__{
      event: event,
      hashtags: NIP51.get_tag_values(event, :t),
      interest_sets: NIP51.get_tag_values(event, :a)
    }
  end

  @doc """
  Creates a new interests list (kind 10015).

  ## Arguments

    - `items` - Map or keyword list with interest items
    - `opts` - Optional event arguments (`pubkey`, `created_at`)

  ## Item Keys

    - `:hashtags` - List of hashtags (without #)
    - `:interest_sets` - List of interest set addresses (kind:30015)

  ## Example

      Interests.create(%{
        hashtags: ["nostr", "bitcoin", "lightning"],
        interest_sets: ["30015:pubkey:tech-interests"]
      })
  """
  @spec create(map() | Keyword.t(), Keyword.t()) :: t()
  def create(items, opts \\ [])

  def create(items, opts) when is_list(items), do: create(Map.new(items), opts)

  def create(items, opts) when is_map(items) do
    t_tags = items |> Map.get(:hashtags, []) |> Enum.map(&Tag.create(:t, &1))
    a_tags = items |> Map.get(:interest_sets, []) |> Enum.map(&Tag.create(:a, &1))
    tags = t_tags ++ a_tags

    opts = Keyword.merge(opts, tags: tags, content: "")

    10_015
    |> Event.create(opts)
    |> parse()
  end
end
