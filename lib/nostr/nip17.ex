defmodule Nostr.NIP17 do
  @moduledoc """
  NIP-17 Private Direct Messages convenience functions

  High-level API for sending and receiving encrypted private messages using
  the NIP-44 encryption and NIP-59 gift wrap protocol.

  This module provides a simple interface on top of the lower-level primitives:
  - `Nostr.Event.PrivateMessage` - Kind 14 chat messages
  - `Nostr.Event.FileMessage` - Kind 15 encrypted file messages
  - `Nostr.Event.Seal` - Kind 13 sealed events
  - `Nostr.Event.GiftWrap` - Kind 1059 gift wrapped events

  Defined in NIP 17
  https://github.com/nostr-protocol/nips/blob/master/17.md
  """
  @moduledoc tags: [:nip17], nip: 17

  alias Nostr.Event.FileMessage
  alias Nostr.Event.GiftWrap
  alias Nostr.Event.PrivateMessage
  alias Nostr.Event.Rumor
  alias Nostr.Event.Seal

  @doc """
  Send a private direct message

  Creates a kind 14 private message, seals it with the sender's key, and
  gift wraps it for each receiver plus the sender (for sent folder).

  ## Arguments

    - `sender_seckey` - sender's secret key (hex-encoded)
    - `receiver_pubkeys` - list of receiver public keys (hex-encoded)
    - `content` - plain text message content
    - `opts` - optional arguments:
      - `:reply_to` - event ID this message is replying to
      - `:subject` - conversation title
      - `:quotes` - list of quoted event references
      - `:created_at` - timestamp for the inner rumor (default: now)

  ## Returns

    `{:ok, gift_wraps}` where gift_wraps is a list of GiftWrap structs,
    one for each receiver plus one for the sender.

  ## Example

      {:ok, gift_wraps} = Nostr.NIP17.send_dm(
        sender_seckey,
        [recipient_pubkey],
        "Hello, this is a private message!",
        subject: "Greeting"
      )
      # Publish each gift wrap to appropriate relays
  """
  @spec send_dm(binary(), [binary()], binary(), Keyword.t()) ::
          {:ok, [GiftWrap.t()]} | {:error, term()}
  def send_dm(sender_seckey, receiver_pubkeys, content, opts \\ []) do
    sender_pubkey = Nostr.Crypto.pubkey(sender_seckey)

    # Create the private message (rumor)
    message = PrivateMessage.create(sender_pubkey, receiver_pubkeys, content, opts)

    # Wrap for each receiver and the sender
    all_recipients = [sender_pubkey | receiver_pubkeys]
    gift_wraps = wrap_for_recipients(message.rumor, sender_seckey, all_recipients)

    {:ok, gift_wraps}
  end

  @doc """
  Receive a private direct message

  Unwraps a gift wrap to extract and parse the private message.
  Validates that the sender pubkey in the rumor matches the seal's signer.

  ## Arguments

    - `gift_wrap` - a GiftWrap struct or raw Event
    - `recipient_seckey` - recipient's secret key (hex-encoded)

  ## Returns

    - `{:ok, private_message}` on success
    - `{:error, reason}` on failure

  ## Example

      {:ok, message} = Nostr.NIP17.receive_dm(gift_wrap, recipient_seckey)
      IO.puts(message.content)
  """
  @spec receive_dm(GiftWrap.t() | Nostr.Event.t(), binary()) ::
          {:ok, PrivateMessage.t()} | {:error, atom()}
  def receive_dm(gift_wrap, recipient_seckey) do
    with {:ok, rumor, seal} <- unwrap_and_validate(gift_wrap, recipient_seckey),
         %Rumor{kind: 14} <- rumor do
      {:ok, PrivateMessage.parse(rumor), seal.sender}
    else
      %Rumor{kind: kind} -> {:error, {:unexpected_kind, kind}}
      error -> error
    end
  end

  @doc """
  Send a private file message

  Creates a kind 15 file message with encryption metadata, seals it with the
  sender's key, and gift wraps it for each receiver plus the sender.

  ## Arguments

    - `sender_seckey` - sender's secret key (hex-encoded)
    - `receiver_pubkeys` - list of receiver public keys (hex-encoded)
    - `file_url` - URL of the encrypted file
    - `file_metadata` - map with file encryption metadata (see `FileMessage.create/5`)
    - `opts` - optional arguments:
      - `:reply_to` - event ID this message is replying to
      - `:subject` - conversation title
      - `:created_at` - timestamp for the inner rumor (default: now)

  ## Returns

    `{:ok, gift_wraps}` where gift_wraps is a list of GiftWrap structs.

  ## Example

      {:ok, gift_wraps} = Nostr.NIP17.send_file(
        sender_seckey,
        [recipient_pubkey],
        "https://example.com/file.enc",
        %{
          file_type: "image/jpeg",
          encryption_algorithm: "aes-gcm",
          decryption_key: "key123",
          decryption_nonce: "nonce456",
          hash: "abc123"
        }
      )
  """
  @spec send_file(binary(), [binary()], binary(), map(), Keyword.t()) ::
          {:ok, [GiftWrap.t()]} | {:error, term()}
  def send_file(sender_seckey, receiver_pubkeys, file_url, file_metadata, opts \\ []) do
    sender_pubkey = Nostr.Crypto.pubkey(sender_seckey)

    # Create the file message (rumor)
    message = FileMessage.create(sender_pubkey, receiver_pubkeys, file_url, file_metadata, opts)

    # Wrap for each receiver and the sender
    all_recipients = [sender_pubkey | receiver_pubkeys]
    gift_wraps = wrap_for_recipients(message.rumor, sender_seckey, all_recipients)

    {:ok, gift_wraps}
  end

  @doc """
  Receive a private file message

  Unwraps a gift wrap to extract and parse the file message.
  Validates that the sender pubkey in the rumor matches the seal's signer.

  ## Arguments

    - `gift_wrap` - a GiftWrap struct or raw Event
    - `recipient_seckey` - recipient's secret key (hex-encoded)

  ## Returns

    - `{:ok, file_message}` on success
    - `{:error, reason}` on failure

  ## Example

      {:ok, file_msg} = Nostr.NIP17.receive_file(gift_wrap, recipient_seckey)
      IO.puts(file_msg.file_url)
  """
  @spec receive_file(GiftWrap.t() | Nostr.Event.t(), binary()) ::
          {:ok, FileMessage.t()} | {:error, atom()}
  def receive_file(gift_wrap, recipient_seckey) do
    with {:ok, rumor, seal} <- unwrap_and_validate(gift_wrap, recipient_seckey),
         %Rumor{kind: 15} <- rumor do
      {:ok, FileMessage.parse(rumor), seal.sender}
    else
      %Rumor{kind: kind} -> {:error, {:unexpected_kind, kind}}
      error -> error
    end
  end

  @doc """
  Receive any NIP-17 message (kind 14 or 15)

  Unwraps a gift wrap and returns the appropriate message type based on the kind.

  ## Returns

    - `{:ok, message, sender_pubkey}` on success where message is PrivateMessage or FileMessage
    - `{:error, reason}` on failure
  """
  @spec receive_message(GiftWrap.t() | Nostr.Event.t(), binary()) ::
          {:ok, PrivateMessage.t() | FileMessage.t(), binary()} | {:error, atom()}
  def receive_message(gift_wrap, recipient_seckey) do
    with {:ok, rumor, seal} <- unwrap_and_validate(gift_wrap, recipient_seckey) do
      case rumor.kind do
        14 -> {:ok, PrivateMessage.parse(rumor), seal.sender}
        15 -> {:ok, FileMessage.parse(rumor), seal.sender}
        kind -> {:error, {:unsupported_kind, kind}}
      end
    end
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp wrap_for_recipients(rumor, sender_seckey, recipients) do
    Enum.map(recipients, fn recipient_pubkey ->
      seal = Seal.create(rumor, sender_seckey, recipient_pubkey)
      GiftWrap.create(seal, recipient_pubkey)
    end)
  end

  defp unwrap_and_validate(gift_wrap, recipient_seckey) do
    # Parse if raw event
    gift_wrap =
      case gift_wrap do
        %GiftWrap{} -> gift_wrap
        %Nostr.Event{kind: 1059} = event -> GiftWrap.parse(event)
      end

    with {:ok, seal} <- GiftWrap.unwrap(gift_wrap, recipient_seckey),
         {:ok, rumor} <- Seal.unwrap(seal, recipient_seckey),
         :ok <- validate_sender(rumor, seal) do
      {:ok, rumor, seal}
    end
  end

  # Validate that the rumor's pubkey matches the seal's signer
  # Per NIP-17: "Clients MUST verify if pubkey of the kind:13 is the same pubkey on the kind:14"
  defp validate_sender(rumor, seal) do
    if rumor.pubkey == seal.sender do
      :ok
    else
      {:error, :sender_mismatch}
    end
  end
end
