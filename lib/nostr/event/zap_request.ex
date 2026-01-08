defmodule Nostr.Event.ZapRequest do
  @moduledoc """
  Zap Request events (Kind 9734).

  Implements NIP-57: https://github.com/nostr-protocol/nips/blob/master/57.md

  A zap request is NOT published to relays. Instead, it is sent to the recipient's
  LNURL pay callback URL to request a Lightning invoice. When the invoice is paid,
  the recipient's wallet publishes a zap receipt (kind 9735).

  ## Required Tags

  - `relays` - list of relays where the receipt should be published
  - `p` - recipient's pubkey (exactly one)

  ## Optional Tags

  - `amount` - amount in millisatoshis
  - `lnurl` - bech32-encoded lnurl
  - `e` - event being zapped (0 or 1)
  - `a` - addressable event coordinate
  - `k` - kind of the zapped event

  ## Examples

      # Create a zap request for a user
      ZapRequest.create("recipient_pubkey", ["wss://relay.example.com"],
        amount_sats: 1000,
        message: "Great post!"
      )

      # Create a zap request for an event
      ZapRequest.create("recipient_pubkey", ["wss://relay.example.com"],
        amount_sats: 100,
        event_id: "event_id_to_zap",
        kind: 1
      )

  """
  @moduledoc tags: [:event, :nip57], nip: 57

  alias Nostr.{Event, Tag}

  @kind 9734

  @type t() :: %__MODULE__{
          event: Event.t(),
          recipient: binary(),
          relays: [binary()],
          amount_msats: non_neg_integer() | nil,
          lnurl: binary() | nil,
          event_id: binary() | nil,
          address: binary() | nil,
          kind: non_neg_integer() | nil,
          message: binary()
        }

  defstruct [
    :event,
    :recipient,
    :amount_msats,
    :lnurl,
    :event_id,
    :address,
    :kind,
    relays: [],
    message: ""
  ]

  @doc """
  Parses a kind 9734 event into a ZapRequest struct.

  ## Validation

  Per NIP-57 Appendix D:
  - Must have exactly one `p` tag
  - Must have 0 or 1 `e` tags
  - Must have 0 or 1 `a` tags
  """
  @spec parse(Event.t()) :: t() | {:error, String.t(), Event.t()}
  def parse(%Event{kind: @kind} = event) do
    p_tags = get_tags_by_type(event.tags, :p)
    e_tags = get_tags_by_type(event.tags, :e)
    a_tags = get_tags_by_type(event.tags, :a)

    cond do
      length(p_tags) != 1 ->
        {:error, "Zap request must have exactly one p tag", event}

      length(e_tags) > 1 ->
        {:error, "Zap request must have 0 or 1 e tags", event}

      length(a_tags) > 1 ->
        {:error, "Zap request must have 0 or 1 a tags", event}

      true ->
        %__MODULE__{
          event: event,
          recipient: hd(p_tags).data,
          relays: get_relays(event.tags),
          amount_msats: get_amount(event.tags),
          lnurl: get_tag_value(event.tags, :lnurl),
          event_id: get_first_tag_value(e_tags),
          address: get_first_tag_value(a_tags),
          kind: get_kind(event.tags),
          message: event.content || ""
        }
    end
  end

  def parse(%Event{} = event) do
    {:error, "Event is not a zap request (expected kind 9734)", event}
  end

  @doc """
  Creates a zap request event.

  ## Options

  - `:amount_sats` - amount in satoshis (will be converted to millisats)
  - `:amount_msats` - amount in millisatoshis (takes precedence over amount_sats)
  - `:lnurl` - bech32-encoded lnurl of recipient
  - `:event_id` - event ID being zapped
  - `:address` - addressable event coordinate (e.g., "30023:pubkey:identifier")
  - `:kind` - kind of the event being zapped
  - `:message` - optional message/comment

  ## Examples

      ZapRequest.create("pubkey", ["wss://relay.example.com"],
        amount_sats: 1000,
        event_id: "abc123",
        kind: 1,
        message: "Great post!"
      )

  """
  @spec create(binary(), [binary()], keyword()) :: t()
  def create(recipient, relays, opts \\ []) do
    amount_msats = get_amount_from_opts(opts)
    lnurl = Keyword.get(opts, :lnurl)
    event_id = Keyword.get(opts, :event_id)
    address = Keyword.get(opts, :address)
    kind = Keyword.get(opts, :kind)
    message = Keyword.get(opts, :message, "")

    tags =
      [build_relays_tag(relays), Tag.create(:p, recipient)] ++
        maybe_amount_tag(amount_msats) ++
        maybe_lnurl_tag(lnurl) ++
        maybe_e_tag(event_id) ++
        maybe_a_tag(address) ++
        maybe_k_tag(kind)

    event_opts =
      opts
      |> Keyword.take([:pubkey, :created_at])
      |> Keyword.put(:tags, tags)
      |> Keyword.put(:content, message)

    @kind
    |> Event.create(event_opts)
    |> parse()
  end

  @doc """
  Builds the LNURL callback URL with the zap request as a query parameter.

  The zap request event must be signed before calling this function.

  ## Example

      signed_request = Event.sign(zap_request.event, seckey)
      url = ZapRequest.to_callback_url(%{zap_request | event: signed_request}, callback_url)
      # => "https://lnurl.example.com/callback?amount=1000&nostr=..."

  """
  @spec to_callback_url(t(), binary()) :: binary()
  def to_callback_url(
        %__MODULE__{event: event, amount_msats: amount_msats, lnurl: lnurl},
        callback_url
      ) do
    event_json = Event.serialize(event)
    encoded_event = URI.encode(event_json)

    params = [{"nostr", encoded_event}]

    params =
      if amount_msats, do: [{"amount", Integer.to_string(amount_msats)} | params], else: params

    params = if lnurl, do: [{"lnurl", lnurl} | params], else: params

    query = URI.encode_query(params)

    if String.contains?(callback_url, "?") do
      callback_url <> "&" <> query
    else
      callback_url <> "?" <> query
    end
  end

  # Private helpers

  defp get_tags_by_type(tags, type) do
    Enum.filter(tags, &(&1.type == type))
  end

  defp get_tag_value(tags, type) do
    case Enum.find(tags, &(&1.type == type)) do
      %Tag{data: value} -> value
      nil -> nil
    end
  end

  defp get_first_tag_value([]), do: nil
  defp get_first_tag_value([%Tag{data: value} | _]), do: value

  defp get_relays(tags) do
    case Enum.find(tags, &(&1.type == :relays)) do
      %Tag{data: first, info: rest} -> [first | rest]
      nil -> []
    end
  end

  defp get_amount(tags) do
    case get_tag_value(tags, :amount) do
      nil -> nil
      str -> parse_amount(str)
    end
  end

  defp parse_amount(str) when is_binary(str) do
    case Integer.parse(str) do
      {amount, ""} -> amount
      _ -> nil
    end
  end

  defp get_kind(tags) do
    case get_tag_value(tags, :k) do
      nil -> nil
      str -> parse_amount(str)
    end
  end

  defp get_amount_from_opts(opts) do
    cond do
      msats = Keyword.get(opts, :amount_msats) -> msats
      sats = Keyword.get(opts, :amount_sats) -> sats * 1000
      true -> nil
    end
  end

  defp build_relays_tag([first | rest]) do
    Tag.create(:relays, first, rest)
  end

  defp maybe_amount_tag(nil), do: []
  defp maybe_amount_tag(msats), do: [Tag.create(:amount, Integer.to_string(msats))]

  defp maybe_lnurl_tag(nil), do: []
  defp maybe_lnurl_tag(lnurl), do: [Tag.create(:lnurl, lnurl)]

  defp maybe_e_tag(nil), do: []
  defp maybe_e_tag(event_id), do: [Tag.create(:e, event_id)]

  defp maybe_a_tag(nil), do: []
  defp maybe_a_tag(address), do: [Tag.create(:a, address)]

  defp maybe_k_tag(nil), do: []
  defp maybe_k_tag(kind), do: [Tag.create(:k, Integer.to_string(kind))]
end
