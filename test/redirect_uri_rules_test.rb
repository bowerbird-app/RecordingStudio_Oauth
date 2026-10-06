# frozen_string_literal: true

require "test_helper"

class RedirectUriRulesTest < Minitest::Test
  def test_requires_redirect_uris
    assert_equal "redirect_uris is required", RecordingStudioOauth::RedirectUriRules.self_registered_error([])
    assert_equal "redirect_uris is required", RecordingStudioOauth::RedirectUriRules.self_registered_error(nil)
  end

  def test_accepts_https_and_loopback_http
    assert_nil RecordingStudioOauth::RedirectUriRules.self_registered_error(["https://app.example.com/callback"])
    assert_nil RecordingStudioOauth::RedirectUriRules.self_registered_error(["http://localhost:6274/callback"])
    assert_nil RecordingStudioOauth::RedirectUriRules.self_registered_error(["http://127.0.0.1:6274/callback"])
    assert_nil RecordingStudioOauth::RedirectUriRules.self_registered_error(["http://[::1]:6274/callback"])
  end

  def test_rejects_http_non_loopback_fragments_wildcards_and_userinfo
    assert_match(/https/, RecordingStudioOauth::RedirectUriRules.self_registered_error(["http://example.com/callback"]))
    assert_match(/fragment/, RecordingStudioOauth::RedirectUriRules.self_registered_error(["https://example.com/callback#oops"]))
    assert_match(/wildcard/, RecordingStudioOauth::RedirectUriRules.self_registered_error(["https://*.example.com/callback"]))
    assert_match(/user info/, RecordingStudioOauth::RedirectUriRules.self_registered_error(["https://user:pass@example.com/callback"]))
    assert_match(/valid URIs/, RecordingStudioOauth::RedirectUriRules.self_registered_error(["not a uri"]))
  end
end
