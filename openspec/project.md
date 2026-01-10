# Project Context

## Purpose

**nostr_lib** is a low-level Elixir library implementing the Nostr protocol specification. It provides:

- Data structures for Nostr events, messages, filters, and tags
- Parsing and serialization (JSON) for all protocol entities
- Cryptographic operations (Schnorr signatures, NIP-44 encryption, key derivation)
- Bech32 encoding/decoding for Nostr identifiers (npub, nsec, note, nprofile, etc.)
- WebSocket protocol message handling (EVENT, REQ, CLOSE, AUTH, etc.)

The library is designed to be a foundation for building Nostr clients, relays, and tools in Elixir.

## Tech Stack

- **Elixir 1.18+** - Uses built-in `JSON` module (not Jason)
- **lib_secp256k1** - Elliptic curve cryptography (Schnorr signing, key derivation)
- **bechamel** - Bech32 encoding for NIP-19
- **scrypt** - Password-based key derivation for NIP-49
- **req** (optional) - HTTP client for NIP-05 verification

### Development Tools
- **Credo** - Static code analysis (strict mode)
- **ExDoc** - Documentation generation
- **mix_test_watch** - Test watcher for TDD

## Project Conventions

### Code Style

- **Line length**: 98 characters max (enforced by Credo)
- **Formatting**: Standard `mix format` with default settings
- **Aliases**: Required when nested deeper than 2 levels or called more than once
- **Alias ordering**: Alphabetical (enforced by Credo)
- **No parentheses** on zero-arity function definitions
- **Prefer implicit try** over explicit try blocks
- **Pipe into anonymous functions** allowed

### Module Documentation

- NIP references in `@moduledoc` using tags: `@moduledoc tags: [:event, :nip01], nip: 1`
- Heavy use of `@type` and `@typedoc` for type specifications
- Message direction documented with `@doc sender: :client` or `@doc sender: :relay`

### Architecture Patterns

**Event Type Modules** (`lib/nostr/event/`):
- Each event kind has its own module (e.g., `Nostr.Event.Note`, `Nostr.Event.Metadata`)
- All event modules implement `parse/1` and `create/n` functions
- `Nostr.Event.Parser` routes generic events to specific types by kind number
- `Nostr.Event.Validator` verifies event ID (SHA256) and signature (Schnorr)

**Error Handling**:
- Return tuples: `{:ok, result}` or `{:error, reason}` or `{:error, reason, context}`
- Parse functions return `nil` for invalid/unverified events

**JSON Serialization**:
- Custom `JSON.Encoder` protocol implementations for all structs
- Events serialize to JSON array format per NIP-01

### Testing Strategy

- **ExUnit** with `async: true` for concurrent test execution
- **Fixtures** in `test/support/` for reusable test data
- **Doctests** enabled for modules with usage examples
- **Test organization**: `describe` blocks group related tests
- Tests named by behavior: "creates event with custom content", "returns nil for invalid signature"

Run tests:
```bash
mix test              # All tests
mix test path:line    # Specific test
mix test.watch        # Watch mode
mix precommit         # Full validation suite
```

### Git Workflow

- **Main branch**: `master`
- **Issue tracking**: bd (beads) - git-backed issue tracking
- **Pre-commit**: Run `mix precommit` before committing (compile warnings as errors, format, test)

## Domain Context

### Nostr Protocol

Nostr is a decentralized social network protocol. Key concepts:

- **Events**: All data is represented as cryptographically signed JSON events
- **Relays**: Servers that store and forward events
- **Clients**: Applications that create events and query relays
- **NIPs**: Nostr Implementation Proposals - the specification documents

### Event Structure (NIP-01)

```json
{
  "id": "<sha256 hex>",
  "pubkey": "<32-byte hex public key>",
  "created_at": <unix timestamp>,
  "kind": <integer>,
  "tags": [["tag", "value", ...]],
  "content": "<string>",
  "sig": "<schnorr signature hex>"
}
```

### Key Concepts

- **Kind numbers**: Define event type (0=metadata, 1=note, 3=contacts, etc.)
- **Tags**: Metadata attached to events (e/p/t tags for references)
- **Filters**: Query parameters for requesting events from relays
- **Bech32**: Human-readable encoding (npub, nsec, note, nprofile, nevent, naddr)

### Specification Reference

The `nips/` directory contains official NIPs as a git submodule. Always consult the relevant NIP when implementing features.

## Important Constraints

- **NIP Compliance**: All implementations must follow the official NIP specifications exactly
- **Cryptographic Correctness**: Event ID (SHA256) and signatures (Schnorr/secp256k1) must be verifiable
- **JSON Compatibility**: Must produce JSON compatible with other Nostr implementations
- **No Runtime Dependencies**: Minimize runtime dependencies for library consumers
- **Elixir 1.18+**: Uses built-in JSON module, not backwards compatible with older Elixir

## External Dependencies

### Cryptography
- **secp256k1**: Elliptic curve for all Nostr signatures and key derivation
- **SHA256**: Event ID computation
- **ChaCha20-Poly1305**: NIP-44 encryption for direct messages

### Protocols
- **WebSocket**: Relay communication (not implemented in this library - consumers provide)
- **HTTP**: NIP-05 verification (optional, requires `req` dependency)

### Specifications
- **nips/** submodule: Authoritative protocol specifications
