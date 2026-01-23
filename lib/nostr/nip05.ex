defmodule Nostr.NIP05 do
  @moduledoc """
  NIP-05: Mapping Nostr keys to DNS-based internet identifiers.

  This module provides utilities for parsing, validating, and verifying NIP-05
  identifiers (email-like addresses that map to Nostr public keys).

  ## Local Functions (no HTTP required)

  - `parse/1` - Split identifier into local-part and domain
  - `valid?/1` - Check if identifier format is valid
  - `verification_url/1` - Build the .well-known URL for verification
  - `display/1` - Format identifier for display (handles `_@domain` -> `domain`)

  ## HTTP Verification (requires :req dependency)

  - `resolve/1` - Fetch pubkey and relays from .well-known endpoint
  - `verify/2` - Verify identifier matches expected pubkey

  Defined in [NIP-05](https://github.com/nostr-protocol/nips/blob/master/05.md)
  """
  @moduledoc tags: [:nip05], nip: 05

  @typedoc "NIP-05 identifier (e.g., `bob@example.com`)"
  @type nip05_id :: String.t()

  @typedoc "Local part of identifier (before @)"
  @type local_part :: String.t()

  @typedoc "Domain part of identifier (after @)"
  @type domain :: String.t()

  @typedoc "Hex-encoded public key"
  @type pubkey :: String.t()

  # Valid characters for local-part: a-z, 0-9, ., _, -
  # Case-insensitive per NIP-05 spec
  @local_part_regex ~r/^[a-z0-9._-]+$/i

  @doc """
  Parse a NIP-05 identifier into its local-part and domain components.

  ## Examples

      iex> Nostr.NIP05.parse("bob@example.com")
      {:ok, "bob", "example.com"}

      iex> Nostr.NIP05.parse("_@domain.com")
      {:ok, "_", "domain.com"}

      iex> Nostr.NIP05.parse("invalid")
      {:error, "missing @ separator"}

  """
  @spec parse(nip05_id()) :: {:ok, local_part(), domain()} | {:error, String.t()}
  def parse(identifier) when is_binary(identifier) do
    case String.split(identifier, "@") do
      [local_part, domain] when local_part != "" and domain != "" ->
        {:ok, local_part, domain}

      [_single] ->
        {:error, "missing @ separator"}

      [local_part, _domain] when local_part == "" ->
        {:error, "empty local-part"}

      [_local_part, domain] when domain == "" ->
        {:error, "empty domain"}

      _multiple ->
        {:error, "multiple @ characters"}
    end
  end

  def parse(_non_string), do: {:error, "identifier must be a string"}

  @doc """
  Check if a NIP-05 identifier has valid format.

  The local-part must contain only `a-z`, `0-9`, `.`, `_`, or `-` characters
  (case-insensitive). The domain must be non-empty.

  ## Examples

      iex> Nostr.NIP05.valid?("bob@example.com")
      true

      iex> Nostr.NIP05.valid?("alice_123@domain.co")
      true

      iex> Nostr.NIP05.valid?("_@bob.com")
      true

      iex> Nostr.NIP05.valid?("Bob!@example.com")
      false

  """
  @spec valid?(nip05_id()) :: boolean()
  def valid?(identifier) when is_binary(identifier) do
    case parse(identifier) do
      {:ok, local_part, _domain} ->
        Regex.match?(@local_part_regex, local_part)

      {:error, _reason} ->
        false
    end
  end

  def valid?(_non_string), do: false

  @doc """
  Build the well-known verification URL for a NIP-05 identifier.

  ## Examples

      iex> {:ok, url} = Nostr.NIP05.verification_url("bob@example.com")
      iex> URI.to_string(url)
      "https://example.com/.well-known/nostr.json?name=bob"

      iex> {:ok, url} = Nostr.NIP05.verification_url("_@domain.com")
      iex> URI.to_string(url)
      "https://domain.com/.well-known/nostr.json?name=_"

  """
  @spec verification_url(nip05_id()) :: {:ok, URI.t()} | {:error, String.t()}
  def verification_url(identifier) do
    case parse(identifier) do
      {:ok, local_part, domain} ->
        url =
          "https://#{domain}/.well-known/nostr.json"
          |> URI.new!()
          |> URI.append_query("name=#{URI.encode_www_form(local_part)}")

        {:ok, url}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Format a NIP-05 identifier for display.

  Per NIP-05, the identifier `_@domain` is the "root" identifier and should
  be displayed as just `domain`.

  ## Examples

      iex> Nostr.NIP05.display("bob@example.com")
      "bob@example.com"

      iex> Nostr.NIP05.display("_@bob.com")
      "bob.com"

  """
  @spec display(nip05_id()) :: String.t()
  def display(identifier) when is_binary(identifier) do
    case parse(identifier) do
      {:ok, "_", domain} -> domain
      _other -> identifier
    end
  end

  def display(identifier), do: identifier

  @doc """
  Resolve a NIP-05 identifier to its pubkey and optional relay list.

  Makes an HTTP request to the domain's `.well-known/nostr.json` endpoint.
  Redirects are disabled per NIP-05 security requirements.

  Returns `{:ok, pubkey, relays}` where `pubkey` is the hex-encoded public key
  and `relays` is a list of relay URLs (may be empty).

  **Requires the `:req` dependency.**

  ## Options

  Any options are passed to `Req.get/2`. Useful for testing with `:plug` option.

  ## Examples

      # Assuming bob@example.com exists and returns valid data:
      {:ok, "b0635d6a9851d3aed0cd6c495b282167acf761729078d975fc341b22650b07b9", ["wss://relay.example.com"]}

  """
  @spec resolve(nip05_id(), keyword()) :: {:ok, pubkey(), [String.t()]} | {:error, String.t()}
  def resolve(identifier, opts \\ []) do
    ensure_req!()

    with {:ok, local_part, _domain} <- parse(identifier),
         {:ok, url} <- verification_url(identifier) do
      req_opts = Keyword.merge([redirect: false, url: URI.to_string(url)], opts)

      case Req.get(req_opts) do
        {:ok, %Req.Response{status: status}} when status in 300..399 ->
          {:error, "redirects not allowed"}

        {:ok, %Req.Response{status: 200, body: body}} when is_map(body) ->
          extract_from_response(body, local_part)

        {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
          case JSON.decode(body) do
            {:ok, decoded} -> extract_from_response(decoded, local_part)
            {:error, _reason} -> {:error, "invalid JSON response"}
          end

        {:ok, %Req.Response{status: status}} ->
          {:error, "HTTP #{status}"}

        {:error, reason} ->
          {:error, "request failed: #{inspect(reason)}"}
      end
    end
  end

  @doc """
  Verify that a NIP-05 identifier resolves to the expected pubkey.

  Returns `:ok` if the identifier resolves to the given pubkey,
  or `{:error, reason}` otherwise.

  **Requires the `:req` dependency.**

  ## Options

  Any options are passed to `resolve/2`. Useful for testing with `:plug` option.

  ## Examples

      # Verify bob@example.com maps to the expected pubkey:
      :ok = Nostr.NIP05.verify("bob@example.com", "b0635d6a9851d3aed0cd6c495b282167acf761729078d975fc341b22650b07b9")

      # Mismatch returns error:
      {:error, "pubkey mismatch"} = Nostr.NIP05.verify("bob@example.com", "wrong_pubkey")

  """
  @spec verify(nip05_id(), pubkey(), keyword()) :: :ok | {:error, String.t()}
  def verify(identifier, expected_pubkey, opts \\ []) when is_binary(expected_pubkey) do
    case resolve(identifier, opts) do
      {:ok, pubkey, _relays} ->
        if String.downcase(pubkey) == String.downcase(expected_pubkey) do
          :ok
        else
          {:error, "pubkey mismatch"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helpers

  defp extract_from_response(%{"names" => names} = body, local_part) when is_map(names) do
    case Map.get(names, local_part) do
      nil ->
        {:error, "name not found"}

      pubkey when is_binary(pubkey) ->
        relays = extract_relays(body, pubkey)
        {:ok, pubkey, relays}

      _invalid ->
        {:error, "invalid pubkey format"}
    end
  end

  defp extract_from_response(_body, _local_part), do: {:error, "missing names field"}

  defp extract_relays(%{"relays" => relays}, pubkey) when is_map(relays) do
    case Map.get(relays, pubkey) do
      urls when is_list(urls) -> urls
      _other -> []
    end
  end

  defp extract_relays(_body, _pubkey), do: []

  defp ensure_req! do
    if not Code.ensure_loaded?(Req) do
      raise """
      The :req dependency is required for HTTP verification.
      Add {:req, "~> 0.5"} to your mix.exs dependencies.
      """
    end
  end
end
