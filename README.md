# Nostr

General Nostr library implementing Elixir structures for Nostr protocol. This is fairly low-level
implementation just parsing, serializing, encrypting, decrypting, etc. If you want more
functionality you can check out `nostr_client` or `nostr_server` libraries implementing WebSocket
client or server (without any other functionality) which you use to build your Nostr project.

If you are looking for fully implemented relay you can check `nostr_relay` package if you want to
check fully featured Nostr client you can check out Nostr Private server project which you can
deploy as your own private caching client running on server.

## Installation

```elixir
def deps do
  [
    {:nostr_lib, "~> 0.1.0"},
  ]
end
```
