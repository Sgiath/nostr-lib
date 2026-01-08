# Nostr

[![Hex.pm](https://img.shields.io/hexpm/v/nostr_lib.svg)](https://hex.pm/packages/nostr_lib)
[![Hex Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/nostr_lib)
[![License](https://img.shields.io/hexpm/l/nostr_lib.svg)](https://github.com/sgiath/nostr-lib/blob/master/LICENSE)

A comprehensive low-level Elixir library implementing the [Nostr protocol](https://nostr.com/).
Provides structures, parsing, serialization, and cryptographic functions for building Nostr
applications.

## Features

- Full event lifecycle: creation, signing, validation, serialization
- Schnorr signature support (secp256k1)
- NIP-44 encryption (versioned encrypted payloads)
- NIP-19 bech32 encoding (npub, nsec, note, nprofile, nevent, naddr)
- NIP-59 gift wrap protocol for private messaging
- WebSocket message protocol handling
- Subscription filter building

## Installation

Add `nostr_lib` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nostr_lib, "~> 0.2.0"}
  ]
end
```

## Quick Start

### Create and Sign an Event

```elixir
# Generate or use existing private key (32 bytes hex)
private_key = "your_private_key_hex"

# Create a text note (kind 1)
{:ok, event} = Nostr.Event.Note.create("Hello Nostr!", private_key)

# Serialize for sending to relay
json = Nostr.Event.serialize(event)
```

### Parse Incoming Events

```elixir
# Parse JSON from relay
{:ok, event} = Nostr.Event.parse(json_string)

# Validate event signature
case Nostr.Event.Validator.validate(event) do
  {:ok, event} -> # Valid event
  {:error, reason, event} -> # Invalid
end
```

### Build Subscription Filters

```elixir
# Create a filter for text notes from specific authors
filter = %Nostr.Filter{
  kinds: [1],
  authors: ["pubkey1", "pubkey2"],
  limit: 100
}
```

### Bech32 Encoding

```elixir
# Encode public key as npub
{:ok, npub} = Nostr.Bech32.encode(:npub, pubkey_hex)
# => "npub1..."

# Decode back
{:ok, {:npub, pubkey}} = Nostr.Bech32.decode(npub)
```

## Implemented NIPs

| NIP | Status | Description | Event Kinds |
|-----|--------|-------------|-------------|
| [NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md) | Full | Basic protocol | 0, 1 |
| [NIP-02](https://github.com/nostr-protocol/nips/blob/master/02.md) | Full | Follow list | 3 |
| [NIP-04](https://github.com/nostr-protocol/nips/blob/master/04.md) | Deprecated | Encrypted DMs (use NIP-17) | 4 |
| [NIP-09](https://github.com/nostr-protocol/nips/blob/master/09.md) | Full | Event deletion | 5 |
| [NIP-16](https://github.com/nostr-protocol/nips/blob/master/16.md) | Full | Event kind ranges | 1000-39999 |
| [NIP-17](https://github.com/nostr-protocol/nips/blob/master/17.md) | Full | Private direct messages | 14, 15, 10050 |
| [NIP-18](https://github.com/nostr-protocol/nips/blob/master/18.md) | Deprecated | Reposts | 6 |
| [NIP-19](https://github.com/nostr-protocol/nips/blob/master/19.md) | Full | Bech32 encoding | - |
| [NIP-21](https://github.com/nostr-protocol/nips/blob/master/21.md) | Full | nostr: URI scheme | - |
| [NIP-25](https://github.com/nostr-protocol/nips/blob/master/25.md) | Full | Reactions | 7 |
| [NIP-28](https://github.com/nostr-protocol/nips/blob/master/28.md) | Full | Public chat channels | 40-44 |
| [NIP-42](https://github.com/nostr-protocol/nips/blob/master/42.md) | Full | Relay authentication | 22242 |
| [NIP-44](https://github.com/nostr-protocol/nips/blob/master/44.md) | Full | Versioned encryption | - |
| [NIP-45](https://github.com/nostr-protocol/nips/blob/master/45.md) | Partial | Event counting | - |
| [NIP-51](https://github.com/nostr-protocol/nips/blob/master/51.md) | Full | Lists | 10001-10030, 30000-30030 |
| [NIP-56](https://github.com/nostr-protocol/nips/blob/master/56.md) | Full | Reporting | 1984 |
| [NIP-57](https://github.com/nostr-protocol/nips/blob/master/57.md) | Full | Lightning zaps | 9734, 9735 |
| [NIP-58](https://github.com/nostr-protocol/nips/blob/master/58.md) | Full | Badges | 8 |
| [NIP-59](https://github.com/nostr-protocol/nips/blob/master/59.md) | Full | Gift wrap | 13, 1059 |
| [NIP-65](https://github.com/nostr-protocol/nips/blob/master/65.md) | Full | Relay list metadata | 10002 |
| [NIP-94](https://github.com/nostr-protocol/nips/blob/master/94.md) | Full | File metadata | 1063 |

## Core Modules

| Module | Description |
|--------|-------------|
| `Nostr.Event` | Core event struct with create, parse, serialize, sign, validate |
| `Nostr.Crypto` | Cryptographic operations (keys, signing, encryption) |
| `Nostr.Message` | WebSocket protocol messages (EVENT, REQ, CLOSE, etc.) |
| `Nostr.Filter` | Subscription filter building |
| `Nostr.Bech32` | NIP-19 bech32 encoding/decoding |
| `Nostr.NIP44` | Versioned encrypted payloads |
| `Nostr.NIP17` | Private message convenience functions |

## Event Types

Each event kind has a dedicated module in `Nostr.Event.*`:

| Kind | Module | Description |
|------|--------|-------------|
| 0 | `Metadata` | User profile metadata |
| 1 | `Note` | Text notes/posts |
| 3 | `Contacts` | Follow list |
| 4 | `DirectMessage` | Encrypted DMs (deprecated) |
| 5 | `Deletion` | Event deletion requests |
| 6 | `Repost` | Reposts (deprecated) |
| 7 | `Reaction` | Reactions to events |
| 8 | `BadgeAward` | Badge awards |
| 13 | `Seal` | Sealed/encrypted events |
| 14 | `PrivateMessage` | Private chat messages |
| 15 | `FileMessage` | Encrypted file messages |
| 40-44 | `Channel*` | Public chat channels |
| 1059 | `GiftWrap` | Gift wrapped events |
| 1063 | `FileMetadata` | File metadata |
| 1984 | `Report` | Content reports |
| 9734 | `ZapRequest` | Lightning zap requests |
| 9735 | `ZapReceipt` | Lightning zap receipts |
| 10002 | `RelayList` | Relay list metadata |
| 10050 | `DMRelayList` | DM relay preferences |
| 22242 | `ClientAuth` | Client authentication |

## Related Packages

This library is part of a larger Nostr ecosystem for Elixir:

- **nostr_lib** (this package) - Low-level protocol implementation
- **nostr_client** - WebSocket client for connecting to relays
- **nostr_server** - WebSocket server for building relays
- **nostr_relay** - Full relay implementation

## Documentation

Full documentation is available on [HexDocs](https://hexdocs.pm/nostr_lib).

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.
