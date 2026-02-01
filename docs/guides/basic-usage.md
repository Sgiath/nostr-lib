# Basic Usage

This guide covers the fundamental operations you'll need when working with Nostr events.

## Key Generation

Generate a public key from a secret key:

```elixir
seckey = "1111111111111111111111111111111111111111111111111111111111111111"
pubkey = Nostr.Crypto.pubkey(seckey)
# => "4f355bdcb7cc0af728ef3cceb9615d90684bb5b2ca5f859ab0f0b704075871aa"
```

## Bech32 Encoding

Convert between hex and bech32 formats (NIP-19):

```elixir
# Encode hex to bech32
{:ok, npub} = Nostr.Bech32.hex_to_npub(pubkey)
# => {:ok, "npub1fuaz67..."}

{:ok, nsec} = Nostr.Bech32.hex_to_nsec(seckey)
# => {:ok, "nsec1zyg3zy..."}

# Decode bech32 to hex
{:ok, hex} = Nostr.Bech32.npub_to_hex(npub)
```

## Creating Events

Create a basic text note (kind 1):

```elixir
event = Nostr.Event.create(1, content: "Hello Nostr!")
```

Create an event with tags:

```elixir
tags = [
  Nostr.Tag.create(:e, "referenced_event_id"),
  Nostr.Tag.create(:p, "mentioned_pubkey")
]

event = Nostr.Event.create(1, content: "Reply to someone", tags: tags)
```

## Signing Events

Sign an event with your secret key:

```elixir
seckey = "your_secret_key_hex"

signed_event =
  1
  |> Nostr.Event.create(content: "Hello Nostr!")
  |> Nostr.Event.sign(seckey)
```

The `sign/2` function automatically:

- Derives and sets the public key from the secret key
- Computes the event ID (SHA256 hash)
- Creates the Schnorr signature

## Parsing Events

Parse a raw event map (validates ID and signature):

```elixir
raw_event = %{
  "id" => "...",
  "pubkey" => "...",
  "kind" => 1,
  "tags" => [],
  "created_at" => 1686312479,
  "content" => "Hello",
  "sig" => "..."
}

# Returns nil if validation fails
event = Nostr.Event.parse(raw_event)
```

Parse to a specific event type struct:

```elixir
# Returns type-specific struct (e.g., Nostr.Event.Note, Nostr.Event.Metadata)
specific_event = Nostr.Event.parse_specific(raw_event)
```

## Working with Messages

Nostr messages are represented as tuples. Create messages for sending:

```elixir
# Client to relay: publish an event
msg = Nostr.Message.create_event(signed_event)
# => {:event, %Nostr.Event{...}}

# Client to relay: subscribe with a filter
filter = %Nostr.Filter{kinds: [1], limit: 10}
msg = Nostr.Message.request(filter, "subscription_id")
# => {:req, "subscription_id", %Nostr.Filter{...}}

# Client to relay: close subscription
msg = Nostr.Message.close("subscription_id")
# => {:close, "subscription_id"}
```

Serialize messages to JSON for the wire:

```elixir
json = Nostr.Message.serialize(msg)
# => "[\"EVENT\",{...}]"
```

Parse incoming messages from JSON:

```elixir
{:event, sub_id, event} = Nostr.Message.parse(json_string)

# Or parse with specific event types
{:event, sub_id, specific_event} = Nostr.Message.parse_specific(json_string)
```

## Filters

Create subscription filters:

```elixir
filter = %Nostr.Filter{
  kinds: [1],                    # Text notes
  authors: ["pubkey1", "pubkey2"],
  since: ~U[2024-01-01 00:00:00Z],
  limit: 100
}

# Tag filters use atom keys
filter = %Nostr.Filter{
  "#e": ["event_id"],            # Events referencing this event
  "#p": ["pubkey"]               # Events mentioning this pubkey
}
```

## Encryption (NIP-04)

Encrypt a direct message:

```elixir
encrypted = Nostr.Crypto.encrypt("Secret message", my_seckey, recipient_pubkey)
# => "base64_ciphertext?iv=base64_iv"
```

Decrypt a direct message:

```elixir
decrypted = Nostr.Crypto.decrypt(encrypted, my_seckey, sender_pubkey)
# => "Secret message"
```

## Complete Example

Here's a full workflow for creating and publishing a signed note:

```elixir
seckey = "your_64_char_hex_secret_key"

# Create, sign, and prepare for sending
message =
  1
  |> Nostr.Event.create(content: "My first Nostr post!")
  |> Nostr.Event.sign(seckey)
  |> Nostr.Message.create_event()

# Serialize to JSON for WebSocket transmission
json = Nostr.Message.serialize(message)
```

## Related Libraries

For WebSocket connectivity and full client/relay implementations, see:

- [nostr_client](https://hex.pm/packages/nostr_client) - WebSocket client
- [nostr_server](https://hex.pm/packages/nostr_server) - WebSocket server
- [nostr_relay](https://hex.pm/packages/nostr_relay) - Full relay implementation
