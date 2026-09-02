# frozen_string_literal: true

require "test_helper"

class ConnectHandshakeTest < Minitest::Test
  def test_title_includes_site_when_every_name_matches
    title = RecordingStudioOauth::ConnectHandshake.title(
      plugin_name: "Seed Demo App",
      site_names: %w[Studio Studio]
    )

    assert_equal "Seed Demo App wants to connect to Studio", title
  end

  def test_title_omits_blank_site
    title = RecordingStudioOauth::ConnectHandshake.title(
      plugin_name: "Seed Demo App",
      site_names: [nil, ""]
    )

    assert_equal "Seed Demo App wants to connect", title
    refute_includes title, "connect to "
  end

  def test_title_omits_site_when_names_differ
    title = RecordingStudioOauth::ConnectHandshake.title(
      plugin_name: "Seed Demo App",
      site_names: %w[Harbor Meadow]
    )

    assert_equal "Seed Demo App wants to connect", title
  end

  def test_row_label_keeps_parent_when_site_is_shared
    label = RecordingStudioOauth::ConnectHandshake.row_label(
      parent_name: "Studio Workspace",
      site_name: "Studio",
      shared_site_name: true
    )

    assert_equal "Studio Workspace", label
  end

  def test_row_label_uses_site_name_when_sites_differ
    label = RecordingStudioOauth::ConnectHandshake.row_label(
      parent_name: "Studio Workspace",
      site_name: "Harbor",
      shared_site_name: false
    )

    assert_equal "Harbor", label
  end

  def test_row_label_skips_blank_site_name
    label = RecordingStudioOauth::ConnectHandshake.row_label(
      parent_name: "Studio Workspace",
      site_name: nil,
      shared_site_name: false
    )

    assert_equal "Studio Workspace", label
  end

  def test_subtitle_drops_a_repeated_site_name
    subtitle = RecordingStudioOauth::ConnectHandshake.subtitle(
      parent_name: "Studio",
      site_name: "Studio"
    )

    assert_nil subtitle
  end
end
