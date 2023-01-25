defmodule Nostr.Filter do
  @moduledoc """
  Nostr filter
  """

  defstruct [:ids, :authors, :kinds, :"#e", :"#p", :"#d", :since, :until, :limit]

  @type t() :: %__MODULE__{
          ids: nil | [<<_::32, _::_*8>>],
          authors: nil | [<<_::32, _::_*8>>],
          kinds: nil | [non_neg_integer()],
          "#e": nil | [<<_::32, _::_*8>>],
          "#p": nil | [<<_::32, _::_*8>>],
          "#d": nil | [binary()],
          since: nil | non_neg_integer(),
          until: nil | non_neg_integer(),
          limit: nil | non_neg_integer()
        }

  @doc """
  Parse filter from raw list to `Nostr.Tag` struct
  """
  @spec parse(map) :: __MODULE__.t()
  def parse(filter) when is_map(filter) do
    filter
    |> Map.take([:ids, :authors, :kinds, :"#e", :"#p", :"#d", :since, :until, :limit])
    |> Map.update(:since, nil, &DateTime.from_unix!/1)
    |> Map.update(:until, nil, &DateTime.from_unix!/1)
    |> Enum.into(%__MODULE__{})
  end
end

defimpl Jason.Encoder, for: Nostr.Filter do
  def encode(%Nostr.Filter{} = filter, opts) do
    filter
    |> Map.update!(:since, &encode_unix/1)
    |> Map.update!(:until, &encode_unix/1)
    |> Map.from_struct()
    |> Enum.reject(fn {_key, val} -> is_nil(val) end)
    |> Enum.into(%{})
    |> Jason.Encode.map(opts)
  end

  defp encode_unix(nil), do: nil
  defp encode_unix(date_time), do: DateTime.to_unix(date_time)
end
