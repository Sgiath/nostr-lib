defmodule Nostr.Event.UserStatus do
  @moduledoc """
  User Statuses (Kind 30315)

  Implements NIP-38 for sharing live user statuses such as what music is playing
  or current activity (working, hiking, etc.).

  ## Status Types

  Two common status types are defined:
  - `general` - General activity statuses ("Working", "Hiking", etc.)
  - `music` - Live streaming what you're listening to

  Any other status types can be used but are not defined by NIP-38.

  ## Examples

      # Create a general status
      UserStatus.general("Working on nostr-lib")

      # Create a music status with expiration
      UserStatus.music("Intergalactic - Beastie Boys",
        url: "spotify:search:Intergalactic%20-%20Beastie%20Boys",
        expiration: DateTime.add(DateTime.utc_now(), 180, :second)
      )

      # Create a status with link
      UserStatus.general("Join my Nostr Nest!",
        url: "https://nostrnests.com/abc123"
      )

      # Clear a status (empty content)
      UserStatus.clear("general")

      # Check if expired
      UserStatus.expired?(status)

  See:
  - https://github.com/nostr-protocol/nips/blob/master/38.md
  - https://github.com/nostr-protocol/nips/blob/master/40.md (expiration)
  - https://github.com/nostr-protocol/nips/blob/master/30.md (custom emoji)
  """
  @moduledoc tags: [:event, :nip38, :nip40], nip: [38, 40]

  alias Nostr.Event
  alias Nostr.Tag

  @kind 30_315

  @type t() :: %__MODULE__{
          event: Event.t(),
          status_type: binary(),
          status: binary(),
          url: binary() | nil,
          profile: binary() | nil,
          note: binary() | nil,
          address: binary() | nil,
          expiration: DateTime.t() | nil,
          emojis: %{binary() => binary()}
        }

  defstruct [
    :event,
    :status_type,
    :status,
    :url,
    :profile,
    :note,
    :address,
    :expiration,
    emojis: %{}
  ]

  @doc """
  Parses a kind 30315 event into a UserStatus struct.
  """
  @spec parse(Event.t()) :: t() | {:error, String.t(), Event.t()}
  def parse(%Event{kind: @kind} = event) do
    %__MODULE__{
      event: event,
      status_type: get_d_tag(event),
      status: event.content,
      url: get_r_tag(event),
      profile: get_p_tag(event),
      note: get_e_tag(event),
      address: get_a_tag(event),
      expiration: get_expiration(event),
      emojis: Nostr.NIP30.from_tags(event.tags)
    }
  end

  def parse(%Event{} = event) do
    {:error, "Event is not a user status (expected kind #{@kind})", event}
  end

  @doc """
  Creates a user status event.

  ## Arguments

  - `status_type` - Status category ("general", "music", or custom)
  - `status` - Status text content (empty string clears the status)
  - `opts` - Optional keyword list

  ## Options

  - `:url` - URL reference (r tag)
  - `:profile` - Profile pubkey reference (p tag)
  - `:note` - Event ID reference (e tag)
  - `:address` - Addressable event coordinates reference (a tag)
  - `:expiration` - DateTime when status expires (NIP-40)
  - `:emojis` - Custom emoji map for NIP-30 (e.g., `%{"wave" => "https://..."}`)
  - `:pubkey` - Author pubkey
  - `:created_at` - Event timestamp

  ## Examples

      UserStatus.create("general", "Working hard!")

      UserStatus.create("music", "Song Name - Artist",
        url: "spotify:track:abc123",
        expiration: DateTime.add(DateTime.utc_now(), 240, :second)
      )

  """
  @spec create(binary(), binary(), keyword()) :: t()
  def create(status_type, status, opts \\ []) do
    tags = build_tags(status_type, opts)

    @kind
    |> Event.create(Keyword.merge(opts, tags: tags, content: status))
    |> parse()
  end

  @doc """
  Creates a general status.

  Convenience function for `create("general", status, opts)`.

  ## Examples

      UserStatus.general("Working on nostr-lib")

      UserStatus.general("In a meeting",
        expiration: DateTime.add(DateTime.utc_now(), 3600, :second)
      )

  """
  @spec general(binary(), keyword()) :: t()
  def general(status, opts \\ []), do: create("general", status, opts)

  @doc """
  Creates a music status.

  Convenience function for `create("music", status, opts)`.

  The expiration should typically be set to when the track stops playing.

  ## Examples

      UserStatus.music("Intergalactic - Beastie Boys",
        url: "spotify:search:Intergalactic%20-%20Beastie%20Boys",
        expiration: DateTime.add(DateTime.utc_now(), 180, :second)
      )

  """
  @spec music(binary(), keyword()) :: t()
  def music(status, opts \\ []), do: create("music", status, opts)

  @doc """
  Clears a status by creating one with empty content.

  ## Examples

      UserStatus.clear("general")
      UserStatus.clear("music")

  """
  @spec clear(binary(), keyword()) :: t()
  def clear(status_type, opts \\ []), do: create(status_type, "", opts)

  @doc """
  Checks if the status has expired.

  Returns `false` if no expiration is set.

  ## Examples

      iex> status = UserStatus.general("test")
      iex> UserStatus.expired?(status)
      false

  """
  @spec expired?(t()) :: boolean()
  def expired?(%__MODULE__{expiration: nil}), do: false

  def expired?(%__MODULE__{expiration: expiration}) do
    DateTime.compare(expiration, DateTime.utc_now()) == :lt
  end

  @doc """
  Returns the status's address coordinates for use in `a` tags.

  Format: `30315:<pubkey>:<status_type>`

  Returns `nil` if pubkey is not set.
  """
  @spec coordinates(t()) :: binary() | nil
  def coordinates(%__MODULE__{event: %Event{pubkey: nil}}), do: nil

  def coordinates(%__MODULE__{event: event, status_type: status_type}) do
    "#{@kind}:#{event.pubkey}:#{status_type}"
  end

  # Private functions

  defp build_tags(status_type, opts) do
    [Tag.create(:d, status_type)] ++
      maybe_r_tag(Keyword.get(opts, :url)) ++
      maybe_p_tag(Keyword.get(opts, :profile)) ++
      maybe_e_tag(Keyword.get(opts, :note)) ++
      maybe_a_tag(Keyword.get(opts, :address)) ++
      maybe_expiration_tag(Keyword.get(opts, :expiration)) ++
      maybe_emoji_tags(Keyword.get(opts, :emojis))
  end

  defp maybe_r_tag(nil), do: []
  defp maybe_r_tag(url), do: [Tag.create(:r, url)]

  defp maybe_p_tag(nil), do: []
  defp maybe_p_tag(pubkey), do: [Tag.create(:p, pubkey)]

  defp maybe_e_tag(nil), do: []
  defp maybe_e_tag(event_id), do: [Tag.create(:e, event_id)]

  defp maybe_a_tag(nil), do: []
  defp maybe_a_tag(address), do: [Tag.create(:a, address)]

  defp maybe_expiration_tag(nil), do: []

  defp maybe_expiration_tag(%DateTime{} = dt) do
    [Tag.create("expiration", Integer.to_string(DateTime.to_unix(dt)))]
  end

  defp maybe_emoji_tags(nil), do: []
  defp maybe_emoji_tags(emojis), do: Nostr.NIP30.build_tags(emojis)

  defp get_d_tag(%Event{tags: tags}) do
    case Enum.find(tags, &(&1.type == :d)) do
      %Tag{data: d} when is_binary(d) -> d
      _no_tag -> ""
    end
  end

  defp get_r_tag(%Event{tags: tags}) do
    case Enum.find(tags, &(&1.type == :r)) do
      %Tag{data: url} -> url
      _no_tag -> nil
    end
  end

  defp get_p_tag(%Event{tags: tags}) do
    case Enum.find(tags, &(&1.type == :p)) do
      %Tag{data: pubkey} -> pubkey
      _no_tag -> nil
    end
  end

  defp get_e_tag(%Event{tags: tags}) do
    case Enum.find(tags, &(&1.type == :e)) do
      %Tag{data: event_id} -> event_id
      _no_tag -> nil
    end
  end

  defp get_a_tag(%Event{tags: tags}) do
    case Enum.find(tags, &(&1.type == :a)) do
      %Tag{data: address} -> address
      _no_tag -> nil
    end
  end

  defp get_expiration(%Event{tags: tags}) do
    case Enum.find(tags, &(to_string(&1.type) == "expiration")) do
      %Tag{data: timestamp} ->
        case Integer.parse(timestamp) do
          {unix, ""} -> DateTime.from_unix!(unix)
          _parse_fail -> nil
        end

      _no_tag ->
        nil
    end
  end
end
