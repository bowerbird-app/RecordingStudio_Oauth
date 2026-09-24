# frozen_string_literal: true

require "test_helper"
require "recording_studio_oauth/hs256_jwt"

class Hs256JwtTest < Minitest::Test
  SECRET = "channel-signing-secret"
  AUDIENCE = "partner-app-client-id"

  def test_round_trips_a_valid_token
    now = 1_700_000_000
    token = encode_token(now: now)

    status, claims = RecordingStudioOauth::Hs256Jwt.decode(
      token,
      SECRET,
      now: now,
      audience: AUDIENCE
    )

    assert_equal :ok, status
    assert_equal AUDIENCE, claims["aud"]
    assert_equal "https://exampleshop.myshopify.com", claims["dest"]
  end

  def test_rejects_a_forged_signature
    token = encode_token
    status, claims = RecordingStudioOauth::Hs256Jwt.decode(
      token,
      "other-secret",
      audience: AUDIENCE
    )

    assert_equal :bad_signature, status
    assert_nil claims
  end

  def test_rejects_alg_none
    token = RecordingStudioOauth::Hs256Jwt.encode(
      valid_payload,
      SECRET,
      header: { "alg" => "none", "typ" => "JWT" }
    )
    status, = RecordingStudioOauth::Hs256Jwt.decode(token, SECRET, audience: AUDIENCE)

    assert_equal :invalid_token, status
  end

  def test_rejects_wrong_audience
    token = encode_token
    status, = RecordingStudioOauth::Hs256Jwt.decode(token, SECRET, audience: "someone-else")

    assert_equal :wrong_audience, status
  end

  def test_rejects_expired_token
    now = 1_700_000_000
    token = encode_token(now: now, exp: now - 30)
    status, = RecordingStudioOauth::Hs256Jwt.decode(token, SECRET, now: now, audience: AUDIENCE)

    assert_equal :expired, status
  end

  def test_allows_exp_inside_leeway
    now = 1_700_000_000
    token = encode_token(now: now, exp: now - 5)
    status, = RecordingStudioOauth::Hs256Jwt.decode(token, SECRET, now: now, audience: AUDIENCE)

    assert_equal :ok, status
  end

  def test_rejects_not_yet_valid_token
    now = 1_700_000_000
    token = encode_token(now: now, nbf: now + 30)
    status, = RecordingStudioOauth::Hs256Jwt.decode(token, SECRET, now: now, audience: AUDIENCE)

    assert_equal :not_yet_valid, status
  end

  def test_rejects_truncated_token
    status, = RecordingStudioOauth::Hs256Jwt.decode("not-a-jwt", SECRET, audience: AUDIENCE)

    assert_equal :invalid_token, status
  end

  private

  def encode_token(now: Time.now.to_i, exp: nil, nbf: nil)
    RecordingStudioOauth::Hs256Jwt.encode(valid_payload(now: now, exp: exp, nbf: nbf), SECRET)
  end

  def valid_payload(now: Time.now.to_i, exp: nil, nbf: nil)
    {
      "iss" => "https://exampleshop.myshopify.com/admin",
      "dest" => "https://exampleshop.myshopify.com",
      "aud" => AUDIENCE,
      "sub" => "42",
      "exp" => exp || (now + 60),
      "nbf" => nbf || (now - 5),
      "iat" => now,
      "jti" => "jti-1",
      "sid" => "sid-1"
    }
  end
end
