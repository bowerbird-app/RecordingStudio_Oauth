# frozen_string_literal: true

require "test_helper"
require "yaml"

class LocalesTest < Minitest::Test
  Copy = RecordingStudioOauth::Copy

  def test_engine_ships_only_english_locale_files
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  def test_dummy_french_covers_every_engine_english_key
    english = flatten_keys(locale_tree(File.join(engine_locales_dir, "en.yml"), "en"))
    french = flatten_keys(locale_tree(File.join(dummy_locales_dir, "fr.yml"), "fr"))
    missing = english - french

    assert_empty missing, "dummy fr.yml is missing keys present in engine en.yml: #{missing.join(', ')}"
  end

  def test_english_default_copy_is_unchanged
    I18n.with_locale(:en) do
      assert_equal "Connect", Copy.t("connect.allow")
      assert_equal "Cancel", Copy.t("connect.deny")
      assert_equal "Connected apps", Copy.t("connected_apps.title")
      assert_equal "These apps have their own access. Remove one to shut it off.", Copy.t("connected_apps.subtitle")
      assert_equal "Remove access", Copy.t("connected_apps.remove")
      assert_equal "App access removed.", Copy.t("flashes.access_removed")
      assert_equal "Could not connect", Copy.t("errors.page_title")
      assert_equal "That access is gone. Connect again.", Copy.t("errors.access_gone")
      assert_equal "Your access changed. Connect again.", Copy.t("errors.role_changed")
      assert_equal "This connection is no longer live.", Copy.t("connect.reconnect_hint")
      assert_equal "View", Copy.role_name("view")
      assert_equal "Edit", Copy.role_name("edit")
      assert_equal "Admin", Copy.role_name("admin")
    end
  end

  def test_role_names_fall_back_to_humanize_for_custom_roles
    I18n.with_locale(:en) do
      assert_equal "Approver", Copy.role_name("approver")
    end
  end

  def test_scope_descriptions_fall_back_to_existing_text
    I18n.with_locale(:en) do
      assert_equal "Read your files", Copy.scope_description("files.read", "Read your files")
    end
  end

  def test_component_text_overrides_win_including_nil
    assert_equal "Connected apps", Copy.value(Copy::UNSET, "connected_apps.title")
    assert_equal "Acme apps", Copy.value("Acme apps", "connected_apps.title")
    assert_nil Copy.value(nil, "connected_apps.title")
  end

  def test_defaulted_follows_locale_until_the_host_changes_the_string
    I18n.with_locale(:en) do
      assert_equal "Connected apps", Copy.defaulted("Connected apps", "Connected apps", "connected_apps.title")
      assert_equal "Acme apps", Copy.defaulted("Acme apps", "Connected apps", "connected_apps.title")
      assert_equal "Connected apps", Copy.defaulted(nil, "Connected apps", "connected_apps.title")
    end
  end

  def test_connect_title_argument_override_wins
    title = RecordingStudioOauth::ConnectHandshake.title(
      plugin_name: "Seed Demo App",
      site_names: %w[Studio],
      title: "Host connect title"
    )

    assert_equal "Host connect title", title
  end

  def test_host_translation_overrides_english
    I18n.backend.store_translations(:en, acme_title)
    assert_equal "Acme apps", Copy.t("connected_apps.title")
  ensure
    I18n.backend.store_translations(:en, default_title)
  end

  def test_gemspec_does_not_depend_on_internationalization
    gemspec = File.read(File.expand_path("../recording_studio_oauth.gemspec", __dir__))

    refute_includes gemspec, "recording_studio_internationalization"
    refute_includes gemspec, "RecordingStudio_Internationalization"
  end

  private

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def dummy_locales_dir
    File.expand_path("dummy/config/locales", __dir__)
  end

  def locale_tree(path, locale)
    yaml = YAML.safe_load_file(path, aliases: true)
    yaml.fetch(locale).fetch("recording_studio").fetch("oauth")
  end

  def flatten_keys(hash, prefix = [])
    hash.flat_map do |key, value|
      path = prefix + [key.to_s]
      value.is_a?(Hash) ? flatten_keys(value, path) : [path.join(".")]
    end
  end

  def acme_title
    { recording_studio: { oauth: { connected_apps: { title: "Acme apps" } } } }
  end

  def default_title
    { recording_studio: { oauth: { connected_apps: { title: "Connected apps" } } } }
  end
end
