defmodule Nostr.Event.ReleaseArtifactSets do
  @moduledoc """
  Release Artifact Sets (Kind 30063)

  Groups of artifacts of a software release. Contains `e` tags for file metadata
  events (kind:1063) and `a` tags for the parent software application event.

  The `d` tag typically follows the format `com.example.app@version`.

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  alias Nostr.Event
  alias Nostr.NIP51
  alias Nostr.Tag

  defstruct [:event, :identifier, :release_notes, artifacts: [], application: nil]

  @type t() :: %__MODULE__{
          event: Event.t(),
          identifier: binary(),
          release_notes: binary() | nil,
          artifacts: [binary()],
          application: binary() | nil
        }

  @doc """
  Parses a kind 30063 event into a `ReleaseArtifactSets` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 30_063, content: content} = event) do
    # The 'a' tag points to the parent software application
    application =
      case NIP51.get_tag_values(event, :a) do
        [app | _rest] -> app
        [] -> nil
      end

    %__MODULE__{
      event: event,
      identifier: NIP51.get_identifier(event),
      release_notes: if(content == "", do: nil, else: content),
      artifacts: NIP51.get_tag_values(event, :e),
      application: application
    }
  end

  @doc """
  Creates a new release artifact set (kind 30063).

  ## Arguments

    - `identifier` - Release identifier, typically `app.id@version`
    - `artifacts` - List of file metadata event IDs (kind:1063)
    - `opts` - Optional event arguments

  ## Options

    - `:application` - Reference to parent software application event (a tag)
    - `:release_notes` - Markdown release notes (stored in content)
    - `:pubkey` - Event author pubkey
    - `:created_at` - Event timestamp

  ## Example

      ReleaseArtifactSets.create("com.example.app@0.0.1", [
        "windows_exe_file_metadata_id",
        "macos_dmg_file_metadata_id",
        "linux_appimage_file_metadata_id"
      ],
        application: "32267:pubkey:com.example.app",
        release_notes: "## What's New\\n- Bug fixes\\n- Performance improvements"
      )
  """
  @spec create(binary(), [binary()], Keyword.t()) :: t()
  def create(identifier, artifacts, opts \\ [])
      when is_binary(identifier) and is_list(artifacts) do
    {application, opts} = Keyword.pop(opts, :application)
    {release_notes, opts} = Keyword.pop(opts, :release_notes, "")

    artifact_tags = Enum.map(artifacts, &Tag.create(:e, &1))
    app_tags = if application, do: [Tag.create(:a, application)], else: []

    tags = [Tag.create(:d, identifier)] ++ artifact_tags ++ app_tags

    opts = Keyword.merge(opts, tags: tags, content: release_notes)

    30_063
    |> Event.create(opts)
    |> parse()
  end
end
