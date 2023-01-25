defmodule Nostr.Message do
  @moduledoc """
  Nostr message
  """

  require Logger

  def create_event(%{event: %Nostr.Event{} = event}), do: {:event, event}
  def create_event(%Nostr.Event{} = event), do: {:event, event}
  def request(%Nostr.Filter{} = filter, sub_id), do: {:req, sub_id, filter}
  def request(filters, sub_id), do: {:req, sub_id, filters}
  def close(sub_id), do: {:close, sub_id}
  def event(%{event: %Nostr.Event{} = event}, sub_id), do: {:event, sub_id, event}
  def event(%Nostr.Event{} = event, sub_id), do: {:event, sub_id, event}
  def notice(message), do: {:notice, message}
  def eose(sub_id), do: {:eose, sub_id}
  def ok(event_id, success?, message), do: {:ok, event_id, success?, message}
  def auth(%{event: %Nostr.Event{} = event}), do: {:auth, event}
  def auth(%Nostr.Event{} = event), do: {:auth, event}
  def auth(challenge), do: {:auth, challenge}

  def serialize(message) when is_tuple(message) do
    message
    |> Tuple.to_list()
    |> List.flatten()
    |> then(fn [name | rest] -> [name |> Atom.to_string() |> String.upcase() | rest] end)
    |> Jason.encode!()
  end

  # Parsing
  def parse(msg) when is_binary(msg), do: msg |> Jason.decode!(keys: :atoms) |> parse()

  # Client to relay
  def parse(["EVENT", event]) when is_map(event) do
    {:event, Nostr.Event.parse(event)}
  end

  def parse(["REQ", sub_id, filter]) when is_binary(sub_id) and is_map(filter) do
    {:req, sub_id, Nostr.Filter.parse(filter)}
  end

  def parse(["CLOSE", sub_id]) when is_binary(sub_id) do
    {:close, sub_id}
  end

  def parse(["AUTH", event]) when is_map(event) do
    {:auth, Nostr.Event.parse(event)}
  end

  # Relay to client
  def parse(["EVENT", sub_id, event]) when is_binary(sub_id) and is_map(event) do
    {:event, sub_id, Nostr.Event.parse(event)}
  end

  def parse(["NOTICE", message]) when is_binary(message) do
    {:notice, message}
  end

  def parse(["EOSE", sub_id]) when is_binary(sub_id) do
    {:eose, sub_id}
  end

  def parse(["OK", event_id, success?, message])
      when is_binary(event_id) and is_boolean(success?) and is_binary(message) do
    {:ok, event_id, success?, message}
  end

  def parse(["AUTH", sub_id]) when is_binary(sub_id) do
    {:auth, sub_id}
  end

  def parse(message) do
    Logger.warning("Parsing unknown message: #{inspect(message)}")
    :error
  end
end
