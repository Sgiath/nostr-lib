defmodule Nostr.Event.PinnedNotes do
  @moduledoc """
  Pinned Notes (Kind 10001)

  A list of events the user intends to showcase in their profile page.
  Typically contains kind:1 note event IDs.

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  alias Nostr.{Event, Tag, NIP51}

  defstruct [:event, notes: []]

  @type t() :: %__MODULE__{
          event: Event.t(),
          notes: [binary()]
        }

  @doc """
  Parses a kind 10001 event into a `PinnedNotes` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 10_001} = event) do
    %__MODULE__{
      event: event,
      notes: NIP51.get_tag_values(event, :e)
    }
  end

  @doc """
  Creates a new pinned notes list (kind 10001).

  ## Arguments

    - `note_ids` - List of event IDs to pin
    - `opts` - Optional event arguments (`pubkey`, `created_at`)

  ## Example

      iex> PinnedNotes.create(["abc123", "def456"])
  """
  @spec create([binary()], Keyword.t()) :: t()
  def create(note_ids, opts \\ []) when is_list(note_ids) do
    tags = Enum.map(note_ids, &Tag.create(:e, &1))
    opts = Keyword.merge(opts, tags: tags, content: "")

    10_001
    |> Event.create(opts)
    |> parse()
  end
end
