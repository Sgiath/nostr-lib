defmodule Nostr.Event do
  @moduledoc """
  Nostr Event
  """

  alias Nostr.Event.Parser
  alias Nostr.Event.Validator

  @enforce_keys [:id, :pubkey, :kind, :tags, :created_at, :content, :sig]
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
  @spec compute_id(event :: __MODULE__.t()) :: binary()
  def compute_id(%__MODULE__{} = event) do
    :sha256
    |> :crypto.hash(serialize(event))
    |> Base.encode16(case: :lower)
  end

  @doc """
  Serialize event from `Nostr.Event` struct
  """
  @spec serialize(event :: __MODULE__.t()) :: String.t()
  def serialize(%__MODULE__{
        pubkey: pubkey,
        kind: kind,
        tags: tags,
        created_at: created_at,
        content: content
      }) do
    Jason.encode!([0, pubkey, DateTime.to_unix(created_at), kind, tags, content])
  end
end

defimpl Jason.Encoder, for: Nostr.Event do
  def encode(%Nostr.Event{} = event, opts) do
    Jason.Encode.map(
      %{
        id: event.id,
        pubkey: event.pubkey,
        kind: event.kind,
        tags: event.tags,
        created_at: DateTime.to_unix(event.created_at),
        content: event.content,
        sig: event.sig
      },
      opts
    )
  end
end
