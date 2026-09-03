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
    assert_match(/\Arsoauth_oc_/, client.client_id)
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
    refute_equal secret, client.client_secret_digest
    assert client.authenticate_secret?(secret)
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
