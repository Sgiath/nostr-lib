defmodule Nostr.Event.DirectMessage do
  @moduledoc """
  Direct encrypted message

  Defined in NIP 04
  https://github.com/nostr-protocol/nips/blob/master/04.md
  """
  @moduledoc tags: [:event, :nip04], nip: 04

  defstruct [:event, :from, :to, :cipher_text, :plain_text]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          from: <<_::32, _::_*8>>,
          to: <<_::32, _::_*8>>,
          cipher_text: binary(),
          plain_text: :not_decrypted | String.t()
        }

  @spec parse(event :: Nostr.Event.t()) :: __MODULE__.t()
  def parse(%Nostr.Event{kind: 4} = event) do
    %__MODULE__{
      event: event,
      from: event.pubkey,
      to: parse_to(event),
      cipher_text: event.content,
      plain_text: :not_decrypted
    }
  end

  defp parse_to(%Nostr.Event{tags: [%Nostr.Tag{type: :p, data: to} | _rest]}), do: to

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
