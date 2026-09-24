# frozen_string_literal: true

require "test_helper"

class VerifySessionTokenTest < ActiveSupport::TestCase
  include OauthDummyHelpers

  setup do
    @secret = "channel-signing-secret"
    @audience = "channel-partner-client-id"
    @client, = create_oauth_client(
      name: "Channel App",
      session_token_provider: "channel",
      session_token_audience: @audience,
      session_token_secret: @secret
    )
    @now = Time.zone.parse("2026-09-24 12:00:00 UTC").to_i
  end

  test "accepts a valid token and returns raw claims" do
    token = session_token

    result = RecordingStudioOauth.verify_session_token(
      client_id: @client.client_id,
      token: token,
      now: @now
    )

    assert result.success?
    assert_equal @client.id, result.value.fetch(:client).id
    assert_equal "42", result.value.fetch(:claims)["sub"]
    refute result.value.key?(:external_id)
    refute result.value.key?(:provider)
  end

  test "the registered app id is not the token audience" do
    refute_equal @audience, @client.client_id
    assert_match(/\Arsoauth_oc_/, @client.client_id)
  end

  test "rejects a bad signature" do
    result = RecordingStudioOauth.verify_session_token(
      client: @client,
      token: session_token,
      secret: "wrong-secret",
      now: @now
    )

    assert result.failure?
    assert_equal "bad signature", result.error
    assert_equal [:bad_signature], result.errors
  end

  test "rejects the wrong audience" do
    result = RecordingStudioOauth.verify_session_token(client: @client, token: session_token(aud: "other-app"), now: @now)

    assert result.failure?
    assert_equal "wrong audience", result.error
    assert_equal [:wrong_audience], result.errors
  end

  test "rejects an expired token" do
    result = RecordingStudioOauth.verify_session_token(client: @client, token: session_token(exp: @now - 30), now: @now)

    assert result.failure?
    assert_equal "expired", result.error
    assert_equal [:expired], result.errors
  end

  test "rejects when nbf is in the future" do
    result = RecordingStudioOauth.verify_session_token(client: @client, token: session_token(nbf: @now + 30), now: @now)

    assert result.failure?
    assert_equal "not yet valid", result.error
    assert_equal [:not_yet_valid], result.errors
  end

  test "does not interpret extra claims" do
    token = session_token("iss" => "https://one.example/admin", "dest" => "https://two.example")

    result = RecordingStudioOauth.verify_session_token(client: @client, token: token, now: @now)

    assert result.success?
    assert_equal "https://one.example/admin", result.value.fetch(:claims)["iss"]
    assert_equal "https://two.example", result.value.fetch(:claims)["dest"]
  end

  test "optional expected_external_id compares host-supplied strings" do
    token = session_token

    matched = RecordingStudioOauth.verify_session_token(
      client: @client,
      token: token,
      external_id: "Store-123",
      expected_external_id: "store-123",
      now: @now
    )
    mismatched = RecordingStudioOauth.verify_session_token(
      client: @client,
      token: token,
      external_id: "store-123",
      expected_external_id: "other-store",
      now: @now
    )

    assert matched.success?
    assert mismatched.failure?
    assert_equal "external id does not match", mismatched.error
    assert_equal [:external_id_mismatch], mismatched.errors
  end

  test "fails closed when audience or secret is missing" do
    bare, = create_oauth_client(name: "Bare App")

    result = RecordingStudioOauth.verify_session_token(
      client: bare,
      token: session_token,
      now: @now
    )

    assert result.failure?
    assert_equal "session token verify is not configured", result.error
    assert_equal [:missing_config], result.errors
  end

  test "unknown client id fails" do
    result = RecordingStudioOauth.verify_session_token(
      client_id: "rsoauth_oc_missing",
      token: session_token,
      now: @now
    )

    assert result.failure?
    assert_equal "unknown client", result.error
    assert_equal [:unknown_client], result.errors
  end

  test "revoked client fails" do
    @client.revoke!

    result = RecordingStudioOauth.verify_session_token(client: @client, token: session_token, now: @now)

    assert result.failure?
    assert_equal "client is revoked", result.error
    assert_equal [:revoked], result.errors
  end

  private

  def session_token(aud: @audience, **claims)
    payload = {
      "aud" => aud,
      "sub" => "42",
      "exp" => @now + 60,
      "nbf" => @now - 5,
      "iat" => @now,
      "jti" => "jti-1"
    }.merge(claims.stringify_keys)

    RecordingStudioOauth::Hs256Jwt.encode(payload, @secret)
  end
end
