defmodule Nostr.Tag do
  @moduledoc """
  Nostr Event tag
  """

  @enforce_keys [:type, :data]
  defstruct type: nil, data: nil, info: []

  @type t() :: %__MODULE__{
          type: atom(),
          data: binary(),
          info: [binary()]
        }

  @doc """
  Parse JSON list into Elixir struct
  """
  @spec parse(tag :: nonempty_maybe_improper_list()) :: t()
  def parse([type, data | info]) do
    %__MODULE__{
      type: String.to_atom(type),
      data: data,
      info: info
    }
  end

  @doc """
  Create new Nostr tag

  Each tag needs to have type and at least one data field. If tag requires more then one data
  field supply them as third argument (list of strings)

  ## Example:

      iex> Nostr.Tag.create(:e, "event-id", ["wss://relay.example.com"])
      %Nostr.Tag{type: :e, data: "event-id", info: ["wss://relay.example.com"]}

      iex> Nostr.Tag.create(:p, "pubkey")
      %Nostr.Tag{type: :p, data: "pubkey", info: []}

  """
  @spec create(type :: atom() | binary(), data :: binary(), other_data :: [binary()]) :: t()
  def create(type, data, other_data \\ [])

  def create(type, data, other_data) when is_binary(type),
    do: create(String.to_atom(type), data, other_data)

  def create(type, data, other_data) when is_atom(type) do
    %__MODULE__{
      type: type,
      data: data,
      info: other_data
    }
  end
end

defimpl JSON.Encoder, for: Nostr.Tag do
  def encode(%Nostr.Tag{} = tag, encoder) do
    :elixir_json.encode_list([Atom.to_string(tag.type), tag.data | tag.info], encoder)
  end
end
