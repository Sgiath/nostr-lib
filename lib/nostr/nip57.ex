defmodule Nostr.NIP57 do
  @moduledoc """
  NIP-57: Lightning Zaps

  High-level API for creating and validating Lightning zap payments on Nostr.

  ## Overview

  Zaps allow Nostr users to send Lightning payments to each other. The flow is:

  1. Client creates a zap request (kind 9734) and signs it
  2. Client sends the zap request to recipient's LNURL callback URL
  3. LNURL server returns a Lightning invoice
  4. Client pays the invoice
  5. Recipient's wallet publishes a zap receipt (kind 9735)

  ## Examples

      # Create and sign a zap request
      {:ok, zap_request} = NIP57.create_zap_request(
        sender_seckey,
        recipient_pubkey,
        1000,  # sats
        relays: ["wss://relay.example.com"],
        event_id: "event_to_zap",
        message: "Great post!"
      )

      # Build the LNURL callback URL
      callback_url = NIP57.build_callback_url(zap_request, lnurl_callback)

      # Validate a zap receipt
      :ok = NIP57.validate_receipt(receipt, wallet_pubkey)

  See: https://github.com/nostr-protocol/nips/blob/master/57.md
  """
  @moduledoc tags: [:nip57], nip: 57

  alias Nostr.Event
  alias Nostr.Event.ZapReceipt
  alias Nostr.Event.ZapRequest

  @doc """
  Creates and signs a zap request.

  ## Arguments

  - `seckey` - sender's secret key (hex string)
  - `recipient` - recipient's pubkey (hex string)
  - `amount_sats` - amount in satoshis
  - `opts` - additional options

  ## Options

  - `:relays` - list of relays for receipt publication (required)
  - `:event_id` - event being zapped
  - `:address` - addressable event coordinate
  - `:kind` - kind of the zapped event
  - `:message` - optional message/comment
  - `:lnurl` - bech32-encoded lnurl

  ## Returns

  `{:ok, zap_request}` on success, `{:error, reason}` on failure.

  ## Examples

      {:ok, request} = NIP57.create_zap_request(
        seckey,
        "pubkey",
        1000,
        relays: ["wss://relay.example.com"]
      )

  """
  @spec create_zap_request(binary(), binary(), non_neg_integer(), keyword()) ::
          {:ok, ZapRequest.t()} | {:error, String.t()}
  def create_zap_request(seckey, recipient, amount_sats, opts \\ []) do
    relays = Keyword.get(opts, :relays, [])

    if relays == [] do
      {:error, "relays option is required"}
    else
      opts = Keyword.put(opts, :amount_sats, amount_sats)

      zap_request = ZapRequest.create(recipient, relays, opts)

      case zap_request do
        %ZapRequest{} = req ->
          signed_event = Event.sign(req.event, seckey)
          {:ok, %{req | event: signed_event}}

        {:error, _reason, _event} = error ->
          error
      end
    end
  end

  @doc """
  Builds the LNURL callback URL with the zap request.

  The zap request must be signed before calling this function.

  ## Examples

      url = NIP57.build_callback_url(zap_request, "https://lnurl.example.com/callback")
      # => "https://lnurl.example.com/callback?amount=1000000&nostr=..."

  """
  @spec build_callback_url(ZapRequest.t(), binary()) :: binary()
  def build_callback_url(%ZapRequest{} = zap_request, callback_url) do
    ZapRequest.to_callback_url(zap_request, callback_url)
  end

  @doc """
  Validates a zap receipt against the wallet's pubkey.

  Per NIP-57 Appendix F:
  - Receipt's pubkey must match the wallet's `nostrPubkey`
  - Invoice amount must match the zap request's amount tag
  - Zap request's lnurl tag should match recipient's lnurl

  ## Examples

      :ok = NIP57.validate_receipt(receipt, wallet_pubkey)
      {:error, "Receipt pubkey does not match"} = NIP57.validate_receipt(bad_receipt, wallet_pubkey)

  """
  @spec validate_receipt(ZapReceipt.t(), binary()) :: :ok | {:error, String.t()}
  def validate_receipt(%ZapReceipt{} = receipt, wallet_pubkey) do
    ZapReceipt.validate(receipt, wallet_pubkey)
  end

  @doc """
  Returns the zap amount in satoshis from a receipt.
  """
  @spec get_zap_amount(ZapReceipt.t()) :: non_neg_integer() | nil
  def get_zap_amount(%ZapReceipt{} = receipt) do
    ZapReceipt.get_amount_sats(receipt)
  end

  @doc """
  Returns the zap amount in millisatoshis from a receipt.
  """
  @spec get_zap_amount_msats(ZapReceipt.t()) :: non_neg_integer() | nil
  def get_zap_amount_msats(%ZapReceipt{} = receipt) do
    ZapReceipt.get_amount_msats(receipt)
  end

  @doc """
  Returns the embedded zap request from a receipt.

  ## Examples

      {:ok, request} = NIP57.get_zap_request(receipt)
      request.message  # => "Great post!"

  """
  @spec get_zap_request(ZapReceipt.t()) :: {:ok, ZapRequest.t()} | {:error, String.t()}
  def get_zap_request(%ZapReceipt{} = receipt) do
    ZapReceipt.get_zap_request(receipt)
  end

  @doc """
  Checks if a metadata event indicates the user supports zaps.

  A user supports zaps if they have `lud16` (Lightning address) or
  `lud06` (LNURL) in their metadata.

  ## Examples

      metadata = Nostr.Event.Metadata.parse(event)
      NIP57.supports_zaps?(metadata)  # => true/false

  """
  @spec supports_zaps?(map() | struct()) :: boolean()
  def supports_zaps?(%{lud16: lud16}) when is_binary(lud16) and lud16 != "", do: true
  def supports_zaps?(%{lud06: lud06}) when is_binary(lud06) and lud06 != "", do: true
  def supports_zaps?(_metadata), do: false

  @doc """
  Returns the zap sender's pubkey from a receipt.

  Returns the `P` tag value (uppercase), or falls back to the zap request's pubkey.
  """
  @spec get_sender(ZapReceipt.t()) :: binary() | nil
  def get_sender(%ZapReceipt{sender: sender}) when is_binary(sender), do: sender

  def get_sender(%ZapReceipt{zap_request: %ZapRequest{event: %Event{pubkey: pubkey}}})
      when is_binary(pubkey),
      do: pubkey

  def get_sender(_receipt), do: nil

  @doc """
  Returns the zap recipient's pubkey from a receipt.
  """
  @spec get_recipient(ZapReceipt.t()) :: binary() | nil
  def get_recipient(%ZapReceipt{recipient: recipient}), do: recipient

  @doc """
  Returns the zap message/comment from a receipt.
  """
  @spec get_message(ZapReceipt.t()) :: binary()
  def get_message(%ZapReceipt{zap_request: %ZapRequest{message: msg}}) when is_binary(msg),
    do: msg

  def get_message(_receipt), do: ""
end
