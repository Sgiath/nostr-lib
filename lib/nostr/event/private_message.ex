defmodule Nostr.Event.PrivateMessage do
  @moduledoc """
  Private Direct Message (Kind 14)

  This is an unsigned event (rumor) for encrypted chat messages per NIP-17.
  Messages MUST be wrapped in a Seal (kind 13) and GiftWrap (kind 1059) before publishing.

  Defined in NIP 17
  https://github.com/nostr-protocol/nips/blob/master/17.md
  """
  @moduledoc tags: [:event, :nip17], nip: 17

  alias Nostr.Event.Rumor
  alias Nostr.Tag

  defstruct [:rumor, :receivers, :content, :reply_to, :subject, :quotes]

  @typedoc "Receiver with optional relay URL"
  @type receiver() :: %{
          pubkey: binary(),
          relay: URI.t() | nil
        }

  @typedoc "Quoted event reference"
  @type quote_ref() :: %{
          id: binary(),
          relay: binary() | nil,
          pubkey: binary() | nil
        }

  @type t() :: %__MODULE__{
          rumor: Rumor.t(),
          receivers: [receiver()],
          content: binary(),
          reply_to: binary() | nil,
          subject: binary() | nil,
          quotes: [quote_ref()]
        }

  @doc """
  Create a new private message (unsigned rumor)

  ## Arguments

    - `sender_pubkey` - public key of the sender
    - `receiver_pubkeys` - list of receiver public keys (or maps with pubkey and optional relay)
    - `content` - plain text message content
    - `opts` - optional arguments:
      - `:reply_to` - event ID this message is replying to
      - `:subject` - conversation title
      - `:quotes` - list of quoted event references
      - `:created_at` - timestamp (defaults to now)

  ## Example

      iex> msg = Nostr.Event.PrivateMessage.create(
      ...>   "sender_pubkey",
      ...>   ["receiver_pubkey"],
      ...>   "Hello!"
      ...> )
      iex> msg.content
      "Hello!"
      iex> msg.rumor.kind
      14
  """
  @spec create(
          sender_pubkey :: binary(),
          receiver_pubkeys :: [binary() | map()],
          content :: binary(),
          opts :: Keyword.t()
        ) :: t()
  def create(sender_pubkey, receiver_pubkeys, content, opts \\ []) do
    tags = build_tags(receiver_pubkeys, opts)

    rumor =
      Rumor.create(14,
        pubkey: sender_pubkey,
        content: content,
        tags: tags,
        created_at: Keyword.get(opts, :created_at, DateTime.utc_now())
      )

    parse(rumor)
  end

  @doc """
  Parse a kind 14 event or rumor into a PrivateMessage struct

  ## Example

      iex> rumor = %Nostr.Event.Rumor{kind: 14, content: "Hello", tags: [], pubkey: "abc", created_at: DateTime.utc_now()}
      iex> msg = Nostr.Event.PrivateMessage.parse(rumor)
      iex> msg.content
      "Hello"
  """
  @spec parse(Rumor.t() | Nostr.Event.t() | map()) :: t()
  def parse(%Rumor{kind: 14} = rumor) do
    %__MODULE__{
      rumor: rumor,
      receivers: get_receivers(rumor),
      content: rumor.content,
      reply_to: get_reply_to(rumor),
      subject: get_subject(rumor),
      quotes: get_quotes(rumor)
    }
  end

  def parse(%Nostr.Event{kind: 14} = event) do
    event
    |> Rumor.from_event()
    |> parse()
  end

  def parse(%{"kind" => 14} = data) do
    data
    |> Rumor.parse()
    |> parse()
  end

  defp build_tags(receiver_pubkeys, opts) do
    p_tags = Enum.map(receiver_pubkeys, &receiver_to_tag/1)
    e_tag = build_reply_tag(Keyword.get(opts, :reply_to))
    subject_tag = build_subject_tag(Keyword.get(opts, :subject))
    q_tags = build_quote_tags(Keyword.get(opts, :quotes, []))

    Enum.concat([p_tags, List.wrap(e_tag), List.wrap(subject_tag), q_tags])
  end

  defp receiver_to_tag(%{pubkey: pubkey, relay: relay}) when is_binary(relay) do
    Tag.create(:p, pubkey, [relay])
  end

  defp receiver_to_tag(%{pubkey: pubkey}) do
    Tag.create(:p, pubkey)
  end

  defp receiver_to_tag(pubkey) when is_binary(pubkey) do
    Tag.create(:p, pubkey)
  end

  defp build_reply_tag(nil), do: nil

  defp build_reply_tag(event_id) when is_binary(event_id) do
    Tag.create(:e, event_id)
  end

  defp build_reply_tag(%{id: id, relay: relay}) when is_binary(relay) do
    Tag.create(:e, id, [relay])
  end

  defp build_reply_tag(%{id: id}) do
    Tag.create(:e, id)
  end

  defp build_subject_tag(nil), do: nil

  defp build_subject_tag(subject) when is_binary(subject) do
    Tag.create(:subject, subject)
  end

  defp build_quote_tags(quotes) do
    Enum.map(quotes, &quote_to_tag/1)
  end

  defp quote_to_tag(%{id: id, relay: relay, pubkey: pubkey})
       when is_binary(relay) and is_binary(pubkey) do
    Tag.create(:q, id, [relay, pubkey])
  end

  defp quote_to_tag(%{id: id, relay: relay}) when is_binary(relay) do
    Tag.create(:q, id, [relay])
  end

  defp quote_to_tag(%{id: id}) do
    Tag.create(:q, id)
  end

  defp quote_to_tag(id) when is_binary(id) do
    Tag.create(:q, id)
  end

  defp get_receivers(%{tags: tags}) do
    tags
    |> Enum.filter(fn %Tag{type: type} -> type == :p end)
    |> Enum.map(&parse_receiver/1)
  end

  defp parse_receiver(%Tag{type: :p, data: pubkey, info: [relay | _rest]}) do
    %{pubkey: pubkey, relay: URI.parse(relay)}
  end

  defp parse_receiver(%Tag{type: :p, data: pubkey, info: []}) do
    %{pubkey: pubkey, relay: nil}
  end

  defp get_reply_to(%{tags: tags}) do
    Enum.find_value(tags, fn
      %Tag{type: :e, data: event_id} -> event_id
      _other -> nil
    end)
  end

  defp get_subject(%{tags: tags}) do
    Enum.find_value(tags, fn
      %Tag{type: :subject, data: subject} -> subject
      _other -> nil
    end)
  end

  defp get_quotes(%{tags: tags}) do
    tags
    |> Enum.filter(fn %Tag{type: type} -> type == :q end)
    |> Enum.map(&parse_quote/1)
  end

  defp parse_quote(%Tag{type: :q, data: id, info: [relay, pubkey | _rest]}) do
    %{id: id, relay: relay, pubkey: pubkey}
  end

  defp parse_quote(%Tag{type: :q, data: id, info: [relay]}) do
    %{id: id, relay: relay, pubkey: nil}
  end

  defp parse_quote(%Tag{type: :q, data: id, info: []}) do
    %{id: id, relay: nil, pubkey: nil}
  end
end
