defmodule Nostr.Event.FileMetadata do
  @moduledoc """
  File metadata

  Defined in NIP 94
  https://github.com/nostr-protocol/nips/blob/master/94.md
  """
  @moduledoc tags: [:event, :nip94], nip: 94

  @enforce_keys [:event, :url, :description, :mime, :hash]
  defstruct [
    :event,
    :url,
    :mime,
    :description,
    :aes_256_gcm,
    :hash,
    :size,
    :dim,
    :magnet,
    :info_hash,
    :blur_hash
  ]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          url: URI.t(),
          mime: String.t(),
          description: String.t(),
          hash: <<_::32, _::_*8>>,
          aes_256_gcm: nil | %{key: binary(), iv: binary()},
          size: nil | non_neg_integer(),
          dim: nil | %{x: non_neg_integer(), y: non_neg_integer()},
          magnet: nil | URI.t(),
          info_hash: nil | <<_::20, _::_*8>>,
          blur_hash: nil | binary()
        }

  @spec parse(event :: Nostr.Event.t()) :: __MODULE__.t()
  def parse(%Nostr.Event{kind: 1063} = event) do
    %__MODULE__{
      event: event,
      url: get_url(event),
      description: event.content,
      mime: get_mime(event),
      hash: get_hash(event),
      aes_256_gcm: get_encryption(event),
      size: get_size(event),
      dim: get_dim(event),
      magnet: get_magnet(event),
      info_hash: get_info_hash(event),
      blur_hash: get_blur_hash(event)
    }
  end

  defp get_url(%Nostr.Event{tags: tags}) do
    Enum.find_value(tags, fn
      %Nostr.Tag{type: :url, data: url} -> URI.parse(url)
      _otherwise -> false
    end)
  end

  defp get_mime(%Nostr.Event{tags: tags}) do
    Enum.find_value(tags, fn
      %Nostr.Tag{type: :m, data: mime} -> mime
      _otherwise -> false
    end)
  end

  defp get_hash(%Nostr.Event{tags: tags}) do
    Enum.find_value(tags, fn
      %Nostr.Tag{type: :x, data: hash} -> hash
      _otherwise -> false
    end)
  end

  defp get_encryption(%Nostr.Event{tags: tags}) do
    Enum.find_value(tags, fn
      %Nostr.Tag{type: :"aes-256-gcm", data: key, info: [iv]} -> %{key: key, iv: iv}
      _otherwise -> nil
    end)
  end

  defp get_size(%Nostr.Event{tags: tags}) do
    Enum.find_value(tags, fn
      %Nostr.Tag{type: :size, data: size} -> size
      _otherwise -> false
    end)
  end

  defp get_dim(%Nostr.Event{tags: tags}) do
    Enum.find_value(tags, fn
      %Nostr.Tag{type: :dim, data: dim} ->
        [x, y] = String.split(dim, "x")
        %{x: String.to_integer(x), y: String.to_integer(y)}

      _otherwise ->
        nil
    end)
  end

  defp get_magnet(%Nostr.Event{tags: tags}) do
    Enum.find_value(tags, fn
      %Nostr.Tag{type: :magnet, data: magnet} -> URI.parse(magnet)
      _otherwise -> false
    end)
  end

  defp get_info_hash(%Nostr.Event{tags: tags}) do
    Enum.find_value(tags, fn
      %Nostr.Tag{type: :i, data: hash} -> hash
      _otherwise -> false
    end)
  end

  defp get_blur_hash(%Nostr.Event{tags: tags}) do
    Enum.find_value(tags, fn
      %Nostr.Tag{type: :blurhash, data: hash} -> hash
      _otherwise -> false
    end)
  end
end
