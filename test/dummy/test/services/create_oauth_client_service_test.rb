# frozen_string_literal: true

require "test_helper"

class CreateOauthClientServiceTest < ActiveSupport::TestCase
  test "creates a public client without a secret" do
    result = RecordingStudioOauth::Services::CreateOauthClient.call(
      name: "Staff Public App",
      redirect_uris: ["http://127.0.0.1/callback"],
      confidential: false
    )

    assert result.success?
    client = result.value.fetch(:client)
    assert_equal "Staff Public App", client.name
    assert_equal "public", client.api_key
    refute client.confidential?
    assert_nil result.value[:client_secret]
    assert_nil client.client_secret_digest
    refute client.self_registered?
    assert_equal "none", client.token_endpoint_auth_method
    assert_match(/\Arsoauth_oc_/, client.client_id)
    refute client.allow_registration?
  end

  test "creates an operations client when that named API exists" do
    result = RecordingStudioOauth::Services::CreateOauthClient.call(
      name: "Staff Ops App",
      redirect_uris: ["https://chatgpt.example/callback"],
      confidential: false,
      api_key: "operations"
    )

    assert result.success?, result.error.to_s
    client = result.value.fetch(:client)
    assert_equal "operations", client.api_key
    assert client.operations?
    refute client.confidential?
  end

  test "rejects an unknown named API" do
    result = RecordingStudioOauth::Services::CreateOauthClient.call(
      name: "Unknown API App",
      redirect_uris: ["https://example.com/callback"],
      confidential: false,
      api_key: "not_a_named_api"
    )

    assert result.failure?
    client = result.errors.first
    assert_includes client.errors[:api_key].join, "is not included in the list"
  end

  test "copies the host registration choice when the caller omits it" do
    previous = RecordingStudioOauth.configuration.allow_registration?
    RecordingStudioOauth.configuration.allow_registration = true

    result = RecordingStudioOauth::Services::CreateOauthClient.call(
      name: "Copied Registration App",
      redirect_uris: ["https://example.com/callback"],
      confidential: false
    )

    assert result.success?
    assert result.value.fetch(:client).allow_registration?
  ensure
    RecordingStudioOauth.configuration.allow_registration = previous
  end

  test "an explicit false does not copy the host registration choice" do
    previous = RecordingStudioOauth.configuration.allow_registration?
    RecordingStudioOauth.configuration.allow_registration = true

    result = RecordingStudioOauth::Services::CreateOauthClient.call(
      name: "Explicit Closed App",
      redirect_uris: ["https://example.com/callback"],
      confidential: false,
      allow_registration: false
    )

    assert result.success?
    refute result.value.fetch(:client).allow_registration?
  ensure
    RecordingStudioOauth.configuration.allow_registration = previous
  end

  test "creates a confidential client with a digest and one-time secret" do
    result = RecordingStudioOauth::Services::CreateOauthClient.call(
      name: "Staff Secret App",
      redirect_uris: ["https://example.com/callback"],
      confidential: true
    )

    assert result.success?
    client = result.value.fetch(:client)
    secret = result.value.fetch(:client_secret)
    assert client.confidential?
    assert_match(/\Arsoauth_cs_/, secret)
    assert_predicate client.client_secret_digest, :present?
    assert_equal "client_secret_basic", client.token_endpoint_auth_method
    refute_equal secret, client.client_secret_digest
    assert client.authenticate_secret?(secret)
  end

  test "stores session token verify fields on create" do
    result = RecordingStudioOauth::Services::CreateOauthClient.call(
      name: "Channel App",
      redirect_uris: ["https://example.com/callback"],
      confidential: false,
      session_token_provider: "channel",
      session_token_audience: "partner-client-id",
      session_token_secret: "channel-api-secret"
    )

    assert result.success?
    client = result.value.fetch(:client)
    assert_equal "channel", client.session_token_provider
    assert_equal "partner-client-id", client.session_token_audience
    assert_equal "channel-api-secret", client.session_token_secret
    assert client.session_token_verify_ready?
  end

  test "rejects a redirect URI with a fragment" do
    result = RecordingStudioOauth::Services::CreateOauthClient.call(
      name: "Bad Redirect",
      redirect_uris: ["https://example.com/callback#oops"],
      confidential: false
    )

    assert result.failure?
    client = result.errors.first
    assert_includes client.errors[:redirect_uris].join, "absolute HTTP(S) URIs without fragments"
  end
end
