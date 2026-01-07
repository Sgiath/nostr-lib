defmodule Nostr.Filter do
  @moduledoc """
  Nostr filter
  """

  defstruct [:ids, :authors, :kinds, :"#e", :"#p", :"#a", :"#d", :since, :until, :limit, :search, :tags]

  @type t() :: %__MODULE__{
          ids: nil | [<<_::32, _::_*8>>],
          authors: nil | [<<_::32, _::_*8>>],
          kinds: nil | [non_neg_integer()],
          "#e": nil | [<<_::32, _::_*8>>],
          "#p": nil | [<<_::32, _::_*8>>],
          # award definition link
          "#a": nil | [<<_::32, _::_*8>>],
          # badge name
          "#d": nil | [binary()],
          since: nil | DateTime.t(),
          until: nil | DateTime.t(),
          limit: nil | non_neg_integer(),
          search: nil | String.t(),
          # Arbitrary single-letter tag filters (NIP-01)
          tags: nil | %{String.t() => [binary()]}
        }

  # Known keys that map to struct fields
  @known_keys %{
    "ids" => :ids,
    "authors" => :authors,
    "kinds" => :kinds,
    "#e" => :"#e",
    "#p" => :"#p",
    "#a" => :"#a",
    "#d" => :"#d",
    "since" => :since,
    "until" => :until,
    "limit" => :limit,
    "search" => :search
  }

  # Single-letter tag pattern (NIP-01: #<single-letter (a-zA-Z)>)
  @tag_pattern ~r/^#[a-zA-Z]$/

  @doc """
  Parse filter from raw list to `Nostr.Filter` struct
  """
  @spec parse(map) :: __MODULE__.t()
  def parse(filter) when is_map(filter) do
    {known, extra_tags} =
      Enum.reduce(filter, {%{}, %{}}, fn {key, value}, {known_acc, tags_acc} ->
        str_key = if is_atom(key), do: Atom.to_string(key), else: key

        cond do
          # Known field
          Map.has_key?(@known_keys, str_key) ->
            atom_key = Map.get(@known_keys, str_key)
            {Map.put(known_acc, atom_key, value), tags_acc}

          # Arbitrary single-letter tag filter (NIP-01)
          is_binary(str_key) and Regex.match?(@tag_pattern, str_key) ->
            {known_acc, Map.put(tags_acc, str_key, value)}

          # Unknown key, ignore
          true ->
            {known_acc, tags_acc}
        end
      end)

    # Add extra tags to known fields if any exist
    known = if map_size(extra_tags) > 0, do: Map.put(known, :tags, extra_tags), else: known

    known =
      if Map.has_key?(known, :since) and known.since != nil do
        Map.update!(known, :since, &DateTime.from_unix!/1)
      else
        known
      end

    known =
      if Map.has_key?(known, :until) and known.until != nil do
        Map.update!(known, :until, &DateTime.from_unix!/1)
      else
        known
      end

    struct(__MODULE__, known)
  end
end

defimpl JSON.Encoder, for: Nostr.Filter do
  def encode(%Nostr.Filter{} = filter, encoder) do
    # Extract extra tags before converting
    extra_tags = filter.tags || %{}

    filter
    |> Map.update!(:since, &encode_unix/1)
    |> Map.update!(:until, &encode_unix/1)
    |> Map.from_struct()
    |> Map.delete(:tags)
    |> Enum.reject(fn {_key, val} -> is_nil(val) end)
    |> Enum.into(%{})
    |> Map.merge(extra_tags)
    |> :elixir_json.encode_map(encoder)
  end

  defp encode_unix(nil), do: nil
  defp encode_unix(date_time), do: DateTime.to_unix(date_time)
end
