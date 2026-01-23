defmodule Nostr.Event.Rumor do
  @moduledoc """
  Unsigned Nostr event (Rumor)

  A rumor is the same thing as an unsigned event. Any event kind can be made a rumor by removing
  the signature. This provides deniability - if a rumor is leaked, it cannot be verified.

  Defined in NIP 59
  https://github.com/nostr-protocol/nips/blob/master/59.md
  """
  @moduledoc tags: [:event, :nip59], nip: 59

  @enforce_keys [:kind, :tags, :created_at, :content]
  defstruct [:id, :pubkey, :kind, :tags, :created_at, :content]

  @typedoc "Unsigned Nostr event (rumor)"
  @type t() :: %__MODULE__{
          id: binary() | nil,
          pubkey: binary() | nil,
          kind: non_neg_integer(),
          tags: [Nostr.Tag.t()],
          created_at: DateTime.t(),
          content: binary()
        }

  @doc """
  Create a new rumor (unsigned event)

  Requires event kind and optionally any other event field:

    - `pubkey` - public key of the author (required for encryption)
    - `tags` - default is `[]` (needs to be list of `Nostr.Tag` structs)
    - `created_at` - default is `DateTime.utc_now/0`
    - `content` - default is `""`

  The ID is computed automatically.

  ## Example

      iex> rumor = Nostr.Event.Rumor.create(1, pubkey: "abc123", content: "Hello")
      iex> rumor.kind
      1
      iex> rumor.content
      "Hello"
  """
  @spec create(kind :: non_neg_integer(), opts :: Keyword.t()) :: t()
  def create(kind, opts \\ []) when is_integer(kind) do
    rumor = %__MODULE__{
      kind: kind,
      pubkey: Keyword.get(opts, :pubkey),
      tags: Keyword.get(opts, :tags, []),
      created_at: Keyword.get(opts, :created_at, DateTime.utc_now()),
      content: Keyword.get(opts, :content, "")
    }

    %__MODULE__{rumor | id: compute_id(rumor)}
  end

  @doc """
  Convert a signed event to a rumor by stripping the signature

  ## Example

      iex> event = %Nostr.Event{kind: 1, content: "test", tags: [], created_at: ~U[2023-01-01 00:00:00Z], pubkey: "abc", id: "123", sig: "xyz"}
      iex> rumor = Nostr.Event.Rumor.from_event(event)
      iex> rumor.kind
      1
      iex> rumor.id
      "123"
  """
  @spec from_event(Nostr.Event.t()) :: t()
  def from_event(%Nostr.Event{} = event) do
    %__MODULE__{
      id: event.id,
      pubkey: event.pubkey,
      kind: event.kind,
      tags: event.tags,
      created_at: event.created_at,
      content: event.content
    }
  end

  @doc """
  Parse a raw map into a rumor struct

  Unlike regular events, rumors have no signature to validate.
  """
  @spec parse(map()) :: t()
  def parse(data) when is_map(data) do
    rumor = %__MODULE__{
      id: Map.get(data, "id"),
      pubkey: Map.get(data, "pubkey"),
      kind: Map.get(data, "kind"),
      tags: parse_tags(Map.get(data, "tags", [])),
      created_at: parse_timestamp(Map.get(data, "created_at")),
      content: Map.get(data, "content", "")
    }

    # Validate/compute ID if pubkey is present
    if rumor.pubkey do
      computed_id = compute_id(rumor)

      if rumor.id && rumor.id != computed_id do
        {:error, :invalid_id, rumor}
      else
        %__MODULE__{rumor | id: computed_id}
      end
    else
      rumor
    end
  end

  @doc """
  Compute the event ID (SHA256 hash of serialized event)
  """
  @spec compute_id(t()) :: binary()
  def compute_id(%__MODULE__{} = rumor) do
    :sha256
    |> :crypto.hash(serialize(rumor))
    |> Base.encode16(case: :lower)
  end

  @doc """
  Serialize rumor for ID computation (NIP-01 format)
  """
  @spec serialize(t()) :: String.t()
  def serialize(%__MODULE__{
        pubkey: pubkey,
        kind: kind,
        tags: tags,
        created_at: created_at,
        content: content
      }) do
    JSON.encode!([0, pubkey, DateTime.to_unix(created_at), kind, tags, content])
  end

  defp parse_tags(tags) when is_list(tags) do
    Enum.map(tags, &Nostr.Tag.parse/1)
  end

  defp parse_tags(_invalid_tags), do: []

  defp parse_timestamp(ts) when is_integer(ts) do
    DateTime.from_unix!(ts)
  end

  defp parse_timestamp(%DateTime{} = dt), do: dt
  defp parse_timestamp(_invalid), do: DateTime.utc_now()
end

defimpl JSON.Encoder, for: Nostr.Event.Rumor do
  def encode(%Nostr.Event.Rumor{} = rumor, encoder) do
    :elixir_json.encode_map(
      %{
        id: rumor.id,
        pubkey: rumor.pubkey,
        kind: rumor.kind,
        tags: rumor.tags,
        created_at: DateTime.to_unix(rumor.created_at),
        content: rumor.content
      },
      encoder
    )
  end
end
