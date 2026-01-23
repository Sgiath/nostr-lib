defmodule Nostr.Event.OpenTimestamps do
  @moduledoc """
  OpenTimestamps attestation for events

  Defined in NIP 03
  https://github.com/nostr-protocol/nips/blob/master/03.md
  """
  @moduledoc tags: [:event, :nip03], nip: 03

  defstruct [:event, :user, :target_event, :target_relay, :target_kind, :ots_data]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          user: <<_::32, _::_*8>>,
          target_event: binary(),
          target_relay: URI.t() | nil,
          target_kind: non_neg_integer() | nil,
          ots_data: String.t()
        }

  @doc "Parses a kind 1040 event into an `OpenTimestamps` struct."
  @spec parse(event :: Nostr.Event.t()) :: t() | {:error, String.t(), Nostr.Event.t()}
  def parse(%Nostr.Event{kind: 1040} = event) do
    with {:ok, target_event, target_relay} <- get_target_event(event) do
      %__MODULE__{
        event: event,
        user: event.pubkey,
        target_event: target_event,
        target_relay: target_relay,
        target_kind: get_target_kind(event),
        ots_data: event.content
      }
    end
  end

  @doc """
  Create new OpenTimestamps attestation event

  ## Arguments:

    - `target_event_id` - ID of the event being timestamped
    - `ots_data` - base64-encoded OTS file data
    - `opts` - optional event arguments:
      - `:target_relay` - relay URL where target event can be found
      - `:target_kind` - kind of the target event
      - plus standard event opts (`pubkey`, `created_at`)

  """
  @spec create(target_event_id :: binary(), ots_data :: String.t(), opts :: Keyword.t()) :: t()
  def create(target_event_id, ots_data, opts \\ []) do
    {target_relay, opts} = Keyword.pop(opts, :target_relay)
    {target_kind, opts} = Keyword.pop(opts, :target_kind)

    tags =
      [build_e_tag(target_event_id, target_relay), build_k_tag(target_kind)]
      |> Enum.reject(&is_nil/1)

    opts = Keyword.merge(opts, tags: tags, content: ots_data)

    1040
    |> Nostr.Event.create(opts)
    |> parse()
  end

  defp get_target_event(%Nostr.Event{tags: tags} = event) do
    case Enum.find(tags, &(&1.type == :e)) do
      %Nostr.Tag{data: event_id, info: [relay | _rest]} ->
        {:ok, event_id, URI.parse(relay)}

      %Nostr.Tag{data: event_id, info: []} ->
        {:ok, event_id, nil}

      nil ->
        {:error, "Cannot find target event tag", event}
    end
  end

  defp get_target_kind(%Nostr.Event{tags: tags}) do
    case Enum.find(tags, &(&1.type == :k)) do
      %Nostr.Tag{data: kind} when is_binary(kind) -> String.to_integer(kind)
      %Nostr.Tag{data: kind} when is_integer(kind) -> kind
      nil -> nil
    end
  end

  defp build_e_tag(event_id, nil), do: Nostr.Tag.create(:e, event_id)
  defp build_e_tag(event_id, relay), do: Nostr.Tag.create(:e, event_id, [relay])

  defp build_k_tag(nil), do: nil
  defp build_k_tag(kind), do: Nostr.Tag.create(:k, to_string(kind))
end
