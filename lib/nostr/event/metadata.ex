defmodule Nostr.Event.Metadata do
  @moduledoc """
  Set metadata

  Defined in NIP 01
  https://github.com/nostr-protocol/nips/blob/master/01.md
  """
  @moduledoc tags: [:event, :nip01], nip: 01

  defstruct [:event, :user, :name, :about, :picture, :nip05, :other]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          user: <<_::32, _::_*8>>,
          name: String.t(),
          about: String.t(),
          picture: URI.t(),
          nip05: String.t(),
          other: map()
        }

  @doc """
  Parse generic `Nostr.Event` to `Nostr.Event.Metadata` struct
  """
  @spec parse(event :: Nostr.Event.t()) :: t()
  def parse(%Nostr.Event{kind: 0} = event) do
    case Jason.decode(event.content, keys: :atoms) do
      {:ok, content} ->
        %__MODULE__{
          event: event,
          user: event.pubkey,
          name: Map.get(content, :name),
          about: Map.get(content, :about),
          picture: Map.get(content, :picture) |> URI.parse(),
          nip05: Map.get(content, :nip05),
          other: Map.drop(content, [:name, :about, :picture, :nip05])
        }

      {:error, %Jason.DecodeError{}} ->
        {:error, "Cannot decode content field", event}
    end
  end

  @doc """
  Create new `Nostr.Event.Metadata` struct

  ## Arguments:

    - `name` - username
    - `about`
    - `picture` - `URI` struct or just `String` URL
    - `nip05` - NIP-05 identifier
    - `opts` - keyword list of other optional event params (`pubkey`, `created_at`, `tags`)

  """
  @spec create(
          name :: String.t(),
          about :: String.t(),
          picture :: URI.t() | String.t(),
          nip05 :: String.t(),
          opts :: Keyword.t()
        ) :: t()
  def create(name, about, picture, nip05, opts \\ [])

  def create(name, about, %URI{} = picture, nip05, opts),
    do: create(name, about, URI.to_string(picture), nip05, opts)

  def create(name, about, picture, nip05, opts) do
    content =
      Jason.encode!(%{
        name: name,
        about: about,
        picture: picture,
        nip05: nip05
      })

    opts = Keyword.put(opts, :content, content)

    0
    |> Nostr.Event.create(opts)
    |> parse()
  end
end
