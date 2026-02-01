# Private Direct Messages (NIP-17)

This guide covers sending and receiving encrypted private messages using the NIP-17 protocol.

NIP-17 provides strong privacy through three layers of encryption:

- **Rumor**: Unsigned message (deniable)
- **Seal**: Encrypted rumor, signed by sender
- **Gift Wrap**: Encrypted seal, signed with ephemeral key

## Quick Start

Send a private message:

```elixir
sender_seckey = "your_64_char_hex_secret_key"
recipient_pubkey = "recipient_64_char_hex_pubkey"

{:ok, gift_wraps} = Nostr.NIP17.send_dm(
  sender_seckey,
  [recipient_pubkey],
  "Hello, this is a private message!"
)

# Publish each gift wrap to recipient's DM relays
```

Receive a private message:

```elixir
{:ok, message, sender_pubkey} = Nostr.NIP17.receive_dm(gift_wrap, recipient_seckey)
IO.puts(message.content)  # "Hello, this is a private message!"
```

## Sending Messages

### Basic Message

```elixir
{:ok, gift_wraps} = Nostr.NIP17.send_dm(
  sender_seckey,
  [recipient_pubkey],
  "Secret message content"
)
```

The function returns a list of gift wraps - one for each recipient plus one for the sender (for the sent folder).

### With Subject and Reply

```elixir
{:ok, gift_wraps} = Nostr.NIP17.send_dm(
  sender_seckey,
  [recipient_pubkey],
  "This is my reply",
  subject: "Important Discussion",
  reply_to: "parent_event_id"
)
```

### Group Message (Multiple Recipients)

```elixir
recipients = [pubkey1, pubkey2, pubkey3]

{:ok, gift_wraps} = Nostr.NIP17.send_dm(
  sender_seckey,
  recipients,
  "Hello everyone!"
)

# Returns 4 gift wraps: one for each recipient + one for sender
```

## Receiving Messages

### Basic Receive

```elixir
{:ok, message, sender_pubkey} = Nostr.NIP17.receive_dm(gift_wrap, recipient_seckey)

message.content     # The plain text message
message.subject     # Conversation title (if set)
message.reply_to    # Parent event ID (if replying)
message.receivers   # List of recipients
```

### From Raw Event

You can pass either a `GiftWrap` struct or a raw `Event`:

```elixir
# From parsed event
{:ok, message, sender} = Nostr.NIP17.receive_dm(gift_wrap_event, seckey)
```

### Receive Any Message Type

Use `receive_message/2` to handle both text (kind 14) and file (kind 15) messages:

```elixir
{:ok, message, sender} = Nostr.NIP17.receive_message(gift_wrap, seckey)

case message do
  %Nostr.Event.PrivateMessage{} ->
    IO.puts("Text: #{message.content}")
  %Nostr.Event.FileMessage{} ->
    IO.puts("File: #{message.file_url}")
end
```

## File Messages

Send encrypted files with metadata:

```elixir
file_metadata = %{
  file_type: "image/jpeg",
  encryption_algorithm: "aes-gcm",
  decryption_key: "symmetric_key_for_file",
  decryption_nonce: "nonce_for_decryption",
  hash: "sha256_of_encrypted_file",
  # Optional fields:
  original_hash: "sha256_of_original_file",
  size: 1024000,
  dimensions: %{width: 1920, height: 1080},
  blurhash: "LEHV6nWB2yk8pyo0adR*.7kCMdnj",
  thumbnail: "https://example.com/thumb.enc",
  fallbacks: ["https://backup.com/file.enc"]
}

{:ok, gift_wraps} = Nostr.NIP17.send_file(
  sender_seckey,
  [recipient_pubkey],
  "https://example.com/encrypted-file.enc",
  file_metadata
)
```

Receive file messages:

```elixir
{:ok, file_msg, sender} = Nostr.NIP17.receive_file(gift_wrap, seckey)

file_msg.file_url              # URL of encrypted file
file_msg.file_type             # MIME type
file_msg.decryption_key        # Key to decrypt file
file_msg.decryption_nonce      # Nonce for decryption
file_msg.hash                  # SHA-256 of encrypted file
```

