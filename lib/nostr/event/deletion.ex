defmodule Nostr.Event.Deletion do
  @moduledoc """
  Event deletion request

  Defined in NIP 09
  https://github.com/nostr-protocol/nips/blob/master/09.md
  """
  @moduledoc tags: [:event, :nip09], nip: 09

  defstruct [:event, :user, :to_delete, :to_delete_naddr, :kinds, :reason]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          user: <<_::32, _::_*8>>,
          to_delete: [binary()],
          to_delete_naddr: [binary()],
          kinds: [non_neg_integer()],
          reason: String.t() | nil
        }

  @doc """
  Create a new deletion request (kind 5) event.

  ## Arguments:

    - `events` - list of event IDs to delete
    - `opts` - optional arguments:
      - `:reason` - text describing why events are being deleted
      - `:naddrs` - list of replaceable event addresses ("kind:pubkey:d-identifier")
      - `:kinds` - list of event kinds being deleted (SHOULD be included per NIP-09)
      - plus standard event opts (`pubkey`, `created_at`)

  ## Examples

      # Delete specific events
      Nostr.Event.Deletion.create(["event_id_1", "event_id_2"], reason: "posted by mistake")

      # Delete replaceable events
      Nostr.Event.Deletion.create([], naddrs: ["30023:pubkey:article-1"], kinds: [30023])

  """
  @spec create(events :: [binary()], opts :: Keyword.t()) :: t()
  def create(events, opts \\ []) do
    {reason, opts} = Keyword.pop(opts, :reason)
    {naddrs, opts} = Keyword.pop(opts, :naddrs, [])
    {kinds, opts} = Keyword.pop(opts, :kinds, [])

    tags =
      build_e_tags(events) ++
        build_a_tags(naddrs) ++
        build_k_tags(kinds)

    content = reason || ""
    opts = Keyword.merge(opts, tags: tags, content: content)

    5
    |> Nostr.Event.create(opts)
    |> parse()
  end

  @doc "Parses a kind 5 event into a `Deletion` struct."
  @spec parse(event :: Nostr.Event.t()) :: t()
  def parse(%Nostr.Event{kind: 5} = event) do
    %__MODULE__{
      event: event,
      user: event.pubkey,
      to_delete: get_e_tags(event),
      to_delete_naddr: get_a_tags(event),
      kinds: get_k_tags(event),
      reason: parse_reason(event.content)
    }
  end

  defp get_e_tags(%Nostr.Event{tags: tags}) do
    tags
    |> Enum.filter(&(&1.type == :e))
    |> Enum.map(& &1.data)
  end

  defp get_a_tags(%Nostr.Event{tags: tags}) do
    tags
    |> Enum.filter(&(&1.type == :a))
    |> Enum.map(& &1.data)
  end

  defp get_k_tags(%Nostr.Event{tags: tags}) do
    tags
    |> Enum.filter(&(&1.type == :k))
    |> Enum.map(&parse_kind/1)
  end

  defp parse_kind(%Nostr.Tag{data: kind}) when is_binary(kind), do: String.to_integer(kind)
  defp parse_kind(%Nostr.Tag{data: kind}) when is_integer(kind), do: kind

  defp parse_reason(""), do: nil
  defp parse_reason(content), do: content

  defp build_e_tags(events) do
    Enum.map(events, &Nostr.Tag.create(:e, &1))
  end

  defp build_a_tags(naddrs) do
    Enum.map(naddrs, &Nostr.Tag.create(:a, &1))
  end

  defp build_k_tags(kinds) do
    Enum.map(kinds, &Nostr.Tag.create(:k, to_string(&1)))
  end
end
