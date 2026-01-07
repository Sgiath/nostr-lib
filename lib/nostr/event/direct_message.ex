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

  defp parse_to(%Nostr.Event{tags: [%Nostr.Tag{type: :p, data: to} | _rest]}), do: to

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
