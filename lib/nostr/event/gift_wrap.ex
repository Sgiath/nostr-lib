defmodule Nostr.Event.GiftWrap do
  @moduledoc """
  Gift Wrap event (kind 1059)

  A gift wrap event wraps any other event (typically a seal). It uses a random, one-time-use
  keypair for signing, which obscures the original author's identity. The recipient is identified
  by a `p` tag.

  Gift wrapping provides the outermost layer of privacy in NIP-59's three-layer protocol:
  - Rumor: unsigned event (deniable)
  - Seal: encrypted rumor, signed by author
  - Gift Wrap: encrypted seal, signed with ephemeral key

  Defined in NIP 59
  https://github.com/nostr-protocol/nips/blob/master/59.md
  """
  @moduledoc tags: [:event, :nip59], nip: 59

  alias Nostr.Event
  alias Nostr.Event.Rumor
  alias Nostr.Event.Seal
  alias Nostr.NIP44
  alias Nostr.Tag

  # Two days in seconds for randomized timestamps
  @two_days 2 * 24 * 60 * 60

  defstruct [:event, :recipient, :encrypted_seal]

  @typedoc "Gift wrap event containing an encrypted seal"
  @type t() :: %__MODULE__{
          event: Event.t(),
          recipient: binary(),
          encrypted_seal: binary()
        }

  @doc """
  Parse a kind 1059 event into a GiftWrap struct

  Note: This only extracts the encrypted content. Use `unwrap/2` to decrypt the seal.
  """
  @spec parse(Event.t()) :: t() | {:error, String.t(), Event.t()}
  def parse(%Event{kind: 1059} = event) do
    case get_recipient(event) do
      {:ok, recipient} ->
        %__MODULE__{
          event: event,
          recipient: recipient,
          encrypted_seal: event.content
        }

      {:error, reason} ->
        {:error, reason, event}
    end
  end

  @doc """
  Create a gift wrap from a seal

  Encrypts the seal using NIP-44 with a random ephemeral key and the recipient's public key.
  The gift wrap is signed by the ephemeral key.

  ## Parameters
    - seal: The seal to wrap
    - recipient_pubkey: Recipient's public key (hex-encoded)
    - opts: Optional keyword list:
      - :created_at - override random timestamp
      - :ephemeral_seckey - use specific ephemeral key (for testing)

  ## Example

      gift_wrap = GiftWrap.create(seal, recipient_pubkey)
  """
  @spec create(Seal.t(), binary(), Keyword.t()) :: t()
  def create(%Seal{event: seal_event}, recipient_pubkey, opts \\ []) do
    # Generate ephemeral key or use provided one (for testing)
    ephemeral_seckey = Keyword.get_lazy(opts, :ephemeral_seckey, &generate_seckey/0)

    # Serialize and encrypt the seal event
    seal_json = JSON.encode!(seal_event)
    encrypted_content = NIP44.encrypt(seal_json, ephemeral_seckey, recipient_pubkey)

    # Create gift wrap with randomized timestamp and recipient tag
    created_at = Keyword.get_lazy(opts, :created_at, &random_past_timestamp/0)
    recipient_tag = Tag.create(:p, recipient_pubkey)

    wrap_event =
      1059
      |> Event.create(content: encrypted_content, tags: [recipient_tag], created_at: created_at)
      |> Event.sign(ephemeral_seckey)

    parse(wrap_event)
  end

  @doc """
  Unwrap a gift wrap to extract the seal

  Decrypts the gift wrap's content using the recipient's secret key.
  The ephemeral public key is obtained from the gift wrap event.

  ## Parameters
    - gift_wrap: The gift wrap to unwrap
    - recipient_seckey: Recipient's secret key (hex-encoded)

  ## Returns
    - `{:ok, seal}` on success
    - `{:error, reason}` on failure
  """
  @spec unwrap(t(), binary()) :: {:ok, Seal.t()} | {:error, atom()}
  def unwrap(%__MODULE__{event: event, encrypted_seal: encrypted_content}, recipient_seckey) do
    ephemeral_pubkey = event.pubkey

    with {:ok, seal_json} <- NIP44.decrypt(encrypted_content, recipient_seckey, ephemeral_pubkey),
         {:ok, seal_data} <- JSON.decode(seal_json),
         seal_event <- Event.parse(seal_data),
         true <- seal_event != nil do
      {:ok, Seal.parse(seal_event)}
    else
      false -> {:error, :invalid_seal}
      error -> error
    end
  end

  # ============================================================================
  # Convenience Functions
  # ============================================================================

  @doc """
  Wrap a message in a complete gift wrap (rumor → seal → gift wrap)

  This is a convenience function that performs all three steps of the NIP-59 protocol:
  1. Creates an unsigned rumor from the message
  2. Seals the rumor with the sender's key
  3. Wraps the seal with an ephemeral key

  ## Parameters
    - kind: The event kind for the inner rumor
    - content: The message content
    - sender_seckey: Sender's secret key (hex-encoded)
    - recipient_pubkey: Recipient's public key (hex-encoded)
    - opts: Optional keyword list:
      - :tags - tags for the inner rumor (default: [])
      - :created_at - timestamp for the rumor (default: now)

  ## Example

      gift_wrap = GiftWrap.wrap_message(1, "Hello!", sender_seckey, recipient_pubkey)
  """
  @spec wrap_message(non_neg_integer(), String.t(), binary(), binary(), Keyword.t()) :: t()
  def wrap_message(kind, content, sender_seckey, recipient_pubkey, opts \\ []) do
    sender_pubkey = Nostr.Crypto.pubkey(sender_seckey)

    # Create rumor with sender's pubkey
    rumor_opts = [
      pubkey: sender_pubkey,
      content: content,
      tags: Keyword.get(opts, :tags, []),
      created_at: Keyword.get(opts, :created_at, DateTime.utc_now())
    ]

    rumor = Rumor.create(kind, rumor_opts)

    # Create seal and wrap
    seal = Seal.create(rumor, sender_seckey, recipient_pubkey)
    create(seal, recipient_pubkey)
  end

  @doc """
  Unwrap a gift wrap to extract the original rumor

  This is a convenience function that decrypts all layers:
  1. Unwraps the gift wrap to get the seal
  2. Unwraps the seal to get the rumor

  ## Parameters
    - gift_wrap: The gift wrap to unwrap
    - recipient_seckey: Recipient's secret key (hex-encoded)

  ## Returns
    - `{:ok, rumor}` on success
    - `{:error, reason}` on failure

  ## Example

      {:ok, rumor} = GiftWrap.unwrap_message(gift_wrap, recipient_seckey)
      IO.puts(rumor.content)
  """
  @spec unwrap_message(t(), binary()) :: {:ok, Rumor.t()} | {:error, atom()}
  def unwrap_message(%__MODULE__{} = gift_wrap, recipient_seckey) do
    with {:ok, seal} <- unwrap(gift_wrap, recipient_seckey) do
      Seal.unwrap(seal, recipient_seckey)
    end
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp get_recipient(%Event{tags: tags}) do
    case Enum.find(tags, &(&1.type == :p)) do
      %Tag{data: pubkey} -> {:ok, pubkey}
      nil -> {:error, "Missing recipient p tag"}
    end
  end

  # Generate a random secret key
  defp generate_seckey do
    :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
  end

  # Generate a random timestamp within the past 2 days
  defp random_past_timestamp do
    offset = :rand.uniform(@two_days)
    DateTime.utc_now() |> DateTime.add(-offset, :second)
  end
end
