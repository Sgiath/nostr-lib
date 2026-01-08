defmodule Nostr.Event.DirectMessage do
  @moduledoc """
  Direct encrypted message

  DEPRECATED in favor of NIP-17 (Private Direct Messages)

  Defined in NIP 04
  https://github.com/nostr-protocol/nips/blob/master/04.md
  """
  @moduledoc tags: [:event, :nip04], nip: 04, deprecated: "NIP-17"

  require Logger

  defstruct [:event, :from, :to, :cipher_text, :plain_text]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          from: <<_::32, _::_*8>>,
          to: <<_::32, _::_*8>>,
          cipher_text: binary(),
          plain_text: :not_decrypted | String.t()
        }

  @doc """
  Create a new encrypted direct message (kind 4) event.

  DEPRECATED: Use NIP-17 Private Direct Messages instead.

  ## Arguments:

    - `message` - plaintext message to encrypt
    - `seckey` - sender's secret key (hex string)
    - `recipient` - recipient's public key (hex string)
    - `opts` - optional event arguments (`:reply_to` for threading, plus standard opts)

  """
  @spec create(
          message :: String.t(),
          seckey :: binary(),
          recipient :: binary(),
          opts :: Keyword.t()
        ) ::
          t()
  def create(message, seckey, recipient, opts \\ []) do
    Logger.warning("DirectMessage event (kind 4, NIP-04) is deprecated. Use NIP-17 instead")

    {reply_to, opts} = Keyword.pop(opts, :reply_to)
    encrypted = Nostr.Crypto.encrypt(message, seckey, recipient)

    tags =
      [Nostr.Tag.create(:p, recipient), build_reply_tag(reply_to)]
      |> Enum.reject(&is_nil/1)

    opts = Keyword.merge(opts, tags: tags, content: encrypted)

    4
    |> Nostr.Event.create(opts)
    |> Nostr.Event.sign(seckey)
    |> parse()
    |> Map.put(:plain_text, message)
  end

  defp build_reply_tag(nil), do: nil
  defp build_reply_tag(event_id), do: Nostr.Tag.create(:e, event_id)

  @doc "Parses a kind 4 event into a `DirectMessage` struct. Message remains encrypted. Logs a deprecation warning."
  @spec parse(event :: Nostr.Event.t()) :: __MODULE__.t()
  def parse(%Nostr.Event{kind: 4} = event) do
    Logger.warning("DirectMessage event (kind 4, NIP-04) is deprecated. Use NIP-17 instead")

    %__MODULE__{
      event: event,
      from: event.pubkey,
      to: parse_to(event),
      cipher_text: event.content,
      plain_text: :not_decrypted
    }
  end

  defp parse_to(%Nostr.Event{tags: tags}) do
    case Enum.find(tags, &(&1.type == :p)) do
      %Nostr.Tag{data: to} -> to
      nil -> nil
    end
  end

  @doc """
  Decrypts the message content using the provided secret key.

  Works whether you're the sender or recipient - automatically determines
  which pubkey to use for ECDH shared secret derivation.

  Returns the message with `plain_text` populated, or `:not_decrypted` if
  the secret key doesn't match sender or recipient.
  """
  @spec decrypt(t(), binary()) :: t()
  def decrypt(%__MODULE__{} = msg, seckey) do
    case Nostr.Crypto.pubkey(seckey) do
      p when p == msg.from ->
        plaintext = Nostr.Crypto.decrypt(msg.cipher_text, seckey, msg.to)
        %__MODULE__{msg | plain_text: plaintext}

      p when p == msg.to ->
        plaintext = Nostr.Crypto.decrypt(msg.cipher_text, seckey, msg.from)
        %__MODULE__{msg | plain_text: plaintext}

      _pubkey ->
        %__MODULE__{msg | plain_text: :not_decrypted}
    end
  end
end