## DM Relay List

Publish your preferred relays for receiving DMs:

```elixir
alias Nostr.Event.DMRelayList

relays = ["wss://inbox.nostr.wine", "wss://relay.damus.io"]
list = DMRelayList.create(relays, pubkey: my_pubkey)

# Sign and publish
signed = Nostr.Event.sign(list.event, seckey)
```

Query a user's DM relays before sending:

```elixir
# Subscribe to kind 10050 events from the recipient
filter = %Nostr.Filter{kinds: [10050], authors: [recipient_pubkey]}
```

## Low-Level API

For more control, use the underlying modules directly:

### Create a Private Message

```elixir
alias Nostr.Event.PrivateMessage

message = PrivateMessage.create(
  sender_pubkey,
  [recipient_pubkey],
  "Hello!",
  subject: "Greeting",
  reply_to: "parent_id"
)

# Access the underlying rumor
message.rumor.kind  # 14
message.rumor.id    # Event ID
```

### Manual Wrapping

```elixir
alias Nostr.Event.{Seal, GiftWrap}

# Create seal (encrypted rumor)
seal = Seal.create(message.rumor, sender_seckey, recipient_pubkey)

# Create gift wrap (encrypted seal with ephemeral key)
gift_wrap = GiftWrap.create(seal, recipient_pubkey)
```

### Manual Unwrapping

```elixir
# Unwrap gift wrap to get seal
{:ok, seal} = GiftWrap.unwrap(gift_wrap, recipient_seckey)

# Unwrap seal to get rumor
{:ok, rumor} = Seal.unwrap(seal, recipient_seckey)

# Parse rumor to message type
message = PrivateMessage.parse(rumor)
```

## Security Notes

- Messages are unsigned (rumors) providing deniability
- Timestamps are randomized within 2 days to prevent timing analysis
- Each gift wrap uses a unique ephemeral signing key
- Always verify sender: the library validates that the rumor's pubkey matches the seal's signer
- Gift wraps should be published to recipient's DM relays (kind 10050)

## Complete Conversation Example

```elixir
# Alice sends to Bob
{:ok, alice_wraps} = Nostr.NIP17.send_dm(alice_seckey, [bob_pubkey], "Hi Bob!")

# Bob receives
bob_wrap = Enum.find(alice_wraps, &(&1.recipient == bob_pubkey))
{:ok, msg, alice_pk} = Nostr.NIP17.receive_dm(bob_wrap, bob_seckey)

# Bob replies
{:ok, bob_wraps} = Nostr.NIP17.send_dm(
  bob_seckey,
  [alice_pubkey],
  "Hey Alice!",
  reply_to: msg.rumor.id
)

# Alice receives reply
alice_wrap = Enum.find(bob_wraps, &(&1.recipient == alice_pubkey))
{:ok, reply, bob_pk} = Nostr.NIP17.receive_dm(alice_wrap, alice_seckey)

# Alice can also read her sent message from her copy
sent_wrap = Enum.find(alice_wraps, &(&1.recipient == alice_pubkey))
{:ok, sent_msg, _} = Nostr.NIP17.receive_dm(sent_wrap, alice_seckey)
```

## Migration from NIP-04

NIP-17 replaces the deprecated NIP-04 direct messages (kind 4). Key differences:

| Feature          | NIP-04                  | NIP-17                    |
| ---------------- | ----------------------- | ------------------------- |
| Encryption       | AES-CBC                 | NIP-44 (ChaCha20)         |
| Metadata privacy | Sender/receiver visible | Hidden by gift wrap       |
| Deniability      | Signed (non-deniable)   | Unsigned rumor (deniable) |
| Group support    | No                      | Yes (multiple p tags)     |

To migrate, use `Nostr.NIP17.send_dm/4` instead of `Nostr.Event.DirectMessage.create/4`.
