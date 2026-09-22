# frozen_string_literal: true

require "test_helper"

class ReturnUrlRulesTest < Minitest::Test
  PATTERN = "https://*/wp-admin/admin-post.php?action=recording_studio_oauth_callback"
  EXACT = "https://shop.example.com/oauth/done"
  MATCHED = "https://blog.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback"

  def test_pattern_matches_a_wordpress_admin_post_return
    assert RecordingStudioOauth::ReturnUrlRules.allow?(
      MATCHED,
      patterns: [PATTERN],
      exact_urls: []
    )
  end

  def test_exact_url_matches_only_that_address
    assert RecordingStudioOauth::ReturnUrlRules.allow?(
      EXACT,
      patterns: [],
      exact_urls: [EXACT]
    )
  end

  def test_rejects_a_return_that_matches_neither_rule
    refute RecordingStudioOauth::ReturnUrlRules.allow?(
      "https://evil.example/steal",
      patterns: [PATTERN],
      exact_urls: [EXACT]
    )
  end

  def test_star_is_a_wildcard_not_a_regular_expression
    pattern = "https://example.com/cb?foo=a.b"

    assert RecordingStudioOauth::ReturnUrlRules.allow?(
      "https://example.com/cb?foo=a.b",
      patterns: [pattern],
      exact_urls: []
    )
    refute RecordingStudioOauth::ReturnUrlRules.allow?(
      "https://example.com/cb?foo=axb",
      patterns: [pattern],
      exact_urls: []
    )
  end

  def test_a_star_pattern_still_rejects_javascript_and_userinfo
    refute RecordingStudioOauth::ReturnUrlRules.allow?("javascript:alert(1)", patterns: ["*"], exact_urls: [])
    refute RecordingStudioOauth::ReturnUrlRules.allow?(
      "https://user:pass@blog.example.com/callback",
      patterns: ["https://*"],
      exact_urls: []
    )
    refute RecordingStudioOauth::ReturnUrlRules.allow?(
      "#{MATCHED}#next",
      patterns: [PATTERN],
      exact_urls: []
    )
  end
end
