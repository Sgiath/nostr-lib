defmodule Nostr.Event.KindMuteSets do
  @moduledoc """
  Kind Mute Sets (Kind 30007)

  Allows muting pubkeys only for specific event kinds. The `d` tag MUST be
  the kind number as a string. This is an addressable event.

  For example, you can mute someone's reposts (kind 6) without muting their
  notes (kind 1).

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  alias Nostr.{Event, Tag, NIP51}

  defstruct [:event, :muted_kind, pubkeys: []]

  @type t() :: %__MODULE__{
          event: Event.t(),
          muted_kind: integer(),
          pubkeys: [binary()]
        }

  @doc """
  Parses a kind 30007 event into a `KindMuteSets` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 30_007} = event) do
    muted_kind =
      case NIP51.get_identifier(event) do
        nil -> nil
        str -> String.to_integer(str)
      end

    %__MODULE__{
      event: event,
      muted_kind: muted_kind,
      pubkeys: NIP51.get_tag_values(event, :p)
    }
  end

  @doc """
  Creates a new kind mute set (kind 30007).

  ## Arguments

    - `muted_kind` - The event kind to mute for these pubkeys (integer)
    - `pubkeys` - List of pubkeys to mute for this kind
    - `opts` - Optional event arguments (`pubkey`, `created_at`)

  ## Example

      # Mute reposts from specific users
      KindMuteSets.create(6, ["pubkey1", "pubkey2"])

      # Mute reactions from specific users
      KindMuteSets.create(7, ["pubkey3"])
  """
  @spec create(integer(), [binary()], Keyword.t()) :: t()
  def create(muted_kind, pubkeys, opts \\ []) when is_integer(muted_kind) and is_list(pubkeys) do
    tags =
      [Tag.create(:d, Integer.to_string(muted_kind))] ++
        Enum.map(pubkeys, &Tag.create(:p, &1))

    opts = Keyword.merge(opts, tags: tags, content: "")

    30_007
    |> Event.create(opts)
    |> parse()
  end
end
