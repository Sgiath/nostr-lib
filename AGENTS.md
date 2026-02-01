# Instructions for LLMs

**Generated:** 2026-02-01 | **Commit:** 91e4b11 | **Branch:** master

## Overview

Low-level Elixir library implementing the Nostr protocol. Provides structs, parsing, serialization, and cryptographic functions. Pure library (no OTP application).

## Structure

```
lib/nostr/
├── event.ex           # Core Event struct + sign/parse/serialize
├── event/             # 67 event type modules (see lib/nostr/event/AGENTS.md)
├── crypto.ex          # Schnorr signing, ECDH, AES-256-CBC
├── message.ex         # WebSocket protocol (EVENT, REQ, CLOSE, etc.)
├── filter.ex          # Subscription filters
├── tag.ex             # Event tags
├── bech32.ex          # Simple bech32 (npub, nsec, note)
├── nip*.ex            # NIP-specific utilities (05, 17, 19, 21, 30, 36, 39, 44, 49, 51, 57)
├── tlv.ex             # ASN.1 BER-TLV encoding
└── bolt11.ex          # Lightning invoice parsing
test/
├── support/fixtures.ex  # Test keypairs + event builders
└── nostr/               # Mirrors lib/ structure
nips/                    # Git submodule: official NIP specs (authoritative reference)
```

## Where to Look

| Task                   | Location                         | Notes                                        |
| ---------------------- | -------------------------------- | -------------------------------------------- |
| Add new event kind     | `lib/nostr/event/` + `parser.ex` | Create module, register in Parser            |
| Modify encryption      | `lib/nostr/nip44.ex`             | NIP-44 modern, `crypto.ex` for legacy NIP-04 |
| Change bech32 encoding | `lib/nostr/nip19.ex`             | Uses `nip19/tlv.ex` for metadata             |
| WebSocket messages     | `lib/nostr/message.ex`           | Tuple-based API                              |
| Test fixtures          | `test/support/fixtures.ex`       | `signed_event/1`, `raw_event_map/1`          |
| NIP specification      | `nips/{number}.md`               | Authoritative source                         |

## Commands

```bash
mix test                          # Run all tests
mix test path/to/test.exs         # Run specific file
mix test path/to/test.exs:42      # Run test at line
mix precommit                     # compile --warnings-as-errors + deps.unlock --unused + format + test
mix test --exclude nip05_http     # Skip HTTP-dependent tests
mix test --exclude ecdh           # Skip ECDH tests
```

## Conventions

### Module Documentation

- `@moduledoc tags: [:event, :nip01], nip: 1` for NIP references
- `@doc sender: :client` or `@doc sender: :relay` for message direction

### JSON Handling

- Uses **Elixir 1.18+ built-in `JSON` module** (not Jason)
- Custom `JSON.Encoder` protocol implementations in: `Event`, `Tag`, `Filter`, `Rumor`

### Error Handling

- Returns tuples: `{:ok, result}` or `{:error, reason}` or `{:error, reason, event}`
- Validation failures return `nil` from `parse/1`

### Event Module Pattern

Each event type in `lib/nostr/event/` implements:

- `parse/1` — Convert generic `Nostr.Event` to typed struct
- `create/n` — Build event with domain-specific options
- `@type t()` — Type specification for the struct

### Test Conventions

- `use ExUnit.Case, async: true` (all tests async)
- `doctest ModuleName` for documentation examples
- Use `Nostr.Test.Fixtures.*` for test data (never hardcode keys)
- Tag external deps: `@tag :nip05_http`, `@tag :ecdh`

## Anti-Patterns

### Do Not

- Use test keypairs in production (`1111...` from fixtures)
- Use `Nostr.Event.DirectMessage` (NIP-04 deprecated → use NIP-17)
- Use `Nostr.Event.Repost` (NIP-18 deprecated → use NIP-27)
- Use `Nostr.Event.Report` in application logic (Apple Store compliance only)
- Suppress warnings with `# credo:disable-for-this-file`

### Deprecated Event Types

| Kind | Module           | Use Instead                             |
| ---- | ---------------- | --------------------------------------- |
| 4    | `DirectMessage`  | NIP-17: `PrivateMessage`, `Nostr.NIP17` |
| 6    | `Repost`         | NIP-27: text note references            |
| 2    | `RecommendRelay` | NIP-65: `RelayList`                     |

## Key Dependencies

| Package         | Purpose                            |
| --------------- | ---------------------------------- |
| `lib_secp256k1` | Schnorr signatures, ECDH           |
| `bechamel`      | Bech32 encoding                    |
| `scrypt`        | NIP-49 key derivation              |
| `req`           | Optional: NIP-05 HTTP verification |

## NIP Implementation Status

### Fully Implemented (33 NIPs)

Core: 01, 02, 03, 09, 16 | Messaging: 04 (deprecated), 17, 44, 59 | Encoding: 05, 19, 21 | Content: 18 (deprecated), 22, 23, 25 | Channels: 28, 32, 42 | Lists: 37, 38, 51, 52, 65 | Zaps: 57, 58 | Tags: 30, 36, 39 | Keys: 49 | Files: 94

### Partial

- NIP-45: Event counting (messages only, no relay logic)

## Architecture Notes

### Event Lifecycle

```
create(kind, opts) → Event struct (unsigned)
    ↓
sign(event, seckey) → Event (with id, pubkey, sig)
    ↓
serialize(event) → JSON string
```

### Parsing Flow

```
JSON string → Event.parse(map) → generic Nostr.Event
                    ↓
           Parser.parse_specific(event) → typed struct (Note, Metadata, etc.)
```

### Encryption Hierarchy

```
NIP-17 (private messages)
  └─ NIP-44 (modern encryption: ChaCha20 + HMAC)
       └─ Nostr.Crypto.shared_secret (ECDH)

NIP-51 (encrypted lists)
  ├─ NIP-44 (preferred)
  └─ NIP-04 (legacy fallback, auto-detected by ?iv= suffix)

NIP-49 (key encryption)
  └─ Scrypt + XChaCha20-Poly1305 (standalone)
```

## Gotchas

- **Elixir 1.18+ required** — Uses built-in `JSON` module
- **Protocol consolidation disabled in test** — Faster test cycles
- **Line limit: 98 chars** — Enforced by Credo
- **No top-level Nostr module** — Call `Nostr.Event.*`, `Nostr.Crypto.*` directly
- **Timestamps are DateTime** — Not Unix integers; use `DateTime.to_unix/1` for wire format
