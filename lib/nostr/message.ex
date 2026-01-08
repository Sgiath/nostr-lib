defmodule Nostr.Message do
  @moduledoc """
  Nostr message is represented as tuple in Elixir. This module provides functions to generate
  messages, serialize or parse them.
  """

  require Logger

  @type t() ::
          {:event, Nostr.Event.t()}
          | {:event, binary(), Nostr.Event.t()}
          | {:req, binary(), [Nostr.Filter.t()]}
          | {:close, binary()}
          | {:eose, binary()}
          | {:notice, String.t()}
          | {:ok, binary(), boolean(), String.t()}
          | {:auth, Nostr.Event.t() | binary()}
          | {:count, String.t(), Nostr.Filter.t() | [Nostr.Filter.t()] | %{count: integer()}}
          | {:closed, String.t(), String.t()}

  @doc """
  Generate post new event message
  """
  @doc sender: :client
  @spec create_event(Nostr.Event.t() | %{event: Nostr.Event.t()}) :: {:event, Nostr.Event.t()}
  def create_event(%{event: %Nostr.Event{} = event}), do: {:event, event}
  def create_event(%Nostr.Event{} = event), do: {:event, event}

  @doc """
  Generate request message
  """
  @doc sender: :client
  @spec request(Nostr.Filter.t() | [Nostr.Filter.t()], binary()) ::
          {:req, binary(), [Nostr.Filter.t()]}
  def request(%Nostr.Filter{} = filter, sub_id), do: {:req, sub_id, [filter]}
  def request(filters, sub_id) when is_list(filters), do: {:req, sub_id, filters}

  @doc """
  Generate close message
  """
  @doc sender: :client
  @spec close(binary()) :: {:close, binary()}
  def close(sub_id), do: {:close, sub_id}

  @doc """
  Generate count message (NIP-45).

  Can be used to request counts from relay (with filters) or respond with counts (with integer).
  """
  @spec count(pos_integer() | Nostr.Filter.t() | [Nostr.Filter.t()], binary()) ::
          {:count, binary(), %{count: pos_integer()} | Nostr.Filter.t() | [Nostr.Filter.t()]}
  def count(count, sub_id) when is_integer(count), do: {:count, sub_id, %{count: count}}
  def count(%Nostr.Filter{} = filter, sub_id), do: {:count, sub_id, filter}
  def count(filters, sub_id) when is_list(filters), do: {:count, sub_id, filters}

  @doc """
  Generate event message
  """
  @doc sender: :relay
  @spec event(Nostr.Event.t() | %{event: Nostr.Event.t()}, binary()) ::
          {:event, binary(), Nostr.Event.t()}
  def event(%{event: %Nostr.Event{} = event}, sub_id), do: {:event, sub_id, event}
  def event(%Nostr.Event{} = event, sub_id), do: {:event, sub_id, event}

  @doc """
  Generate notice message
  """
  @doc sender: :relay
  @spec notice(String.t()) :: {:notice, String.t()}
  def notice(message), do: {:notice, message}

  @doc """
  Generate eose message
  """
  @doc sender: :relay
  @spec eose(binary()) :: {:eose, binary()}
  def eose(sub_id), do: {:eose, sub_id}

  @doc """
  Generate OK message
  """
  @doc sender: :relay
  @spec ok(binary(), boolean(), String.t()) :: {:ok, binary(), boolean(), String.t()}
  def ok(event_id, success?, message), do: {:ok, event_id, success?, message}

  @doc """
  Generate CLOSED message (NIP-01)
  """
  @doc sender: :relay
  @spec closed(String.t(), String.t()) :: {:closed, String.t(), String.t()}
  def closed(sub_id, message), do: {:closed, sub_id, message}

  @doc """
  Generate AUTH message (NIP-42).

  Can be used by relay (with challenge string) or by client (with signed event).
  """
  @spec auth(Nostr.Event.t() | %{event: Nostr.Event.t()} | binary()) ::
          {:auth, Nostr.Event.t() | binary()}
  def auth(%{event: %Nostr.Event{} = event}), do: {:auth, event}
  def auth(%Nostr.Event{} = event), do: {:auth, event}
  def auth(challenge), do: {:auth, challenge}

  @doc """
  Serialize Elixir tuple message to on-the-wire binary
  """
  @spec serialize(tuple()) :: binary()
  def serialize(message) when is_tuple(message) do
    message
    |> Tuple.to_list()
    |> List.flatten()
    |> then(fn [name | rest] -> [name |> Atom.to_string() |> String.upcase() | rest] end)
    |> JSON.encode!()
  end

  @doc """
  Parse binary message to Elixir tuple, if message contains event it will be returned as general
  `Nostr.Event.t()` struct
  """
  @spec parse(msg :: String.t()) :: t()
  def parse(msg) when is_binary(msg), do: msg |> JSON.decode!() |> do_parse(:general)

  @doc """
  Parse binary message to Elixir tuple, if message contains event it will be returned as specific
  `Nostr.Event.t()` struct dependent of type of Event
  """
  @spec parse_specific(String.t()) :: t() | struct()
  def parse_specific(msg) when is_binary(msg),
    do: msg |> JSON.decode!() |> do_parse(:specific)

  # Client to relay
  defp do_parse(["EVENT", event], :general) when is_map(event) do
    {:event, Nostr.Event.parse(event)}
  end

  defp do_parse(["EVENT", event], :specific) when is_map(event) do
    {:event, Nostr.Event.parse_specific(event)}
  end

  defp do_parse(["REQ", sub_id | filters], _type)
       when is_binary(sub_id) and filters != [] do
    parsed = Enum.map(filters, &Nostr.Filter.parse/1)
    {:req, sub_id, parsed}
  end

  defp do_parse(["CLOSE", sub_id], _type) when is_binary(sub_id) do
    {:close, sub_id}
  end

  defp do_parse(["AUTH", event], :general) when is_map(event) do
    {:auth, Nostr.Event.parse(event)}
  end

  defp do_parse(["AUTH", event], :specific) when is_map(event) do
    {:auth, Nostr.Event.parse_specific(event)}
  end

  # Relay to client
  defp do_parse(["EVENT", sub_id, event], :general) when is_binary(sub_id) and is_map(event) do
    {:event, sub_id, Nostr.Event.parse(event)}
  end

  defp do_parse(["EVENT", sub_id, event], :specific) when is_binary(sub_id) and is_map(event) do
    {:event, sub_id, Nostr.Event.parse_specific(event)}
  end

  defp do_parse(["NOTICE", message], _type) when is_binary(message) do
    {:notice, message}
  end

  defp do_parse(["EOSE", sub_id], _type) when is_binary(sub_id) do
    {:eose, sub_id}
  end

  defp do_parse(["OK", event_id, success?, message], _type)
       when is_binary(event_id) and is_boolean(success?) and is_binary(message) do
    {:ok, event_id, success?, message}
  end

  defp do_parse(["AUTH", sub_id], _type) when is_binary(sub_id) do
    {:auth, sub_id}
  end

  defp do_parse(["CLOSED", sub_id, message], _type) when is_binary(sub_id) do
    {:closed, sub_id, message}
  end

  defp do_parse(["COUNT", sub_id, %{"count" => count}], _type)
       when is_binary(sub_id) and is_integer(count) do
    {:count, sub_id, %{count: count}}
  end

  defp do_parse(message, _type) do
    Logger.warning("Parsing unknown message: #{inspect(message)}")
    :error
  end
end
