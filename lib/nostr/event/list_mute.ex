defmodule Nostr.Event.ListMute do
  @moduledoc """
  List mute event

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  defstruct [:event, :public_mute, :private_mute]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          public_mute: [<<_::32, _::_*8>>],
          private_mute: :not_loaded | [<<_::32, _::_*8>>]
        }

  @doc "Parses a kind 10000 event into a `ListMute` struct. Private list remains encrypted."
  @spec parse(event :: Nostr.Event.t()) :: t()
  def parse(%Nostr.Event{kind: 10_000} = event) do
    %__MODULE__{
      event: event,
      public_mute: get_users_to_mute(event),
      private_mute: :not_loaded
    }
  end

  @doc """
  Decrypts the private mute list using your secret key.

  The secret key must match the event's pubkey (you can only decrypt your own mute list).
  """
  @spec decrypt_private_list(event :: t(), seckey :: <<_::32, _::_*8>>) :: t()
  def decrypt_private_list(
        %__MODULE__{event: %Nostr.Event{pubkey: pubkey, content: content}} = event,
        seckey
      ) do
    if pubkey != Nostr.Crypto.pubkey(seckey) do
      raise "seckey doesn't match the event pubkey"
    end

    private_pubkeys =
      content
      |> Nostr.Crypto.decrypt(seckey, pubkey)
      |> JSON.decode!()
      |> Enum.map(&Nostr.Tag.parse/1)
      |> Enum.filter(fn %Nostr.Tag{type: type} -> type == :p end)
      |> Enum.map(fn %Nostr.Tag{type: :p, data: pubkey} -> pubkey end)

    Map.put(event, :private_mute, private_pubkeys)
  end

  @doc """
  Creates a new mute list event (kind 10000).

  ## Arguments

    - `public_keys` - list of pubkeys to mute publicly
    - `opts` - optional event arguments (`pubkey`, `created_at`, `content` for encrypted private list)

  """
  @spec create(public_keys :: [binary()], opts :: Keyword.t()) :: t()
  def create(public_keys, opts \\ []) do
    tags = Enum.map(public_keys, &Nostr.Tag.create(:p, &1))
    opts = Keyword.put(opts, :tags, tags)

    10_000
    |> Nostr.Event.create(opts)
    |> parse()
  end

  defp get_users_to_mute(%Nostr.Event{tags: tags}) do
    tags
    |> Enum.filter(fn %Nostr.Tag{type: type} -> type == :p end)
    |> Enum.map(fn %Nostr.Tag{type: :p, data: pubkey} -> pubkey end)
  end
end
