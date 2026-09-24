# frozen_string_literal: true

require "test_helper"

class VerifySessionTokenTest < ActiveSupport::TestCase
  include OauthDummyHelpers

  setup do
    @secret = "shopify-api-secret"
    @audience = "shopify-partner-client-id"
    @client, = create_oauth_client(
      name: "Channel App",
      session_token_provider: "shopify",
      session_token_audience: @audience,
      session_token_secret: @secret
    )
    @now = Time.zone.parse("2026-09-24 12:00:00 UTC").to_i
  end

  test "accepts a shopify session token and returns the shop" do
    token = shopify_session_token

    result = RecordingStudioOauth.verify_session_token(
      client_id: @client.client_id,
      token: token,
      now: @now
    )

    assert result.success?
    assert_equal @client.id, result.value.fetch(:client).id
    assert_equal "exampleshop.myshopify.com", result.value.fetch(:external_id)
    assert_equal "shopify", result.value.fetch(:provider)
    assert_equal "42", result.value.fetch(:claims)["sub"]
  end

  test "the registered app id is not the token audience" do
    refute_equal @audience, @client.client_id
    assert_match(/\Arsoauth_oc_/, @client.client_id)
  end

  test "rejects a bad signature" do
    token = shopify_session_token

    result = RecordingStudioOauth.verify_session_token(
      client: @client,
      token: token,
      secret: "wrong-secret",
      now: @now
    )

    assert result.failure?
    assert_equal "bad signature", result.error
    assert_equal [:bad_signature], result.errors
  end

  test "rejects the wrong audience" do
    token = shopify_session_token(aud: "other-app")

    result = RecordingStudioOauth.verify_session_token(client: @client, token: token, now: @now)

    assert result.failure?
    assert_equal "wrong audience", result.error
    assert_equal [:wrong_audience], result.errors
  end

  test "rejects an expired token" do
    token = shopify_session_token(exp: @now - 30)

    result = RecordingStudioOauth.verify_session_token(client: @client, token: token, now: @now)

    assert result.failure?
    assert_equal "expired", result.error
    assert_equal [:expired], result.errors
  end

  test "rejects when nbf is in the future" do
    token = shopify_session_token(nbf: @now + 30)

    result = RecordingStudioOauth.verify_session_token(client: @client, token: token, now: @now)

    assert result.failure?
    assert_equal "not yet valid", result.error
    assert_equal [:not_yet_valid], result.errors
  end

  test "rejects issuer and dest host mismatch" do
    token = shopify_session_token(iss: "https://othershop.myshopify.com/admin")

    result = RecordingStudioOauth.verify_session_token(client: @client, token: token, now: @now)

    assert result.failure?
    assert_equal "issuer and destination do not match", result.error
    assert_equal [:iss_mismatch], result.errors
  end

  test "rejects an expected shop that does not match dest" do
    token = shopify_session_token

    result = RecordingStudioOauth.verify_session_token(
      client: @client,
      token: token,
      expected_external_id: "othershop.myshopify.com",
      now: @now
    )

    assert result.failure?
    assert_equal "shop does not match", result.error
    assert_equal [:external_id_mismatch], result.errors
  end

  test "fails closed when audience or secret is missing" do
    bare, = create_oauth_client(name: "Bare App")

    result = RecordingStudioOauth.verify_session_token(
      client: bare,
      token: shopify_session_token,
      now: @now
    )

    assert result.failure?
    assert_equal "session token verify is not configured", result.error
    assert_equal [:missing_config], result.errors
  end

  test "unknown client id fails" do
    result = RecordingStudioOauth.verify_session_token(
      client_id: "rsoauth_oc_missing",
      token: shopify_session_token,
      now: @now
    )

    assert result.failure?
    assert_equal "unknown client", result.error
    assert_equal [:unknown_client], result.errors
  end

  test "revoked client fails" do
    @client.revoke!

    result = RecordingStudioOauth.verify_session_token(client: @client, token: shopify_session_token, now: @now)

    assert result.failure?
    assert_equal "client is revoked", result.error
    assert_equal [:revoked], result.errors
  end

  private

  def shopify_session_token(aud: @audience, shop: "exampleshop.myshopify.com", **claims)
    payload = {
      "iss" => "https://#{shop}/admin",
      "dest" => "https://#{shop}",
      "aud" => aud,
      "sub" => "42",
      "exp" => @now + 60,
      "nbf" => @now - 5,
      "iat" => @now,
      "jti" => "jti-1",
      "sid" => "sid-1"
    }.merge(claims.stringify_keys)

    RecordingStudioOauth::Hs256Jwt.encode(payload, @secret)
  end
end
