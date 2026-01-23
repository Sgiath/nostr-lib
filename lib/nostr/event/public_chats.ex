defmodule Nostr.Event.PublicChats do
  @moduledoc """
  Public Chats List (Kind 10005)

  A list of NIP-28 chat channels the user is in. Contains references to
  channel definition events (kind:40) via `e` tags.

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  alias Nostr.Event
  alias Nostr.NIP51
  alias Nostr.Tag

  defstruct [:event, channels: []]

  @type t() :: %__MODULE__{
          event: Event.t(),
          channels: [binary()]
        }

  @doc """
  Parses a kind 10005 event into a `PublicChats` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 10_005} = event) do
    %__MODULE__{
      event: event,
      channels: NIP51.get_tag_values(event, :e)
    }
  end

  @doc """
  Creates a new public chats list (kind 10005).

  ## Arguments

    - `channel_ids` - List of channel creation event IDs (kind:40)
    - `opts` - Optional event arguments (`pubkey`, `created_at`)

  ## Example

      iex> PublicChats.create(["channel_event_id_1", "channel_event_id_2"])
  """
  @spec create([binary()], Keyword.t()) :: t()
  def create(channel_ids, opts \\ []) when is_list(channel_ids) do
    tags = Enum.map(channel_ids, &Tag.create(:e, &1))
    opts = Keyword.merge(opts, tags: tags, content: "")

    10_005
    |> Event.create(opts)
    |> parse()
  end
end
