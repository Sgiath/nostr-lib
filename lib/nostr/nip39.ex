defmodule Nostr.NIP39 do
  @moduledoc """
  NIP-39: External Identities in Profiles

  Adds `i` tags to kind 0 metadata events for external identity verification.

  ## Tag Format

      ["i", "platform:identity", "proof"]

  ## Supported Platforms

  - `github` - GitHub username, proof is a Gist ID
  - `twitter` - Twitter username, proof is a Tweet ID
  - `mastodon` - Mastodon `instance/@username`, proof is a Post ID
  - `telegram` - Telegram user ID, proof is `channel/message_id`

  ## Examples

      # Extract identities from event tags
      identities = NIP39.from_tags(event.tags)
      # => [%{platform: "github", identity: "alice", proof: "abc123"}]

      # Build i tags from identity list
      tags = NIP39.build_tags([
        %{platform: "github", identity: "alice", proof: "abc123"}
      ])
      # => [%Tag{type: :i, data: "github:alice", info: ["abc123"]}]

      # Get proof verification URL
      NIP39.proof_url(%{platform: "github", identity: "alice", proof: "abc123"})
      # => "https://gist.github.com/alice/abc123"

  See: https://github.com/nostr-protocol/nips/blob/master/39.md
  """
  @moduledoc tags: [:nip39], nip: 39

  alias Nostr.Tag

  @typedoc "External identity with platform, identity, and proof"
  @type identity() :: %{
          platform: String.t(),
          identity: String.t(),
          proof: String.t()
        }

  @supported_platforms ["github", "twitter", "mastodon", "telegram"]

  @doc """
  Extracts external identities from `i` tags.

  ## Examples

      tags = [
        %Tag{type: :i, data: "github:alice", info: ["abc123"]},
        %Tag{type: :p, data: "pubkey123", info: []}
      ]
      NIP39.from_tags(tags)
      # => [%{platform: "github", identity: "alice", proof: "abc123"}]

  """
  @spec from_tags([Tag.t()]) :: [identity()]
  def from_tags(tags) when is_list(tags) do
    tags
    |> Enum.filter(&(&1.type == :i))
    |> Enum.map(&parse_identity_tag/1)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Builds `i` tags from a list of identities.

  ## Examples

      NIP39.build_tags([
        %{platform: "github", identity: "alice", proof: "abc123"},
        %{platform: "twitter", identity: "bob", proof: "12345"}
      ])

  """
  @spec build_tags([identity()] | [map()]) :: [Tag.t()]
  def build_tags(nil), do: []

  def build_tags(identities) when is_list(identities) do
    identities
    |> Enum.map(&to_tag/1)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Creates a single `i` tag from an identity map.

  ## Examples

      NIP39.to_tag(%{platform: "github", identity: "alice", proof: "abc123"})
      # => %Tag{type: :i, data: "github:alice", info: ["abc123"]}

  """
  @spec to_tag(identity() | map()) :: Tag.t() | nil
  def to_tag(%{platform: platform, identity: id, proof: proof})
      when is_binary(platform) and is_binary(id) and is_binary(proof) do
    Tag.create(:i, "#{platform}:#{id}", [proof])
  end

  def to_tag(_), do: nil

  @doc """
  Parses a "platform:identity" string.

  ## Examples

      NIP39.parse("github:alice")
      # => {:ok, {"github", "alice"}}

      NIP39.parse("mastodon:bitcoinhackers.org/@alice")
      # => {:ok, {"mastodon", "bitcoinhackers.org/@alice"}}

      NIP39.parse("invalid")
      # => :error

  """
  @spec parse(binary()) :: {:ok, {platform :: binary(), identity :: binary()}} | :error
  def parse(platform_identity) when is_binary(platform_identity) do
    case String.split(platform_identity, ":", parts: 2) do
      [platform, identity] when platform != "" and identity != "" ->
        {:ok, {platform, identity}}

      _ ->
        :error
    end
  end

  @doc """
  Checks if a platform name is in the list of supported platforms.

  ## Examples

      NIP39.supported_platform?("github")
      # => true

      NIP39.supported_platform?("unknown")
      # => false

  """
  @spec supported_platform?(binary()) :: boolean()
  def supported_platform?(platform) when is_binary(platform) do
    platform in @supported_platforms
  end

  @doc """
  Returns the list of supported platforms.
  """
  @spec supported_platforms() :: [String.t()]
  def supported_platforms, do: @supported_platforms

  @doc """
  Builds a verification URL for the given identity.

  Returns the URL where the proof can be verified, or `nil` if the platform
  is not supported or the identity format is invalid.

  ## Examples

      NIP39.proof_url(%{platform: "github", identity: "alice", proof: "abc123"})
      # => "https://gist.github.com/alice/abc123"

      NIP39.proof_url(%{platform: "twitter", identity: "alice", proof: "12345"})
      # => "https://twitter.com/alice/status/12345"

      NIP39.proof_url(%{platform: "mastodon", identity: "bitcoinhackers.org/@alice", proof: "67890"})
      # => "https://bitcoinhackers.org/@alice/67890"

      NIP39.proof_url(%{platform: "telegram", identity: "12345", proof: "channel/678"})
      # => "https://t.me/channel/678"

  """
  @spec proof_url(identity() | map()) :: binary() | nil
  def proof_url(%{platform: "github", identity: identity, proof: proof}) do
    "https://gist.github.com/#{identity}/#{proof}"
  end

  def proof_url(%{platform: "twitter", identity: identity, proof: proof}) do
    "https://twitter.com/#{identity}/status/#{proof}"
  end

  def proof_url(%{platform: "mastodon", identity: identity, proof: proof}) do
    "https://#{identity}/#{proof}"
  end

  def proof_url(%{platform: "telegram", proof: proof}) do
    "https://t.me/#{proof}"
  end

  def proof_url(_), do: nil

  # Private functions

  defp parse_identity_tag(%Tag{type: :i, data: platform_identity, info: [proof | _]})
       when is_binary(platform_identity) and is_binary(proof) do
    case parse(platform_identity) do
      {:ok, {platform, identity}} ->
        %{platform: platform, identity: identity, proof: proof}

      :error ->
        nil
    end
  end

  defp parse_identity_tag(%Tag{type: :i, data: platform_identity, info: []})
       when is_binary(platform_identity) do
    # Handle i tags without proof (NIP says clients SHOULD process tags with >2 values)
    case parse(platform_identity) do
      {:ok, {platform, identity}} ->
        %{platform: platform, identity: identity, proof: ""}

      :error ->
        nil
    end
  end

  defp parse_identity_tag(_), do: nil
end
