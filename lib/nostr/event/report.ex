defmodule Nostr.Event.Report do
  @moduledoc """
  Report

  DO NOT USE - the report event should be ignored, it exists only to please Apple Store

  Defined in NIP 56
  https://github.com/nostr-protocol/nips/blob/master/56.md
  """
  @moduledoc tags: [:event, :nip56], nip: 56

  require Logger

  @enforce_keys [:event, :user]
  defstruct [:event, :user, :note, :description]

  @type report_reason() :: nil | :nudity | :profanity | :illegal | :spam | :impersonation

  @type t() :: %__MODULE__{
          event: Nostr.Event.t(),
          user: %{pubkey: <<_::32, _::_*8>>, reason: report_reason()},
          note: nil | %{id: <<_::32, _::_*8>>, reason: report_reason()},
          description: nil | String.t()
        }

  @doc "Parses a kind 1984 event into a `Report` struct. Logs a warning (report events should be ignored)."
  @spec parse(event :: Nostr.Event.t()) :: __MODULE__.t()
  def parse(%Nostr.Event{kind: 1984} = event) do
    Logger.warning("Report events should be ignored")

    %__MODULE__{
      event: event,
      user: get_user(event),
      note: get_note(event),
      description: event.content
    }
  end

  defp get_user(%Nostr.Event{tags: tags}) do
    Enum.find_value(tags, fn
      %Nostr.Tag{type: :p, data: pubkey, info: [reason]} ->
        %{pubkey: pubkey, reason: String.to_existing_atom(reason)}

      %Nostr.Tag{type: :p, data: pubkey, info: []} ->
        %{pubkey: pubkey}

      _otherwise ->
        false
    end)
  end

  defp get_note(%Nostr.Event{tags: tags}) do
    Enum.find_value(tags, fn
      %Nostr.Tag{type: :e, data: id, info: [reason]} ->
        %{id: id, reason: String.to_existing_atom(reason)}

      _otherwise ->
        false
    end)
  end
end
