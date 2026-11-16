# frozen_string_literal: true

require "test_helper"

class ReturnUrlRulesTest < Minitest::Test
  PATTERN = "https://*/wp-admin/admin-post.php?action=recording_studio_oauth_callback"
  EXACT = "https://shop.example.com/oauth/done"
  MATCHED = "https://blog.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback"
  LABEL = "https://*.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback"

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

  def test_label_pattern_matches_one_subdomain
    assert allow_pattern?(
      "https://blog.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback",
      LABEL
    )
    assert allow_pattern?("https://Blog.example.com/cb", "https://*.Example.COM/cb")
    assert allow_pattern?("https://example.com/cb", "https://example.com:443/cb")
  end

  def test_label_pattern_rejects_an_attacker_host_that_copies_the_pattern
    refute allow_pattern?(
      "https://attacker.tld/x.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback",
      LABEL
    )
    refute allow_pattern?(
      "https://blog.example.com/other?x=https://blog.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback",
      LABEL
    )
  end

  def test_label_pattern_rejects_extra_labels_a_public_suffix_and_mismatches
    refute allow_pattern?(
      "https://a.b.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback",
      LABEL
    )
    refute allow_pattern?(
      "https://evil.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback",
      "https://*.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback"
    )
    refute allow_pattern?(
      "https://blog.example.com/wp-admin/other.php?action=recording_studio_oauth_callback",
      LABEL
    )
    refute allow_pattern?(
      "https://blog.example.com/wp-admin/admin-post.php?action=other",
      LABEL
    )
    refute allow_pattern?(
      "https://blog.example.com:8443/wp-admin/admin-post.php?action=recording_studio_oauth_callback",
      LABEL
    )
    refute allow_pattern?(
      "http://blog.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback",
      LABEL
    )
  end

  def test_any_host_pattern_keeps_the_path_and_query_and_rejects_ip_literals
    assert allow_pattern?(MATCHED, PATTERN)
    refute allow_pattern?(
      "https://blog.example.com/other/wp-admin/admin-post.php?action=recording_studio_oauth_callback",
      PATTERN
    )
    refute allow_pattern?(
      "https://127.0.0.1/wp-admin/admin-post.php?action=recording_studio_oauth_callback",
      PATTERN
    )
    refute allow_pattern?(
      "https://[::1]/wp-admin/admin-post.php?action=recording_studio_oauth_callback",
      PATTERN
    )
  end

  def test_rejects_trailing_dot_hosts_encoded_hosts_and_stars_outside_the_host
    refute allow_pattern?(
      "https://blog.example.com./wp-admin/admin-post.php?action=recording_studio_oauth_callback",
      LABEL
    )
    refute allow_pattern?("https://ex%61mple.com/cb", "https://*.example.com/cb")
    refute allow_pattern?("https://example.com/a/done", "https://example.com/*/done")
    refute allow_pattern?("https://example.com/cb?foo=bar", "https://example.com/cb?foo=*")
    refute allow_pattern?("https://evil.com/cb", "https://*.com/cb")
    refute RecordingStudioOauth::ReturnUrlRules.any_host_pattern?("https://*.example.com/cb")
    assert RecordingStudioOauth::ReturnUrlRules.any_host_pattern?(PATTERN)
  end

  private

  def allow_pattern?(url, pattern)
    RecordingStudioOauth::ReturnUrlRules.allow?(url, patterns: [pattern], exact_urls: [])
  end
end
