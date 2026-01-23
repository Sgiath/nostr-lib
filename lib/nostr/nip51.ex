defmodule Nostr.NIP51 do
  @moduledoc """
  NIP-51 Lists - Shared utilities for list event types.

  This module provides common functionality for all NIP-51 list types including:
  - Encryption/decryption of private list items
  - Tag parsing utilities
  - Auto-detection of encryption version (NIP-44 vs legacy NIP-04)

  ## Encryption

  Private items in lists are encrypted using the author's own keys (shared key
  computed from author's public and private key). New lists should use NIP-44
  encryption. For backward compatibility, this module can decrypt both NIP-44
  and legacy NIP-04 encrypted content.

  Detection is automatic: NIP-04 ciphertext contains `?iv=` suffix, NIP-44 does not.

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:nip51], nip: 51

  alias Nostr.Tag

  @doc """
  Encrypts private list items using NIP-44.

  The private items are a list of tags that will be JSON-encoded and encrypted
  using the author's own keypair (same pubkey as sender and recipient).

  ## Parameters
    - `tags` - List of `Nostr.Tag` structs or raw tag arrays
    - `seckey` - Author's secret key (hex-encoded)
    - `pubkey` - Author's public key (hex-encoded)

  ## Returns
    Base64-encoded encrypted payload (NIP-44 format)

  ## Example

      iex> tags = [Nostr.Tag.create(:p, "abc123"), Nostr.Tag.create(:t, "nostr")]
      iex> Nostr.NIP51.encrypt_private_items(tags, seckey, pubkey)
      "AgKK5..."
  """
  @spec encrypt_private_items([Tag.t() | list()], binary(), binary()) :: binary()
  def encrypt_private_items(tags, seckey, pubkey) when is_list(tags) do
    tags
    |> Enum.map(&tag_to_array/1)
    |> JSON.encode!()
    |> Nostr.NIP44.encrypt(seckey, pubkey)
  end

  @doc """
  Decrypts private list items with auto-detection of encryption version.

  Automatically detects whether the content is encrypted with NIP-44 or legacy
  NIP-04 by checking for the `?iv=` suffix that NIP-04 uses.

  ## Parameters
    - `content` - Encrypted content from event
    - `seckey` - Author's secret key (hex-encoded)
    - `pubkey` - Author's public key (hex-encoded)

  ## Returns
    - `{:ok, tags}` - List of parsed `Nostr.Tag` structs
    - `{:error, reason}` - Decryption or parsing failed

  ## Example

      iex> {:ok, tags} = Nostr.NIP51.decrypt_private_items(content, seckey, pubkey)
      iex> Enum.map(tags, & &1.type)
      [:p, :t, :word]
  """
  @spec decrypt_private_items(binary(), binary(), binary()) ::
          {:ok, [Tag.t()]} | {:error, term()}
  def decrypt_private_items("", _seckey, _pubkey), do: {:ok, []}
  def decrypt_private_items(nil, _seckey, _pubkey), do: {:ok, []}

  def decrypt_private_items(content, seckey, pubkey) do
    case detect_encryption_version(content) do
      :nip04 ->
        decrypt_nip04(content, seckey, pubkey)

      :nip44 ->
        decrypt_nip44(content, seckey, pubkey)
    end
  end

  @doc """
  Detects whether encrypted content uses NIP-04 or NIP-44 encryption.

  NIP-04 ciphertext has the format: `<base64_ciphertext>?iv=<base64_iv>`
  NIP-44 ciphertext is plain base64 without the `?iv=` suffix.

  ## Returns
    - `:nip04` - Legacy NIP-04 encryption detected
    - `:nip44` - Modern NIP-44 encryption (default)
  """
  @spec detect_encryption_version(binary()) :: :nip04 | :nip44
  def detect_encryption_version(content) when is_binary(content) do
    if String.contains?(content, "?iv=") do
      :nip04
    else
      :nip44
    end
  end

  @doc """
  Extracts tags of a specific type from an event.

  ## Parameters
    - `event` - A `Nostr.Event` struct
    - `type` - Tag type atom (e.g., `:p`, `:e`, `:t`, `:relay`)

  ## Returns
    List of matching `Nostr.Tag` structs
  """
  @spec get_tags_by_type(Nostr.Event.t(), atom()) :: [Tag.t()]
  def get_tags_by_type(%Nostr.Event{tags: tags}, type) when is_atom(type) do
    Enum.filter(tags, fn %Tag{type: t} -> t == type end)
  end

  @doc """
  Extracts tag data values of a specific type from an event.

  Convenience function that returns just the `data` field of matching tags.

  ## Parameters
    - `event` - A `Nostr.Event` struct
    - `type` - Tag type atom

  ## Returns
    List of data values (strings)
  """
  @spec get_tag_values(Nostr.Event.t(), atom()) :: [binary()]
  def get_tag_values(event, type) do
    event
    |> get_tags_by_type(type)
    |> Enum.map(fn %Tag{data: data} -> data end)
  end

  @doc """
  Extracts the `d` tag identifier from a parameterized replaceable event.

  ## Returns
    - `identifier` - The d tag value if present
    - `nil` - If no d tag exists
  """
  @spec get_identifier(Nostr.Event.t()) :: binary() | nil
  def get_identifier(event) do
    case get_tags_by_type(event, :d) do
      [%Tag{data: identifier} | _rest] -> identifier
      [] -> nil
    end
  end

  @doc """
  Extracts optional set metadata (title, image, description) from an event.

  ## Returns
    Map with `:title`, `:image`, and `:description` keys (values may be nil)
  """
  @spec get_set_metadata(Nostr.Event.t()) :: %{
          title: binary() | nil,
          image: binary() | nil,
          description: binary() | nil
        }
  def get_set_metadata(event) do
    %{
      title: get_first_tag_value(event, :title),
      image: get_first_tag_value(event, :image),
      description: get_first_tag_value(event, :description)
    }
  end

  @doc """
  Converts a tag to its JSON array representation.

  ## Examples

      iex> Nostr.NIP51.tag_to_array(Nostr.Tag.create(:p, "abc123"))
      ["p", "abc123"]

      iex> Nostr.NIP51.tag_to_array(["e", "event_id", "wss://relay.com"])
      ["e", "event_id", "wss://relay.com"]
  """
  @spec tag_to_array(Tag.t() | list()) :: list()
  def tag_to_array(%Tag{type: type, data: data, info: []}) do
    [Atom.to_string(type), data]
  end

  def tag_to_array(%Tag{type: type, data: data, info: info}) do
    [Atom.to_string(type), data | info]
  end

  def tag_to_array(list) when is_list(list), do: list

  # Private functions

  defp get_first_tag_value(event, type) do
    case get_tags_by_type(event, type) do
      [%Tag{data: value} | _rest] -> value
      [] -> nil
    end
  end

  defp decrypt_nip04(content, seckey, pubkey) do
    tags =
      content
      |> Nostr.Crypto.decrypt(seckey, pubkey)
      |> JSON.decode!()
      |> Enum.map(&Tag.parse/1)

    {:ok, tags}
  rescue
    e -> {:error, {:nip04_decrypt_failed, e}}
  end

  defp decrypt_nip44(content, seckey, pubkey) do
    case Nostr.NIP44.decrypt(content, seckey, pubkey) do
      {:ok, plaintext} ->
        case JSON.decode(plaintext) do
          {:ok, arrays} ->
            tags = Enum.map(arrays, &Tag.parse/1)
            {:ok, tags}

          {:error, reason} ->
            {:error, {:json_decode_failed, reason}}
        end

      {:error, reason} ->
        {:error, {:nip44_decrypt_failed, reason}}
    end
  end
end
