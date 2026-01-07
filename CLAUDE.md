# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
mix deps.get          # Install dependencies
mix compile           # Compile the project
mix test              # Run all tests
mix test path/to/test.exs              # Run specific test file
mix test path/to/test.exs:42           # Run test at specific line
mix test.watch        # Watch mode for tests
mix precommit         # Full validation: compile --warnings-as-errors, deps.unlock --unused, format, test
mix format            # Format code
mix credo             # Run linter (strict mode, 98 char line limit)
mix docs              # Generate documentation
```

## Specification Reference

The `nips/` directory contains the official Nostr Implementation Proposals (NIPs) as a git submodule. These markdown files are the authoritative specification this library implements. When implementing or modifying features, always consult the relevant NIP file:

- `nips/01.md` - Basic protocol: events, signatures, tags, filters, relay messages
- `nips/02.md` - Follow list (kind 3)
- `nips/04.md` - Encrypted direct messages (kind 4)
- `nips/09.md` - Event deletion (kind 5)
- `nips/19.md` - Bech32 encoding (npub, nsec, note, nprofile, nevent, naddr)
- `nips/25.md` - Reactions (kind 7)
- `nips/28.md` - Public chat channels (kinds 40-44)
- `nips/42.md` - Authentication (kind 22242)

Use `nips/README.md` for the full index of all NIPs and their status.

## Architecture

This is a low-level Elixir library implementing the Nostr protocol specification. It provides structures, parsing, serialization, and cryptographic functions for Nostr.

### Core Modules

- **Nostr.Event** - Core event struct with `create/2`, `parse/1`, `serialize/1`, `sign/2`, `compute_id/1`
- **Nostr.Crypto** - Cryptographic operations: `pubkey/1`, `sign/2`, `encrypt/3`, `decrypt/3`
- **Nostr.Message** - WebSocket protocol message handling (EVENT, REQ, CLOSE, etc.)
- **Nostr.Filter** - Subscription filter struct for queries
- **Nostr.Tag** - Event tag structure (type, data, info)
- **Nostr.Bech32** - NIP-19 bech32 encoding (npub, nsec, note, nprofile, etc.)
- **Nostr.TLV** - ASN.1 BER-TLV encoding/decoding

### Event Types (lib/nostr/event/)

Each event kind has its own module implementing `parse/1` and `create/n`:
- Kind 0: Metadata (NIP-01)
- Kind 1: Note (NIP-01)
- Kind 3: Contacts (NIP-02)
- Kind 4: DirectMessage (NIP-04)
- Kind 5: Deletion (NIP-09)
- Kind 6: Repost (NIP-18)
- Kind 7: Reaction (NIP-25)
- Kinds 40-44: Channel operations (NIP-28)
- Kind 22242: ClientAuth (NIP-42)

The `Nostr.Event.Parser` module routes generic events to specific types by kind number.
The `Nostr.Event.Validator` module verifies event ID (SHA256) and signature (Schnorr).

### Key Dependencies

- `lib_secp256k1` - Elliptic curve cryptography (signing, key derivation)
- `bechamel` - Bech32 encoding

### JSON Handling

Uses Elixir 1.18+ built-in `JSON` module (not Jason). Custom `JSON.Encoder` protocol implementations handle struct serialization.

## Code Conventions

- Modules document NIP references in `@moduledoc` with tags like `@moduledoc tags: [:event, :nip01], nip: 1`
- Heavy use of `@type` and `@typedoc` for type specifications
- Message types annotated with `@doc sender: :client` or `@doc sender: :relay`
- Error handling returns tuples like `{:error, reason, event}`
