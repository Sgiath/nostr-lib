defmodule Nostr.NIP05Test do
  use ExUnit.Case, async: true

  alias Nostr.NIP05

  doctest Nostr.NIP05

  describe "parse/1" do
    test "parses valid identifier" do
      assert {:ok, "bob", "example.com"} = NIP05.parse("bob@example.com")
    end

    test "parses identifier with subdomain" do
      assert {:ok, "alice", "sub.domain.co"} = NIP05.parse("alice@sub.domain.co")
    end

    test "parses root identifier" do
      assert {:ok, "_", "bob.com"} = NIP05.parse("_@bob.com")
    end

    test "parses identifier with numbers and special chars" do
      assert {:ok, "alice_123.test-user", "domain.com"} =
               NIP05.parse("alice_123.test-user@domain.com")
    end

    test "returns error for missing @" do
      assert {:error, "missing @ separator"} = NIP05.parse("bobexample.com")
    end

    test "returns error for empty local-part" do
      assert {:error, "empty local-part"} = NIP05.parse("@example.com")
    end

    test "returns error for empty domain" do
      assert {:error, "empty domain"} = NIP05.parse("bob@")
    end

    test "returns error for multiple @" do
      assert {:error, "multiple @ characters"} = NIP05.parse("bob@foo@example.com")
    end

    test "returns error for non-string" do
      assert {:error, "identifier must be a string"} = NIP05.parse(123)
      assert {:error, "identifier must be a string"} = NIP05.parse(nil)
    end
  end

  describe "valid?/1" do
    test "accepts valid identifiers" do
      assert NIP05.valid?("bob@example.com")
      assert NIP05.valid?("alice_123@domain.co")
      assert NIP05.valid?("_@bob.com")
      assert NIP05.valid?("user.name@example.com")
      assert NIP05.valid?("test-user@example.com")
    end

    test "accepts uppercase (case-insensitive)" do
      assert NIP05.valid?("Bob@Example.com")
      assert NIP05.valid?("ALICE@DOMAIN.COM")
    end

    test "rejects invalid characters in local-part" do
      refute NIP05.valid?("bob!@example.com")
      refute NIP05.valid?("alice#test@domain.com")
      refute NIP05.valid?("user name@example.com")
      refute NIP05.valid?("user@name@example.com")
    end

    test "rejects malformed identifiers" do
      refute NIP05.valid?("bobexample.com")
      refute NIP05.valid?("@example.com")
      refute NIP05.valid?("bob@")
      refute NIP05.valid?("")
    end

    test "rejects non-strings" do
      refute NIP05.valid?(123)
      refute NIP05.valid?(nil)
      refute NIP05.valid?(%{})
    end
  end

  describe "verification_url/1" do
    test "builds correct URL" do
      assert {:ok, url} = NIP05.verification_url("bob@example.com")
      assert URI.to_string(url) == "https://example.com/.well-known/nostr.json?name=bob"
    end

    test "builds URL for root identifier" do
      assert {:ok, url} = NIP05.verification_url("_@domain.com")
      assert URI.to_string(url) == "https://domain.com/.well-known/nostr.json?name=_"
    end

    test "URL-encodes special characters" do
      assert {:ok, url} = NIP05.verification_url("test.user@example.com")
      assert URI.to_string(url) == "https://example.com/.well-known/nostr.json?name=test.user"
    end

    test "returns error for invalid identifier" do
      assert {:error, _reason} = NIP05.verification_url("invalid")
    end
  end

  describe "display/1" do
    test "returns full identifier for regular names" do
      assert NIP05.display("bob@example.com") == "bob@example.com"
      assert NIP05.display("alice@domain.co") == "alice@domain.co"
    end

    test "returns just domain for root identifier" do
      assert NIP05.display("_@bob.com") == "bob.com"
      assert NIP05.display("_@example.com") == "example.com"
    end

    test "returns invalid input unchanged" do
      assert NIP05.display("invalid") == "invalid"
      assert NIP05.display("") == ""
    end

    test "handles non-strings" do
      assert NIP05.display(nil) == nil
      assert NIP05.display(123) == 123
    end
  end

  describe "resolve/1" do
    @tag :nip05_http
    test "resolves valid identifier with names only" do
      Req.Test.stub(:nip05, fn conn ->
        body =
          JSON.encode!(%{
            "names" => %{
              "bob" => "b0635d6a9851d3aed0cd6c495b282167acf761729078d975fc341b22650b07b9"
            }
          })

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, body)
      end)

      assert {:ok, pubkey, relays} =
               NIP05.resolve("bob@example.com", plug: {Req.Test, :nip05})

      assert pubkey == "b0635d6a9851d3aed0cd6c495b282167acf761729078d975fc341b22650b07b9"
      assert relays == []
    end

    @tag :nip05_http
    test "resolves identifier with relays" do
      Req.Test.stub(:nip05, fn conn ->
        body =
          JSON.encode!(%{
            "names" => %{
              "bob" => "b0635d6a9851d3aed0cd6c495b282167acf761729078d975fc341b22650b07b9"
            },
            "relays" => %{
              "b0635d6a9851d3aed0cd6c495b282167acf761729078d975fc341b22650b07b9" => [
                "wss://relay.example.com",
                "wss://relay2.example.com"
              ]
            }
          })

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, body)
      end)

      assert {:ok, _pubkey, relays} =
               NIP05.resolve("bob@example.com", plug: {Req.Test, :nip05})

      assert relays == ["wss://relay.example.com", "wss://relay2.example.com"]
    end

    @tag :nip05_http
    test "returns error when name not found" do
      Req.Test.stub(:nip05, fn conn ->
        body = JSON.encode!(%{"names" => %{"alice" => "somepubkey"}})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, body)
      end)

      assert {:error, "name not found"} =
               NIP05.resolve("bob@example.com", plug: {Req.Test, :nip05})
    end

    @tag :nip05_http
    test "returns error on redirect" do
      Req.Test.stub(:nip05, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "https://evil.com/nostr.json")
        |> Plug.Conn.send_resp(302, "")
      end)

      assert {:error, "redirects not allowed"} =
               NIP05.resolve("bob@example.com", plug: {Req.Test, :nip05})
    end

    @tag :nip05_http
    test "returns error on HTTP error" do
      Req.Test.stub(:nip05, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, "{}")
      end)

      assert {:error, "HTTP 404"} =
               NIP05.resolve("bob@example.com", plug: {Req.Test, :nip05})
    end

    @tag :nip05_http
    test "returns error on missing names field" do
      Req.Test.stub(:nip05, fn conn ->
        body = JSON.encode!(%{"other" => "data"})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, body)
      end)

      assert {:error, "missing names field"} =
               NIP05.resolve("bob@example.com", plug: {Req.Test, :nip05})
    end

    test "returns error for invalid identifier" do
      assert {:error, "missing @ separator"} = NIP05.resolve("invalid")
    end
  end

  describe "verify/2" do
    @tag :nip05_http
    test "returns :ok when pubkey matches" do
      expected = "b0635d6a9851d3aed0cd6c495b282167acf761729078d975fc341b22650b07b9"

      Req.Test.stub(:nip05, fn conn ->
        body = JSON.encode!(%{"names" => %{"bob" => expected}})

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, body)
      end)

      assert :ok = NIP05.verify("bob@example.com", expected, plug: {Req.Test, :nip05})
    end

    @tag :nip05_http
    test "returns :ok with case-insensitive pubkey match" do
      Req.Test.stub(:nip05, fn conn ->
        body =
          JSON.encode!(%{
            "names" => %{
              "bob" => "B0635D6A9851D3AED0CD6C495B282167ACF761729078D975FC341B22650B07B9"
            }
          })

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, body)
      end)

      assert :ok =
               NIP05.verify(
                 "bob@example.com",
                 "b0635d6a9851d3aed0cd6c495b282167acf761729078d975fc341b22650b07b9",
                 plug: {Req.Test, :nip05}
               )
    end

    @tag :nip05_http
    test "returns error when pubkey doesn't match" do
      Req.Test.stub(:nip05, fn conn ->
        body =
          JSON.encode!(%{
            "names" => %{
              "bob" => "b0635d6a9851d3aed0cd6c495b282167acf761729078d975fc341b22650b07b9"
            }
          })

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, body)
      end)

      assert {:error, "pubkey mismatch"} =
               NIP05.verify("bob@example.com", "different_pubkey", plug: {Req.Test, :nip05})
    end

    @tag :nip05_http
    test "returns error when resolve fails" do
      Req.Test.stub(:nip05, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, "{}")
      end)

      assert {:error, "HTTP 404"} =
               NIP05.verify("bob@example.com", "any_pubkey", plug: {Req.Test, :nip05})
    end
  end
end
