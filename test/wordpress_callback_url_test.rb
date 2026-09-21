# frozen_string_literal: true

require "test_helper"

class WordPressCallbackUrlTest < Minitest::Test
  def test_allows_https_wp_admin_callback
    url = RecordingStudioOauth::WordPressCallbackUrl.parse(
      "https://blog.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback"
    )

    assert_equal "https://blog.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback", url.to_s
  end

  def test_allows_localhost_http_and_subdirectory
    url = RecordingStudioOauth::WordPressCallbackUrl.parse(
      "http://localhost:8888/blog/wp-admin/admin-post.php?action=recording_studio_oauth_callback"
    )

    assert_equal "http://localhost:8888/blog/wp-admin/admin-post.php?action=recording_studio_oauth_callback", url.to_s
  end

  def test_canonicalizes_host_case_and_default_port
    url = RecordingStudioOauth::WordPressCallbackUrl.parse(
      "https://Blog.Example.COM:443/wp-admin/admin-post.php?action=recording_studio_oauth_callback"
    )

    assert_equal "https://blog.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback", url.to_s
  end

  def test_rejects_open_redirect_hosts_without_wp_action
    [
      "https://evil.example/",
      "https://evil.example/wp-admin/admin-post.php",
      "https://evil.example/wp-admin/admin-post.php?action=other",
      "https://blog.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback&next=https://evil.example",
      "https://blog.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback#https://evil.example",
      "javascript:alert(1)",
      "/wp-admin/admin-post.php?action=recording_studio_oauth_callback",
      "https://user:pass@blog.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback",
      "https://blog.example.com/wp-admin/../secret/wp-admin/admin-post.php?action=recording_studio_oauth_callback",
      "https://blog.example.com/not-admin/admin-post.php?action=recording_studio_oauth_callback"
    ].each do |raw|
      assert_nil RecordingStudioOauth::WordPressCallbackUrl.parse(raw), raw
    end
  end
end
