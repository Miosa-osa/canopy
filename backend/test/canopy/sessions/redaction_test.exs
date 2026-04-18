defmodule Canopy.Sessions.RedactionTest do
  @moduledoc """
  Tests for `Canopy.Sessions.Redaction`.

  Each credential pattern has:
    - a positive case (the credential is redacted)
    - a negative case (benign text passes through untouched)
    - a nested-map case (redaction walks into nested structures)
  """

  use ExUnit.Case, async: true

  alias Canopy.Sessions.Redaction

  # ---------------------------------------------------------------------------
  # AWS access keys
  # ---------------------------------------------------------------------------

  describe "AWS access key (AKIA...)" do
    test "redacts a valid AWS access key" do
      input = "Key: AKIAIOSFODNN7EXAMPLE"
      result = Redaction.scrub(input)
      assert result =~ "***REDACTED_AWS_KEY***"
      refute result =~ "AKIAIOSFODNN7EXAMPLE"
    end

    test "passes through text that merely starts with AKIA but is too short" do
      # AKIA followed by only 4 chars — does not match the 16 [A-Z0-9] requirement
      input = "AKIA1234"
      assert Redaction.scrub(input) == input
    end

    test "redacts AWS key embedded in a nested map" do
      input = %{"config" => %{"aws_key" => "AKIAIOSFODNN7EXAMPLE"}}
      result = Redaction.scrub(input)
      assert result["config"]["aws_key"] =~ "***REDACTED_AWS_KEY***"
    end
  end

  # ---------------------------------------------------------------------------
  # Anthropic keys
  # ---------------------------------------------------------------------------

  describe "Anthropic key (sk-ant-...)" do
    test "redacts a valid Anthropic key" do
      input = "ANTHROPIC_API_KEY=sk-ant-api03-abcdefghijklmnopqrstuvwx"
      result = Redaction.scrub(input)
      assert result =~ "***REDACTED_ANTHROPIC_KEY***"
      refute result =~ "sk-ant-api03-abcdefghijklmnopqrstuvwx"
    end

    test "passes through sk-ant- prefix that is too short" do
      input = "sk-ant-short"
      assert Redaction.scrub(input) == input
    end

    test "redacts Anthropic key in nested map" do
      input = %{"env" => %{"key" => "sk-ant-api03-abcdefghijklmnopqrstu"}}
      result = Redaction.scrub(input)
      assert result["env"]["key"] =~ "***REDACTED_ANTHROPIC_KEY***"
    end
  end

  # ---------------------------------------------------------------------------
  # Generic API keys (sk-...)
  # ---------------------------------------------------------------------------

  describe "Generic API key (sk-...)" do
    test "redacts a valid sk- key" do
      input = "OPENAI_API_KEY=sk-projABCDEFGHIJKLMNOPQRSTUVWXYZ"
      result = Redaction.scrub(input)
      assert result =~ "***REDACTED_API_KEY***"
      refute result =~ "sk-projABCDEFGHIJKLMNOPQRSTUVWXYZ"
    end

    test "passes through sk- prefix that is too short" do
      input = "sk-short"
      assert Redaction.scrub(input) == input
    end

    test "redacts generic key in nested map" do
      input = %{"tool_args" => %{"api_key" => "sk-abcdefghijklmnopqrstuv"}}
      result = Redaction.scrub(input)
      assert result["tool_args"]["api_key"] =~ "***REDACTED_API_KEY***"
    end
  end

  # ---------------------------------------------------------------------------
  # GitHub tokens
  # ---------------------------------------------------------------------------

  describe "GitHub tokens (ghp_, gho_, ghs_, ghu_)" do
    test "redacts ghp_ personal access token" do
      input = "token: ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabc"
      result = Redaction.scrub(input)
      assert result =~ "***REDACTED_GITHUB_TOKEN***"
      refute result =~ "ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabc"
    end

    test "redacts gho_ OAuth token" do
      input = "gho_ABCDEFGHIJKLMNOPQRSTUVWXYZabc"
      result = Redaction.scrub(input)
      assert result =~ "***REDACTED_GITHUB_TOKEN***"
    end

    test "redacts ghs_ server-to-server token" do
      input = "ghs_ABCDEFGHIJKLMNOPQRSTUVWXYZabc"
      result = Redaction.scrub(input)
      assert result =~ "***REDACTED_GITHUB_TOKEN***"
    end

    test "redacts ghu_ user token" do
      input = "ghu_ABCDEFGHIJKLMNOPQRSTUVWXYZabc"
      result = Redaction.scrub(input)
      assert result =~ "***REDACTED_GITHUB_TOKEN***"
    end

    test "passes through ghp_ prefix that is too short" do
      input = "ghp_short"
      assert Redaction.scrub(input) == input
    end

    test "redacts GitHub token in nested map" do
      input = %{"github" => %{"token" => "ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabc"}}
      result = Redaction.scrub(input)
      assert result["github"]["token"] =~ "***REDACTED_GITHUB_TOKEN***"
    end
  end

  # ---------------------------------------------------------------------------
  # Google API keys
  # ---------------------------------------------------------------------------

  describe "Google API key (AIza...)" do
    test "redacts a valid Google API key" do
      input = "GOOGLE_KEY=AIzaSyAbcdefghijklmnopqrstuv"
      result = Redaction.scrub(input)
      assert result =~ "***REDACTED_GOOGLE_KEY***"
      refute result =~ "AIzaSyAbcdefghijklmnopqrstuv"
    end

    test "passes through AIza prefix that is too short" do
      input = "AIzaShort"
      assert Redaction.scrub(input) == input
    end

    test "redacts Google key in nested map" do
      input = %{"maps" => %{"key" => "AIzaSyAbcdefghijklmnopqrstuv"}}
      result = Redaction.scrub(input)
      assert result["maps"]["key"] =~ "***REDACTED_GOOGLE_KEY***"
    end
  end

  # ---------------------------------------------------------------------------
  # Bearer tokens
  # ---------------------------------------------------------------------------

  describe "Bearer token (Authorization: Bearer ...)" do
    test "redacts a Bearer token" do
      input = "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9abcdefghij"
      result = Redaction.scrub(input)
      assert result =~ "Bearer ***REDACTED***"
      refute result =~ "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9abcdefghij"
    end

    test "passes through Bearer with a payload shorter than 20 chars" do
      input = "Bearer short"
      assert Redaction.scrub(input) == input
    end

    test "redacts Bearer token in nested map" do
      input = %{"headers" => %{"authorization" => "Bearer abcdefghijklmnopqrstuvwxyz"}}
      result = Redaction.scrub(input)
      assert result["headers"]["authorization"] =~ "Bearer ***REDACTED***"
    end
  end

  # ---------------------------------------------------------------------------
  # Private key blocks
  # ---------------------------------------------------------------------------

  describe "Private key PEM block" do
    test "redacts RSA private key block" do
      input = """
      -----BEGIN RSA PRIVATE KEY-----
      MIIEowIBAAKCAQEA0Z3VS5JJcds3xHn/ygWep4
      -----END RSA PRIVATE KEY-----
      """

      result = Redaction.scrub(input)
      assert result =~ "***REDACTED_PRIVATE_KEY***"
      refute result =~ "MIIEowIBAAKCAQEA0Z3VS5JJcds3xHn"
    end

    test "redacts OPENSSH private key block" do
      input = """
      -----BEGIN OPENSSH PRIVATE KEY-----
      b3BlbnNzaC1rZXktdjEAAAAA
      -----END OPENSSH PRIVATE KEY-----
      """

      result = Redaction.scrub(input)
      assert result =~ "***REDACTED_PRIVATE_KEY***"
    end

    test "passes through public key block (not a PRIVATE KEY header)" do
      input = """
      -----BEGIN PUBLIC KEY-----
      MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA
      -----END PUBLIC KEY-----
      """

      assert Redaction.scrub(input) == input
    end

    test "redacts private key in nested map" do
      key = "-----BEGIN RSA PRIVATE KEY-----\nMIIABC\n-----END RSA PRIVATE KEY-----"
      input = %{"credentials" => %{"private_key" => key}}
      result = Redaction.scrub(input)
      assert result["credentials"]["private_key"] =~ "***REDACTED_PRIVATE_KEY***"
    end
  end

  # ---------------------------------------------------------------------------
  # JWT tokens
  # ---------------------------------------------------------------------------

  describe "JWT (eyJ...)" do
    test "redacts a well-formed JWT" do
      input =
        "token: eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV"

      result = Redaction.scrub(input)
      assert result =~ "***REDACTED_JWT***"
      refute result =~ "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9"
    end

    test "passes through a string that starts with eyJ but has no second dot segment" do
      input = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9onlyone"
      assert Redaction.scrub(input) == input
    end

    test "redacts JWT in nested map" do
      jwt =
        "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c2VyXzEyMyIsIm5hbWUiOiJUZXN0VXNlciJ9.SflKxwRJSMeKKF2QT4fwpMe"

      input = %{"auth" => %{"token" => jwt}}
      result = Redaction.scrub(input)
      assert result["auth"]["token"] =~ "***REDACTED_JWT***"
    end
  end

  # ---------------------------------------------------------------------------
  # Structural walking
  # ---------------------------------------------------------------------------

  describe "structural traversal" do
    test "scrubs binaries in a flat list" do
      input = ["hello", "sk-abcdefghijklmnopqrstuv", "world"]
      result = Redaction.scrub(input)
      assert Enum.at(result, 0) == "hello"
      assert Enum.at(result, 1) =~ "***REDACTED_API_KEY***"
      assert Enum.at(result, 2) == "world"
    end

    test "passes integers, booleans, and nil through unchanged" do
      assert Redaction.scrub(42) == 42
      assert Redaction.scrub(true) == true
      assert Redaction.scrub(nil) == nil
    end

    test "scrubs a deeply nested map" do
      input = %{
        "level1" => %{
          "level2" => %{
            "secret" => "sk-abcdefghijklmnopqrstuv"
          }
        }
      }

      result = Redaction.scrub(input)
      assert result["level1"]["level2"]["secret"] =~ "***REDACTED_API_KEY***"
    end

    test "multiple credentials in one string are all redacted" do
      input = "aws=AKIAIOSFODNN7EXAMPLE token=sk-abcdefghijklmnopqrstuv"
      result = Redaction.scrub(input)
      assert result =~ "***REDACTED_AWS_KEY***"
      assert result =~ "***REDACTED_API_KEY***"
    end

    test "benign strings are returned unchanged" do
      input = "The quick brown fox jumps over the lazy dog."
      assert Redaction.scrub(input) == input
    end

    test "empty string passes through unchanged" do
      assert Redaction.scrub("") == ""
    end

    test "empty map passes through unchanged" do
      assert Redaction.scrub(%{}) == %{}
    end
  end
end
