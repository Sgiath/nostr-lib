defmodule Nostr.Event.FileMessage do
  @moduledoc """
  Private File Message (Kind 15)

  This is an unsigned event (rumor) for encrypted file messages per NIP-17.
  Messages MUST be wrapped in a Seal (kind 13) and GiftWrap (kind 1059) before publishing.

  The file content is encrypted with AES-GCM and stored externally. The decryption
  key and nonce are included in the event tags.

  Defined in NIP 17
  https://github.com/nostr-protocol/nips/blob/master/17.md
  """
  @moduledoc tags: [:event, :nip17], nip: 17

  alias Nostr.Event.Rumor
  alias Nostr.Tag

  defstruct [
    :rumor,
    :receivers,
    :file_url,
    :reply_to,
    :subject,
    :file_type,
    :encryption_algorithm,
    :decryption_key,
    :decryption_nonce,
    :hash,
    :original_hash,
    :size,
    :dimensions,
    :blurhash,
    :thumbnail,
    :fallbacks
  ]

  @typedoc "Receiver with optional relay URL"
  @type receiver() :: %{
          pubkey: binary(),
          relay: URI.t() | nil
        }

  @type t() :: %__MODULE__{
          rumor: Rumor.t(),
          receivers: [receiver()],
          file_url: binary(),
          reply_to: binary() | nil,
          subject: binary() | nil,
          file_type: binary(),
          encryption_algorithm: binary(),
          decryption_key: binary(),
          decryption_nonce: binary(),
          hash: binary(),
          original_hash: binary() | nil,
          size: non_neg_integer() | nil,
          dimensions: %{width: non_neg_integer(), height: non_neg_integer()} | nil,
          blurhash: binary() | nil,
          thumbnail: binary() | nil,
          fallbacks: [binary()]
        }

  @doc """
  Create a new file message (unsigned rumor)

  ## Arguments

    - `sender_pubkey` - public key of the sender
    - `receiver_pubkeys` - list of receiver public keys (or maps with pubkey and optional relay)
    - `file_url` - URL of the encrypted file
    - `file_metadata` - map with file encryption metadata:
      - `:file_type` - MIME type (required)
      - `:encryption_algorithm` - e.g., "aes-gcm" (required)
      - `:decryption_key` - symmetric key for decryption (required)
      - `:decryption_nonce` - nonce for decryption (required)
      - `:hash` - SHA-256 of encrypted file (required)
      - `:original_hash` - SHA-256 of original file (optional)
      - `:size` - file size in bytes (optional)
      - `:dimensions` - `%{width: w, height: h}` for images (optional)
      - `:blurhash` - blurhash preview (optional)
      - `:thumbnail` - thumbnail URL (optional)
      - `:fallbacks` - list of fallback URLs (optional)
    - `opts` - optional arguments:
      - `:reply_to` - event ID this message is replying to
      - `:subject` - conversation title
      - `:created_at` - timestamp (defaults to now)

  ## Example

      iex> msg = Nostr.Event.FileMessage.create(
      ...>   "sender_pubkey",
      ...>   ["receiver_pubkey"],
      ...>   "https://example.com/file.enc",
      ...>   %{
      ...>     file_type: "image/jpeg",
      ...>     encryption_algorithm: "aes-gcm",
      ...>     decryption_key: "key123",
      ...>     decryption_nonce: "nonce456",
      ...>     hash: "abc123"
      ...>   }
      ...> )
      iex> msg.file_url
      "https://example.com/file.enc"
      iex> msg.rumor.kind
      15
  """
  @spec create(
          sender_pubkey :: binary(),
          receiver_pubkeys :: [binary() | map()],
          file_url :: binary(),
          file_metadata :: map(),
          opts :: Keyword.t()
        ) :: t()
  def create(sender_pubkey, receiver_pubkeys, file_url, file_metadata, opts \\ []) do
    tags = build_tags(receiver_pubkeys, file_metadata, opts)

    rumor =
      Rumor.create(15,
        pubkey: sender_pubkey,
        content: file_url,
        tags: tags,
        created_at: Keyword.get(opts, :created_at, DateTime.utc_now())
      )

    parse(rumor)
  end

  @doc """
  Parse a kind 15 event or rumor into a FileMessage struct
  """
  @spec parse(Rumor.t() | Nostr.Event.t() | map()) :: t()
  def parse(%Rumor{kind: 15} = rumor) do
    %__MODULE__{
      rumor: rumor,
      receivers: get_receivers(rumor),
      file_url: rumor.content,
      reply_to: get_reply_to(rumor),
      subject: get_subject(rumor),
      file_type: get_tag_value(rumor, :"file-type"),
      encryption_algorithm: get_tag_value(rumor, :"encryption-algorithm"),
      decryption_key: get_tag_value(rumor, :"decryption-key"),
      decryption_nonce: get_tag_value(rumor, :"decryption-nonce"),
      hash: get_tag_value(rumor, :x),
      original_hash: get_tag_value(rumor, :ox),
      size: get_size(rumor),
      dimensions: get_dimensions(rumor),
      blurhash: get_tag_value(rumor, :blurhash),
      thumbnail: get_tag_value(rumor, :thumb),
      fallbacks: get_fallbacks(rumor)
    }
  end

  def parse(%Nostr.Event{kind: 15} = event) do
    event
    |> Rumor.from_event()
    |> parse()
  end

  def parse(%{"kind" => 15} = data) do
    data
    |> Rumor.parse()
    |> parse()
  end

  defp build_tags(receiver_pubkeys, file_metadata, opts) do
    p_tags = Enum.map(receiver_pubkeys, &receiver_to_tag/1)
    e_tag = build_reply_tag(Keyword.get(opts, :reply_to))
    subject_tag = build_subject_tag(Keyword.get(opts, :subject))
    file_tags = build_file_tags(file_metadata)

    Enum.concat([p_tags, List.wrap(e_tag), List.wrap(subject_tag), file_tags])
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
    Tag.create(:e, event_id, ["", "reply"])
  end

  defp build_reply_tag(%{id: id, relay: relay}) when is_binary(relay) do
    Tag.create(:e, id, [relay, "reply"])
  end

  defp build_reply_tag(%{id: id}) do
    Tag.create(:e, id, ["", "reply"])
  end

  defp build_subject_tag(nil), do: nil

  defp build_subject_tag(subject) when is_binary(subject) do
    Tag.create(:subject, subject)
  end

  defp build_file_tags(metadata) do
    required_tags = [
      Tag.create(:"file-type", Map.fetch!(metadata, :file_type)),
      Tag.create(:"encryption-algorithm", Map.fetch!(metadata, :encryption_algorithm)),
      Tag.create(:"decryption-key", Map.fetch!(metadata, :decryption_key)),
      Tag.create(:"decryption-nonce", Map.fetch!(metadata, :decryption_nonce)),
      Tag.create(:x, Map.fetch!(metadata, :hash))
    ]

    optional_tags =
      []
      |> maybe_add_tag(:ox, Map.get(metadata, :original_hash))
      |> maybe_add_tag(:size, Map.get(metadata, :size))
      |> maybe_add_dim_tag(Map.get(metadata, :dimensions))
      |> maybe_add_tag(:blurhash, Map.get(metadata, :blurhash))
      |> maybe_add_tag(:thumb, Map.get(metadata, :thumbnail))
      |> add_fallback_tags(Map.get(metadata, :fallbacks, []))

    required_tags ++ optional_tags
  end

  defp maybe_add_tag(tags, _type, nil), do: tags

  defp maybe_add_tag(tags, type, value) when is_integer(value) do
    [Tag.create(type, Integer.to_string(value)) | tags]
  end

  defp maybe_add_tag(tags, type, value) when is_binary(value) do
    [Tag.create(type, value) | tags]
  end

  defp maybe_add_dim_tag(tags, nil), do: tags

  defp maybe_add_dim_tag(tags, %{width: w, height: h}) do
    [Tag.create(:dim, "#{w}x#{h}") | tags]
  end

  defp add_fallback_tags(tags, []), do: tags

  defp add_fallback_tags(tags, fallbacks) do
    fallback_tags = Enum.map(fallbacks, &Tag.create(:fallback, &1))
    tags ++ fallback_tags
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

  defp get_tag_value(%{tags: tags}, tag_type) do
    Enum.find_value(tags, fn
      %Tag{type: ^tag_type, data: value} -> value
      _other -> nil
    end)
  end

  defp get_size(%{tags: tags}) do
    Enum.find_value(tags, fn
      %Tag{type: :size, data: size} -> String.to_integer(size)
      _other -> nil
    end)
  end

  defp get_dimensions(%{tags: tags}) do
    Enum.find_value(tags, fn
      %Tag{type: :dim, data: dim} ->
        [w, h] = String.split(dim, "x")
        %{width: String.to_integer(w), height: String.to_integer(h)}

      _other ->
        nil
    end)
  end

  defp get_fallbacks(%{tags: tags}) do
    tags
    |> Enum.filter(fn %Tag{type: type} -> type == :fallback end)
    |> Enum.map(fn %Tag{data: url} -> url end)
  end
end
