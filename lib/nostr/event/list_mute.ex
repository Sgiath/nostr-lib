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
          users: [<<_::32, _::_*8>>],
          private_mute: :not_loaded | [<<_::32, _::_*8>>]
        }

  @spec parse(event :: Nostr.Event.t()) :: t()
  def parse(%Nostr.Event{kind: 10_000} = event) do
    %__MODULE__{
      event: event,
      public_mute: get_users_to_mute(event),
      private_mute: :not_loaded
    }
  end

  @spec decrypt_private_list(event :: t(), seckey :: <<_::32, _::_*8>>) :: t()
  def decrypt_private_list(
        %__MODULE__{event: %Nostr.Event{pubkey: pubkey, content: content}} = event,
        seckey
      ) do
    unless pubkey == Nostr.Crypto.pubkey(seckey) do
      raise "seckey doesn't match the event pubkey"
    end

    private_pubkeys =
      content
      |> Nostr.Crypto.decrypt(seckey, pubkey)
      |> Jason.decode!(keys: :atoms)
      |> Enum.map(&Nostr.Tag.parse/1)
      |> Enum.filter(fn %Nostr.Tag{type: type} -> type == :p end)
      |> Enum.map(fn %Nostr.Tag{type: :p, data: pubkey} -> pubkey end)

    Map.put(event, :private_mute, private_pubkeys)
  end

  @doc """
  Create new Note Nostr event

  ## Arguments:

    - `note` textual note used as content
    - `opts` other optional event arguments (`pubkey`, `created_at`, `tags`)

  """
  @spec create(note :: String.t(), opts :: Keyword.t()) :: t()
  def create(note, opts \\ []) do
    opts = Keyword.put(opts, :content, note)

    1
    |> Nostr.Event.create(opts)
    |> parse()
  end

  defp get_users_to_mute(%Nostr.Event{tags: tags}) do
    tags
    |> Enum.filter(fn %Nostr.Tag{type: type} -> type == :p end)
    |> Enum.map(fn %Nostr.Tag{type: :p, data: pubkey} -> pubkey end)
  end
end
