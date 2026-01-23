defmodule Nostr.Event.Communities do
  @moduledoc """
  Communities List (Kind 10004)

  A list of NIP-72 communities the user belongs to. Contains references to
  community definition events (kind:34550) via `a` tags.

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  alias Nostr.Event
  alias Nostr.NIP51
  alias Nostr.Tag

  defstruct [:event, communities: []]

  @type t() :: %__MODULE__{
          event: Event.t(),
          communities: [binary()]
        }

  @doc """
  Parses a kind 10004 event into a `Communities` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 10_004} = event) do
    %__MODULE__{
      event: event,
      communities: NIP51.get_tag_values(event, :a)
    }
  end

  @doc """
  Creates a new communities list (kind 10004).

  ## Arguments

    - `community_refs` - List of community addresses (kind:34550 addressable references)
    - `opts` - Optional event arguments (`pubkey`, `created_at`)

  ## Example

      iex> Communities.create(["34550:pubkey:community-name"])
  """
  @spec create([binary()], Keyword.t()) :: t()
  def create(community_refs, opts \\ []) when is_list(community_refs) do
    tags = Enum.map(community_refs, &Tag.create(:a, &1))
    opts = Keyword.merge(opts, tags: tags, content: "")

    10_004
    |> Event.create(opts)
    |> parse()
  end
end
