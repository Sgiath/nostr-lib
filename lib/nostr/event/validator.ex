defmodule Nostr.Event.Validator do
  @moduledoc """
  Internal module for validating Nostr events.

  Validation checks:
  1. **ID verification** - Recomputes SHA256 hash and compares with event ID
  2. **Signature verification** - Verifies Schnorr signature against pubkey and event ID

  Both checks must pass for an event to be considered valid.
  """

  @doc """
  Validates an event's ID and signature.

  Returns `true` if both the computed ID matches the event ID and
  the Schnorr signature is valid for the given pubkey.
  """
  @spec valid?(Nostr.Event.t()) :: boolean()
  def valid?(%Nostr.Event{} = event) do
    valid_id?(event) and valid_sig?(event)
  end

  # Verifies that the event ID matches the SHA256 hash of the serialized event
  defp valid_id?(%Nostr.Event{id: id} = event) do
    Nostr.Event.compute_id(event) == id
  end

  # Verifies the Schnorr signature against the event ID and pubkey
  defp valid_sig?(%Nostr.Event{id: id, sig: sig, pubkey: pubkey}) do
    sig_bytes = Base.decode16!(sig, case: :lower)
    id_bytes = Base.decode16!(id, case: :lower)
    pubkey_bytes = Base.decode16!(pubkey, case: :lower)

    Secp256k1.schnorr_valid?(sig_bytes, id_bytes, pubkey_bytes)
  end
end
