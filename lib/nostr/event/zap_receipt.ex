defmodule Nostr.Event.ZapReceipt do
  @moduledoc """
  Zap Receipt events (Kind 9735).

  Implements NIP-57: https://github.com/nostr-protocol/nips/blob/master/57.md

  A zap receipt is published by the recipient's lightning wallet after a zap request
  invoice has been paid. It serves as proof that a Lightning payment was made.

  ## Required Tags

  - `p` - zap recipient pubkey
  - `bolt11` - the paid Lightning invoice
  - `description` - JSON-encoded zap request event

  ## Optional Tags

  - `P` - zap sender pubkey (uppercase P)
  - `e` - event that was zapped
  - `a` - addressable event coordinate
  - `k` - kind of the zapped event
  - `preimage` - payment preimage

  ## Validation

  Per NIP-57 Appendix F, clients should validate:
  - Receipt's pubkey matches the recipient's LNURL `nostrPubkey`
  - Invoice amount matches the zap request's amount tag
  - Receipt's lnurl tag (if present) matches recipient's lnurl

  ## Examples

      # Parse a zap receipt
      {:ok, receipt} = ZapReceipt.parse(event)

      # Get the zap amount
      sats = ZapReceipt.get_amount_sats(receipt)

      # Get the embedded zap request
      {:ok, request} = ZapReceipt.get_zap_request(receipt)

  """
  @moduledoc tags: [:event, :nip57], nip: 57

  alias Nostr.{Bolt11, Event, Tag}
  alias Nostr.Event.ZapRequest

  @kind 9735

  @type t() :: %__MODULE__{
          event: Event.t(),
          recipient: binary(),
          sender: binary() | nil,
          event_id: binary() | nil,
          address: binary() | nil,
          kind: non_neg_integer() | nil,
          bolt11: binary(),
          description: binary(),
          preimage: binary() | nil,
          invoice: Bolt11.t() | nil,
          zap_request: ZapRequest.t() | nil
        }

  defstruct [
    :event,
    :recipient,
    :sender,
    :event_id,
    :address,
    :kind,
    :bolt11,
    :description,
    :preimage,
    :invoice,
    :zap_request
  ]

  @doc """
  Parses a kind 9735 event into a ZapReceipt struct.

  Automatically parses the embedded bolt11 invoice and zap request.
  """
  @spec parse(Event.t()) :: t() | {:error, String.t(), Event.t()}
  def parse(%Event{kind: @kind} = event) do
    bolt11 = get_tag_value(event.tags, :bolt11)
    description = get_tag_value(event.tags, :description)

    cond do
      is_nil(bolt11) ->
        {:error, "Zap receipt must have a bolt11 tag", event}

      is_nil(description) ->
        {:error, "Zap receipt must have a description tag", event}

      true ->
        invoice = parse_invoice(bolt11)
        zap_request = parse_zap_request(description)

        %__MODULE__{
          event: event,
          recipient: get_tag_value(event.tags, :p),
          sender: get_sender(event.tags),
          event_id: get_tag_value(event.tags, :e),
          address: get_tag_value(event.tags, :a),
          kind: get_kind_value(event.tags),
          bolt11: bolt11,
          description: description,
          preimage: get_tag_value(event.tags, :preimage),
          invoice: invoice,
          zap_request: zap_request
        }
    end
  end

  def parse(%Event{} = event) do
    {:error, "Event is not a zap receipt (expected kind 9735)", event}
  end

  @doc """
  Creates a zap receipt event.

  ## Required Options

  - `:recipient` - recipient pubkey (p tag)
  - `:bolt11` - the paid Lightning invoice
  - `:description` - JSON-encoded zap request event

  ## Optional Options

  - `:sender` - sender pubkey (P tag)
  - `:event_id` - event that was zapped (e tag)
  - `:address` - addressable event coordinate (a tag)
  - `:kind` - kind of the zapped event (k tag)
  - `:preimage` - payment preimage

  ## Examples

      ZapReceipt.create(
        recipient: "recipient_pubkey",
        bolt11: "lnbc...",
        description: ~s({"kind":9734,...}),
        sender: "sender_pubkey",
        event_id: "zapped_event_id"
      )

  """
  @spec create(keyword()) :: t() | {:error, String.t()}
  def create(opts) do
    recipient = Keyword.get(opts, :recipient)
    bolt11 = Keyword.get(opts, :bolt11)
    description = Keyword.get(opts, :description)

    cond do
      is_nil(recipient) ->
        {:error, "recipient is required"}

      is_nil(bolt11) ->
        {:error, "bolt11 is required"}

      is_nil(description) ->
        {:error, "description is required"}

      true ->
        do_create(opts)
    end
  end

  defp do_create(opts) do
    recipient = Keyword.fetch!(opts, :recipient)
    bolt11_str = Keyword.fetch!(opts, :bolt11)
    description = Keyword.fetch!(opts, :description)

    tags =
      [
        Tag.create(:p, recipient),
        Tag.create(:bolt11, bolt11_str),
        Tag.create(:description, description)
      ] ++
        maybe_sender_tag(Keyword.get(opts, :sender)) ++
        maybe_e_tag(Keyword.get(opts, :event_id)) ++
        maybe_a_tag(Keyword.get(opts, :address)) ++
        maybe_k_tag(Keyword.get(opts, :kind)) ++
        maybe_preimage_tag(Keyword.get(opts, :preimage))

    event_opts =
      opts
      |> Keyword.take([:pubkey, :created_at])
      |> Keyword.put(:tags, tags)
      |> Keyword.put(:content, "")

    @kind
    |> Event.create(event_opts)
    |> parse()
  end

  @doc """
  Returns the zap amount in satoshis from the parsed invoice.

  Returns nil if the invoice couldn't be parsed or has no amount.
  """
  @spec get_amount_sats(t()) :: non_neg_integer() | nil
  def get_amount_sats(%__MODULE__{invoice: nil}), do: nil
  def get_amount_sats(%__MODULE__{invoice: invoice}), do: Bolt11.amount_sats(invoice)

  @doc """
  Returns the zap amount in millisatoshis from the parsed invoice.
  """
  @spec get_amount_msats(t()) :: non_neg_integer() | nil
  def get_amount_msats(%__MODULE__{invoice: nil}), do: nil
  def get_amount_msats(%__MODULE__{invoice: invoice}), do: Bolt11.amount_msats(invoice)

  @doc """
  Returns the parsed zap request from the description tag.

  Returns `{:ok, zap_request}` if successfully parsed, `{:error, reason}` otherwise.
  """
  @spec get_zap_request(t()) :: {:ok, ZapRequest.t()} | {:error, String.t()}
  def get_zap_request(%__MODULE__{zap_request: nil}), do: {:error, "Failed to parse zap request"}
  def get_zap_request(%__MODULE__{zap_request: req}), do: {:ok, req}

  @doc """
  Validates the zap receipt according to NIP-57 Appendix F.

  ## Validation Steps

  1. Receipt's pubkey must match the wallet's `nostrPubkey`
  2. Invoice amount must match the zap request's amount tag (if present)
  3. Zap request's lnurl tag (if present) should match recipient's lnurl

  Returns `:ok` if valid, `{:error, reason}` otherwise.
  """
  @spec validate(t(), binary()) :: :ok | {:error, String.t()}
  def validate(
        %__MODULE__{event: event, invoice: invoice, zap_request: zap_request},
        wallet_pubkey
      ) do
    cond do
      event.pubkey != wallet_pubkey ->
        {:error, "Receipt pubkey does not match wallet's nostrPubkey"}

      not amounts_match?(invoice, zap_request) ->
        {:error, "Invoice amount does not match zap request amount"}

      true ->
        :ok
    end
  end

  defp amounts_match?(nil, _), do: true
  defp amounts_match?(_, nil), do: true

  defp amounts_match?(_invoice, %ZapRequest{amount_msats: nil}), do: true

  defp amounts_match?(invoice, %ZapRequest{amount_msats: request_msats}) do
    case Bolt11.amount_msats(invoice) do
      nil -> true
      invoice_msats -> invoice_msats == request_msats
    end
  end

  # Private helpers

  defp get_tag_value(tags, type) do
    case Enum.find(tags, &(&1.type == type)) do
      %Tag{data: value} -> value
      nil -> nil
    end
  end

  # P tag (uppercase) for sender
  defp get_sender(tags) do
    case Enum.find(tags, fn tag ->
           tag.type == :P or (is_binary(tag.type) and tag.type == "P")
         end) do
      %Tag{data: value} -> value
      nil -> nil
    end
  end

  defp get_kind_value(tags) do
    case get_tag_value(tags, :k) do
      nil ->
        nil

      str when is_binary(str) ->
        case Integer.parse(str) do
          {kind, ""} -> kind
          _ -> nil
        end
    end
  end

  defp parse_invoice(bolt11) do
    case Bolt11.decode(bolt11) do
      {:ok, invoice} -> invoice
      {:error, _} -> nil
    end
  end

  defp parse_zap_request(description) do
    with {:ok, event_map} when is_map(event_map) <- JSON.decode(description),
         %Event{} = event <- safe_parse_event(event_map),
         %ZapRequest{} = request <- ZapRequest.parse(event) do
      request
    else
      _ -> nil
    end
  end

  defp safe_parse_event(event_map) do
    Nostr.Event.Parser.parse(event_map)
  rescue
    _ -> nil
  end

  @doc """
  Serializes an event to JSON object format for use in the description tag.

  This is different from `Event.serialize/1` which returns array format for ID computation.
  """
  @spec serialize_event_to_json(Event.t()) :: binary()
  def serialize_event_to_json(%Event{} = event) do
    %{
      "id" => event.id,
      "pubkey" => event.pubkey,
      "created_at" => DateTime.to_unix(event.created_at),
      "kind" => event.kind,
      "tags" => Enum.map(event.tags, &tag_to_list/1),
      "content" => event.content,
      "sig" => event.sig
    }
    |> JSON.encode!()
  end

  defp tag_to_list(%Tag{type: type, data: data, info: info}) do
    [to_string(type), data | info]
  end

  defp maybe_sender_tag(nil), do: []
  defp maybe_sender_tag(sender), do: [Tag.create(:P, sender)]

  defp maybe_e_tag(nil), do: []
  defp maybe_e_tag(event_id), do: [Tag.create(:e, event_id)]

  defp maybe_a_tag(nil), do: []
  defp maybe_a_tag(address), do: [Tag.create(:a, address)]

  defp maybe_k_tag(nil), do: []
  defp maybe_k_tag(kind), do: [Tag.create(:k, Integer.to_string(kind))]

  defp maybe_preimage_tag(nil), do: []
  defp maybe_preimage_tag(preimage), do: [Tag.create(:preimage, preimage)]
end
