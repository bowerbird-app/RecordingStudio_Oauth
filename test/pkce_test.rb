# frozen_string_literal: true

require "test_helper"

class PkceTest < Minitest::Test
  def test_s256_challenge_is_urlsafe_and_stable
    verifier = "a" * 43
    first = RecordingStudioOauth::Pkce.s256_challenge(verifier)
    second = RecordingStudioOauth::Pkce.s256_challenge(verifier)

    assert_equal first, second
    refute_includes first, "="
    assert RecordingStudioOauth::Pkce.s256_matches?(verifier, first)
  end

  def test_rejects_short_verifiers
    refute RecordingStudioOauth::Pkce.valid_verifier?("short")
    refute RecordingStudioOauth::Pkce.s256_matches?("short", "anything")
  end
end
