defmodule Nostr.Event.DraftWrap do
  @moduledoc """
  Draft Wraps (Kind 31234)

  Encrypted storage for unsigned draft events. The draft is JSON-stringified,
  NIP-44 encrypted to the signer's own public key, and stored in content.

  ## Examples

      # Create a draft wrap for a note
      draft = %{kind: 1, content: "My draft note", tags: []}
      {:ok, wrap} = DraftWrap.create(draft, seckey, identifier: "my-draft")

      # Decrypt a draft wrap
      {:ok, decrypted} = DraftWrap.decrypt(wrap, seckey)
      decrypted.draft  # => %{kind: 1, content: "My draft note", tags: []}

      # Create a deletion (blanked content)
      {:ok, deletion} = DraftWrap.delete("my-draft", pubkey: pubkey)

  See: https://github.com/nostr-protocol/nips/blob/master/37.md
  """
  @moduledoc tags: [:event, :nip37], nip: 37

  alias Nostr.Crypto
  alias Nostr.Event
  alias Nostr.NIP44
  alias Nostr.Tag

  defstruct [:event, :identifier, :draft_kind, :expiration, :draft]

  @type t() :: %__MODULE__{
          event: Event.t(),
          identifier: binary(),
          draft_kind: non_neg_integer() | nil,
          expiration: non_neg_integer() | nil,
          draft: map() | nil
        }

  @doc """
  Parses a kind 31234 event into a DraftWrap struct.

  The draft field will be nil until decrypt/2 is called.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 31_234} = event) do
    %__MODULE__{
      event: event,
      identifier: get_tag_value(event.tags, :d) || "",
      draft_kind: get_draft_kind(event.tags),
      expiration: get_expiration(event.tags),
      draft: nil
    }
  end

  @doc """
  Creates a draft wrap event.

  The draft is JSON-stringified and NIP-44 encrypted to the signer's public key.

  ## Arguments
    - `draft` - Map or Event struct representing the unsigned draft event
    - `seckey` - Hex-encoded secret key for signing and encryption
    - `opts` - Options

  ## Options
    - `:identifier` - The d tag identifier (default: random UUID)
    - `:expiration` - Unix timestamp when the draft expires
    - `:pubkey` - Override pubkey (derived from seckey if not provided)
    - `:created_at` - Override created_at timestamp

  ## Returns
    - `{:ok, draft_wrap}` - The created draft wrap (with draft field populated)
  """
  @spec create(draft :: map() | Event.t(), seckey :: binary(), opts :: Keyword.t()) ::
          {:ok, t()}
  def create(draft, seckey, opts \\ []) do
    pubkey = Keyword.get_lazy(opts, :pubkey, fn -> Crypto.pubkey(seckey) end)
    identifier = Keyword.get(opts, :identifier, generate_identifier())
    expiration = Keyword.get(opts, :expiration)

    draft_map = normalize_draft(draft)
    draft_kind = Map.get(draft_map, :kind) || Map.get(draft_map, "kind")

    draft_json = JSON.encode!(draft_map)
    encrypted_content = NIP44.encrypt(draft_json, seckey, pubkey)

    tags = build_tags(identifier, draft_kind, expiration)

    event_opts =
      opts
      |> Keyword.drop([:identifier, :expiration])
      |> Keyword.merge(content: encrypted_content, tags: tags, pubkey: pubkey)

    event =
      31_234
      |> Event.create(event_opts)
      |> Event.sign(seckey)

    wrap = %__MODULE__{
      event: event,
      identifier: identifier,
      draft_kind: draft_kind,
      expiration: expiration,
      draft: draft_map
    }

    {:ok, wrap}
  end

  @doc """
  Decrypts a draft wrap and returns it with the draft field populated.

  ## Arguments
    - `wrap` - The DraftWrap struct to decrypt
    - `seckey` - Hex-encoded secret key for decryption

  ## Returns
    - `{:ok, draft_wrap}` - The wrap with draft field populated
    - `{:error, reason}` - On decryption failure
  """
  @spec decrypt(t(), binary()) :: {:ok, t()} | {:error, atom()}
  def decrypt(%__MODULE__{event: event} = wrap, seckey) do
    if event.content == "" do
      {:ok, %{wrap | draft: nil}}
    else
      with {:ok, draft_json} <- NIP44.decrypt(event.content, seckey, event.pubkey),
           {:ok, draft_map} <- JSON.decode(draft_json) do
        {:ok, %{wrap | draft: draft_map}}
      else
        {:error, %JSON.DecodeError{}} -> {:error, :invalid_draft_json}
        {:error, _reason} = error -> error
      end
    end
  end

  @doc """
  Creates a draft deletion event (blanked content).

  A blanked content field signals that the draft has been deleted.

  ## Arguments
    - `identifier` - The d tag identifier of the draft to delete
    - `opts` - Options (requires :pubkey or :seckey)

  ## Options
    - `:pubkey` - Author's public key (required if seckey not provided)
    - `:seckey` - Secret key to derive pubkey and sign
    - `:draft_kind` - Optional kind of the original draft
    - `:created_at` - Override created_at timestamp

  ## Returns
    - `{:ok, draft_wrap}` - The deletion wrap (unsigned unless seckey provided)
  """
  @spec delete(binary(), Keyword.t()) :: {:ok, t()}
  def delete(identifier, opts) do
    seckey = Keyword.get(opts, :seckey)
    pubkey = Keyword.get(opts, :pubkey) || (seckey && Crypto.pubkey(seckey))
    draft_kind = Keyword.get(opts, :draft_kind)

    if !pubkey do
      raise ArgumentError, "either :pubkey or :seckey must be provided"
    end

    tags = build_tags(identifier, draft_kind, nil)

    event_opts =
      opts
      |> Keyword.drop([:identifier, :draft_kind, :seckey])
      |> Keyword.merge(content: "", tags: tags, pubkey: pubkey)

    event = Event.create(31_234, event_opts)
    event = if seckey, do: Event.sign(event, seckey), else: event

    wrap = %__MODULE__{
      event: event,
      identifier: identifier,
      draft_kind: draft_kind,
      expiration: nil,
      draft: nil
    }

    {:ok, wrap}
  end

  @doc """
  Checks if this draft wrap represents a deletion (blanked content).
  """
  @spec deleted?(t()) :: boolean()
  def deleted?(%__MODULE__{event: %{content: ""}}), do: true
  def deleted?(_wrap), do: false

  # Private functions

  defp build_tags(identifier, draft_kind, expiration) do
    tags = [Tag.create(:d, identifier)]

    tags =
      if draft_kind do
        tags ++ [Tag.create(:k, to_string(draft_kind))]
      else
        tags
      end

    if expiration do
      tags ++ [Tag.create(:expiration, to_string(expiration))]
    else
      tags
    end
  end

  defp normalize_draft(%Event{} = event) do
    %{
      kind: event.kind,
      content: event.content,
      tags: Enum.map(event.tags, &tag_to_list/1),
      pubkey: event.pubkey,
      created_at: event.created_at
    }
  end

  defp normalize_draft(draft) when is_map(draft), do: draft

  defp tag_to_list(%Tag{type: type, data: data, info: info}) do
    [Atom.to_string(type), data | info]
  end

  defp get_tag_value(tags, type) do
    case Enum.find(tags, &(&1.type == type)) do
      %Tag{data: value} -> value
      nil -> nil
    end
  end

  defp get_draft_kind(tags) do
    case get_tag_value(tags, :k) do
      nil -> nil
      kind_str -> String.to_integer(kind_str)
    end
  end

  defp get_expiration(tags) do
    case get_tag_value(tags, :expiration) do
      nil -> nil
      exp_str -> String.to_integer(exp_str)
    end
  end

  defp generate_identifier do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end
end
