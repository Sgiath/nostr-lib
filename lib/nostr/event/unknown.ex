defmodule Nostr.Event.Unknown do
  @moduledoc """
  Unknown type of event
  """

  defstruct [:event]

  @type t() :: %__MODULE__{
          event: Nostr.Event.t()
        }
end
