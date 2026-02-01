# Event Types (lib/nostr/event/)

67 modules implementing Nostr event kinds. Each wraps `Nostr.Event` with domain-specific parsing and creation.

## Structure

| File             | Purpose                                      |
| ---------------- | -------------------------------------------- |
| `parser.ex`      | Routes kinds to modules (`parse_specific/1`) |
| `validator.ex`   | Verifies ID (SHA256) and signature (Schnorr) |
| `rumor.ex`       | Unsigned event wrapper (NIP-59)              |
| `{kind_name}.ex` | Type-specific struct + parse/create          |

## Adding New Event Kind

1. Create `lib/nostr/event/your_event.ex`:

```elixir
defmodule Nostr.Event.YourEvent do
  @moduledoc """
  Your event description (Kind NNNN)
  """
  @moduledoc tags: [:event, :nipXX], nip: XX

  defstruct [:event, :your_field, ...]

  @type t() :: %__MODULE__{
    event: Nostr.Event.t(),
    your_field: binary()
  }

  @spec parse(Nostr.Event.t()) :: t()
  def parse(%Nostr.Event{kind: NNNN} = event) do
    %__MODULE__{
      event: event,
      your_field: extract_from_tags(event.tags)
    }
  end

  @spec create(binary(), Keyword.t()) :: t()
  def create(your_field, opts \\ []) do
    tags = build_tags(your_field)
    opts = Keyword.merge(opts, tags: tags, content: "")

    NNNN
    |> Nostr.Event.create(opts)
    |> parse()
  end

  # Private helpers...
end
```

2. Register in `parser.ex`:

```elixir
def parse_specific(%Event{kind: NNNN} = event), do: Event.YourEvent.parse(event)
```

3. Create test `test/nostr/event/your_event_test.exs`

## Module Patterns

### Parse-Only (19%)

Kind range wrappers, no create function:

- `regular.ex` — Kinds 1000-9999
- `ephemeral.ex` — Kinds 20000-29999
- `replaceable.ex` — Kinds 10000-19999
- `parameterized_replaceable.ex` — Kinds 30000-39999
- `unknown.ex` — Fallback

### Simple (39%)

Single parse + create, straightforward tag extraction:

- `contacts.ex` — Kind 3 (follow list)
- `deletion.ex` — Kind 5
- `relay_list.ex` — Kind 10002

### Complex (40%)

Multiple create variants, validation, cross-NIP integration:

- `note.ex` — Kind 1 (NIP-01, 10, 14, 30, 36)
- `metadata.ex` — Kind 0 (JSON content, NIP-24, 30, 39)
- `article.ex` — Kinds 30023/30024 (NIP-23)
- `zap_request.ex` — Kind 9734 (validation-heavy)

## Common Helpers

### Tag Extraction (copy pattern)

```elixir
defp get_e_tags(tags) do
  tags |> Enum.filter(&(&1.type == :e)) |> Enum.map(& &1.data)
end

defp find_tag(tags, type) do
  Enum.find(tags, &(&1.type == type))
end
```

### Tag Building (copy pattern)

```elixir
defp build_e_tag(event_id, relay \\ nil, pubkey \\ nil) do
  info = case {relay, pubkey} do
    {nil, nil} -> []
    {r, nil} -> [r]
    {nil, p} -> ["", p]
    {r, p} -> [r, p]
  end
  Nostr.Tag.create(:e, event_id, info)
end
```

### JSON Content (for metadata-like events)

```elixir
case JSON.decode(event.content) do
  {:ok, content} -> extract_fields(content)
  {:error, _} -> {:error, "Cannot decode content", event}
end
```

## Delegation Patterns

| Concern             | Delegate To   | Used By                              |
| ------------------- | ------------- | ------------------------------------ |
| List encryption     | `Nostr.NIP51` | Bookmarks, RelayList, ListMute, etc. |
| Custom emoji        | `Nostr.NIP30` | Note, Metadata, Reaction             |
| Content warnings    | `Nostr.NIP36` | Note, Article                        |
| External identities | `Nostr.NIP39` | Metadata                             |
| Zap utilities       | `Nostr.NIP57` | ZapRequest, ZapReceipt               |

## Special Cases

### Encrypted Events

`DirectMessage`, `PrivateMessage`, `GiftWrap`, `Seal`:

- Include `decrypt/2` function
- Use `Nostr.Crypto` or `Nostr.NIP44`

### Deprecated Events

`DirectMessage` (Kind 4), `Repost` (Kind 6), `RecommendRelay` (Kind 2):

- Log `Logger.warning()` on parse/create
- Kept for backward compatibility

### Multi-Kind Events

`Article` (30023, 30024), `CurationSets` (30004-30006):

- Guard allows multiple kinds in pattern match

### Validation Events

`ZapRequest`, `Reaction`, `ClientAuth`:

- Return `{:error, reason, event}` for invalid input
- Validate tag requirements before building struct

## Kind Reference

| Kind        | Module         | NIP             |
| ----------- | -------------- | --------------- |
| 0           | Metadata       | 01              |
| 1           | Note           | 01, 10, 14      |
| 3           | Contacts       | 02              |
| 4           | DirectMessage  | 04 (deprecated) |
| 5           | Deletion       | 09              |
| 7           | Reaction       | 25              |
| 13          | Seal           | 59              |
| 14          | PrivateMessage | 17              |
| 40-44       | Channel\*      | 28              |
| 1059        | GiftWrap       | 59              |
| 1111        | Comment        | 22              |
| 9734-9735   | Zap\*          | 57              |
| 10000-10102 | Lists          | 51              |
| 22242       | ClientAuth     | 42              |
| 30000-39999 | Sets           | 51              |

Full routing: see `parser.ex` lines 112-206.
