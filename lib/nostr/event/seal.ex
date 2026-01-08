defmodule Nostr.Event.Seal do
  @moduledoc """
  Seal event (kind 13)

  A seal is a kind 13 event that wraps a rumor with the sender's regular key. The seal is always
  encrypted to a receiver's pubkey but there is no `p` tag pointing to the receiver. There is no
  way to know who the rumor is for without the receiver's or the sender's private key.

  The only public information in this event is who is signing it.

  Defined in NIP 59
  https://github.com/nostr-protocol/nips/blob/master/59.md
  """
  @moduledoc tags: [:event, :nip59], nip: 59

  alias Nostr.Event
  alias Nostr.Event.Rumor
  alias Nostr.NIP44

  # Two days in seconds for randomized timestamps
  @two_days 2 * 24 * 60 * 60

  defstruct [:event, :sender, :encrypted_rumor]

  @typedoc "Seal event wrapping an encrypted rumor"
  @type t() :: %__MODULE__{
          event: Event.t(),
          sender: binary(),
          encrypted_rumor: binary()
        }

  @doc """
  Parse a kind 13 event into a Seal struct

  Note: This only extracts the encrypted content. Use `unwrap/2` to decrypt the rumor.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 13} = event) do
    %__MODULE__{
      event: event,
      sender: event.pubkey,
      encrypted_rumor: event.content
    }
  end

  @doc """
  Create a seal from a rumor

  Encrypts the rumor using NIP-44 with the sender's secret key and recipient's public key.
  The seal is signed by the sender.

  Tags are always empty per NIP-59 spec.
  The created_at timestamp is randomized within the past 2 days to thwart timing analysis.

  ## Parameters
    - rumor: The rumor to seal (must have pubkey set)
    - sender_seckey: Sender's secret key (hex-encoded)
    - recipient_pubkey: Recipient's public key (hex-encoded)
    - opts: Optional keyword list with :created_at to override random timestamp

  ## Example

      rumor = Rumor.create(1, pubkey: sender_pubkey, content: "Hello")
      seal = Seal.create(rumor, sender_seckey, recipient_pubkey)
  """
  @spec create(Rumor.t(), binary(), binary(), Keyword.t()) :: t()
  def create(%Rumor{} = rumor, sender_seckey, recipient_pubkey, opts \\ []) do
    # Ensure rumor has sender's pubkey
    rumor =
      if rumor.pubkey do
        rumor
      else
        sender_pubkey = Nostr.Crypto.pubkey(sender_seckey)

        %Rumor{
          rumor
          | pubkey: sender_pubkey,
            id: Rumor.compute_id(%Rumor{rumor | pubkey: sender_pubkey})
        }
      end

    # Serialize and encrypt the rumor
    rumor_json = JSON.encode!(rumor)
    encrypted_content = NIP44.encrypt(rumor_json, sender_seckey, recipient_pubkey)

    # Create seal event with randomized timestamp
    created_at = Keyword.get_lazy(opts, :created_at, &random_past_timestamp/0)

    seal_event =
      13
      |> Event.create(content: encrypted_content, tags: [], created_at: created_at)
      |> Event.sign(sender_seckey)

    parse(seal_event)
  end

  @doc """
  Unwrap a seal to extract the rumor

  Decrypts the seal's content using the recipient's secret key.
  The sender's public key is obtained from the seal event.

  ## Parameters
    - seal: The seal to unwrap
    - recipient_seckey: Recipient's secret key (hex-encoded)

  ## Returns
    - `{:ok, rumor}` on success
    - `{:error, reason}` on failure
  """
  @spec unwrap(t(), binary()) :: {:ok, Rumor.t()} | {:error, atom()}
  def unwrap(%__MODULE__{event: event, encrypted_rumor: encrypted_content}, recipient_seckey) do
    sender_pubkey = event.pubkey

    with {:ok, rumor_json} <- NIP44.decrypt(encrypted_content, recipient_seckey, sender_pubkey),
         {:ok, rumor_data} <- JSON.decode(rumor_json) do
      {:ok, Rumor.parse(rumor_data)}
    end
  end

  # Generate a random timestamp within the past 2 days
  defp random_past_timestamp do
    offset = :rand.uniform(@two_days)
    DateTime.utc_now() |> DateTime.add(-offset, :second)
  end
end
