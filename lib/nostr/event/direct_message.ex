defmodule Nostr.Event.DirectMessage do
  @moduledoc """
  Direct encrypted message

  Defined in NIP 04
  https://github.com/nostr-protocol/nips/blob/master/04.md
  """

  defstruct [:event, :from, :to, :cipher_text, :plain_text]

  def parse(%Nostr.Event{kind: 4} = event) do
    %__MODULE__{
      event: event,
      from: event.pubkey,
      to: parse_to(event.tags),
      cipher_text: event.content,
      plain_text: :not_decrypted
    }
  end

  defp parse_to([%Nostr.Tag{type: :p, data: to} | _rest]), do: to

  def decrypt(%__MODULE__{} = msg, seckey) do
    case Nostr.Crypto.pubkey(seckey) do
      p when p == msg.from -> Nostr.Crypto.decrypt(msg.cipher_text, seckey, msg.to)
      p when p == msg.to -> Nostr.Crypto.decrypt(msg.cipher_text, seckey, msg.from)
      _pubkey -> {:error, :cannot_decrypt}
    end
  end
end
