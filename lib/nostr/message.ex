defmodule Nostr.Message do
  @moduledoc """
  Nostr message
  """

  require Logger

  @spec create_event(Nostr.Event.t() | %{event: Nostr.Event.t()}) :: {:event, Nostr.Event.t()}
  def create_event(%{event: %Nostr.Event{} = event}), do: {:event, event}
  def create_event(%Nostr.Event{} = event), do: {:event, event}

  @spec request(Nostr.Filter.t() | [Nostr.Filter.t()], binary()) ::
          {:req, binary(), Nostr.Filter.t() | [Nostr.Filter.t()]}
  def request(%Nostr.Filter{} = filter, sub_id), do: {:req, sub_id, filter}
  def request(filters, sub_id), do: {:req, sub_id, filters}

  @spec close(binary()) :: {:close, binary()}
  def close(sub_id), do: {:close, sub_id}

  @spec event(Nostr.Event.t() | %{event: Nostr.Event.t()}, binary()) ::
          {:event, binary(), Nostr.Event.t()}
  def event(%{event: %Nostr.Event{} = event}, sub_id), do: {:event, sub_id, event}
  def event(%Nostr.Event{} = event, sub_id), do: {:event, sub_id, event}

  @spec notice(String.t()) :: {:notice, String.t()}
  def notice(message), do: {:notice, message}

  @spec eose(binary()) :: {:eose, binary()}
  def eose(sub_id), do: {:eose, sub_id}

  @spec ok(binary(), boolean(), String.t()) :: {:ok, binary(), boolean(), String.t()}
  def ok(event_id, success?, message), do: {:ok, event_id, success?, message}

  @spec auth(Nostr.Event.t() | %{event: Nostr.Event.t()} | binary()) ::
          {:auth, Nostr.Event.t() | binary()}
  def auth(%{event: %Nostr.Event{} = event}), do: {:auth, event}
  def auth(%Nostr.Event{} = event), do: {:auth, event}
  def auth(challenge), do: {:auth, challenge}

  @spec serialize(tuple()) :: binary()
  def serialize(message) when is_tuple(message) do
    message
    |> Tuple.to_list()
    |> List.flatten()
    |> then(fn [name | rest] -> [name |> Atom.to_string() |> String.upcase() | rest] end)
    |> Jason.encode!()
  end

  # Parsing
  def parse(msg) when is_binary(msg), do: msg |> Jason.decode!(keys: :atoms) |> do_parse(:general)

  def parse_specific(msg) when is_binary(msg),
    do: msg |> Jason.decode!(keys: :atoms) |> do_parse(:specific)

  # Client to relay
  defp do_parse(["EVENT", event], :general) when is_map(event) do
    {:event, Nostr.Event.parse(event)}
  end

  defp do_parse(["EVENT", event], :specific) when is_map(event) do
    {:event, Nostr.Event.parse_specific(event)}
  end

  defp do_parse(["REQ", sub_id, filter], _type) when is_binary(sub_id) and is_map(filter) do
    {:req, sub_id, Nostr.Filter.parse(filter)}
  end

  defp do_parse(["CLOSE", sub_id], _type) when is_binary(sub_id) do
    {:close, sub_id}
  end

  defp do_parse(["AUTH", event], _type) when is_map(event) do
    {:auth, Nostr.Event.parse(event)}
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

  defp do_parse(message, _type) do
    Logger.warning("Parsing unknown message: #{inspect(message)}")
    :error
  end
end
