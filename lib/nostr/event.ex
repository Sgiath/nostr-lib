defmodule Nostr.Event do
  @moduledoc """
  Nostr Event
  """

  alias Nostr.Event.Parser
  alias Nostr.Event.Validator

  @enforce_keys [:kind, :tags, :created_at, :content]
  defstruct id: nil, pubkey: nil, kind: nil, tags: [], created_at: nil, content: "", sig: nil

  @typedoc "Nostr event"
  @type t() :: %__MODULE__{
          id: <<_::32, _::_*8>>,
          pubkey: <<_::32, _::_*8>>,
          kind: non_neg_integer(),
          tags: [Nostr.Tag.t()],
          created_at: DateTime.t(),
          content: binary(),
          sig: <<_::64, _::_*8>>
        }

  @doc """
  Parse raw event map to `Nostr.Event` struct and validate ID and signature
  """
  @spec parse(event :: map()) :: nil | Nostr.Event.t()
  def parse(event) when is_map(event) do
    event = Parser.parse(event)

    if Validator.valid?(event), do: event
  end

  @doc """
  Parse raw event map to specific event struct (also validates ID and signature)
  """
  @spec parse_specific(event :: map()) :: struct()
  def parse_specific(event) when is_map(event) do
    event
    |> parse()
    |> Parser.parse_specific()
  end

  @doc """
  Compute event ID from `Nostr.Event` struct
  """
  @spec compute_id(event :: t()) :: binary()
  def compute_id(%__MODULE__{} = event) do
    :sha256
    |> :crypto.hash(serialize(event))
    |> Base.encode16(case: :lower)
  end

  @doc """
  Serialize event from `Nostr.Event` struct
  """
  @spec serialize(event :: t()) :: String.t()
  def serialize(%__MODULE__{
        pubkey: pubkey,
        kind: kind,
        tags: tags,
        created_at: created_at,
        content: content
      }) do
    JSON.encode!([0, pubkey, DateTime.to_unix(created_at), kind, tags, content])
  end

  @doc """
  Create new Nostr event struct

  Requires event kind and optionally any other event field:

    - `pubkey` - default is `nil` (derived later during event signing)
    - `tags` - default is `[]` (needs to be list of `Nostr.Tag` structs)
    - `created_at` - default is  `DateTime.utc_now/0`
    - `content` - default is `""`
    - `id` ignored (computed later during event signing)
    - `sig` ignored, if you want to signed event use `Nostr.Event.sign/2`

  ## Example

      iex> Nostr.Event.create(1, content: "My note", created_at: ~U[2023-06-09 11:07:59.031962Z])
      %Nostr.Event{
        kind: 1,
        pubkey: nil,
        tags: [],
        created_at: ~U[2023-06-09 11:07:59.031962Z],
        content: "My note"
      }

      iex> tags = [Nostr.Tag.create(:e, "event-id")]
      iex> Nostr.Event.create(1, created_at: ~U[2023-06-09 11:07:59.031962Z], tags: tags)
      %Nostr.Event{
        kind: 1,
        pubkey: nil,
        tags: [%Nostr.Tag{type: :e, data: "event-id", info: []}],
        created_at: ~U[2023-06-09 11:07:59.031962Z],
        content: ""
      }

  """
  def create(kind, opts \\ []) when is_integer(kind) do
    %__MODULE__{
      kind: kind,
      pubkey: Keyword.get(opts, :pubkey),
      tags: Keyword.get(opts, :tags, []),
      created_at: Keyword.get(opts, :created_at, DateTime.utc_now()),
      content: Keyword.get(opts, :content, "")
    }
  end

  @doc """
  Sign the event with seckey

  It auto-populates pubkey from seckey if event doesn't contain one or check it matches the seckey
  if there is an pubkey

  It auto-populates event ID or check the ID is correct before signing
  """
  def sign(%__MODULE__{pubkey: nil} = event, seckey) do
    sign(%__MODULE__{event | pubkey: Nostr.Crypto.pubkey(seckey)}, seckey)
  end

  def sign(%__MODULE__{id: nil} = event, seckey) do
    sign(%__MODULE__{event | id: compute_id(event)}, seckey)
  end

  def sign(%__MODULE__{id: id, pubkey: pubkey} = event, seckey) do
    unless id == compute_id(event) do
      raise "Event ID isn't correct"
    end

    unless pubkey == Nostr.Crypto.pubkey(seckey) do
      raise "Event pubkey doesn't match the seckey"
    end

    %__MODULE__{event | sig: Nostr.Crypto.sign(id, seckey)}
  end

  def sign(%{event: %__MODULE__{}} = event, seckey) do
    Map.update!(event, :event, &sign(&1, seckey))
  end
end

defimpl JSON.Encoder, for: Nostr.Event do
  def encode(%Nostr.Event{} = event, encoder) do
    :elixir_json.encode_map(
      %{
        id: event.id,
        pubkey: event.pubkey,
        kind: event.kind,
        tags: event.tags,
        created_at: DateTime.to_unix(event.created_at),
        content: event.content,
        sig: event.sig
      },
      encoder
    )
  end
end
