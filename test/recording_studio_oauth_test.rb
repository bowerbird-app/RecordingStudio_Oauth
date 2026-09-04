# frozen_string_literal: true

require "test_helper"

class RecordingStudioOauthTest < Minitest::Test
  def test_version_matches_release
    assert_equal "0.1.1", ::RecordingStudioOauth::VERSION
  end

  def test_engine_exists
    assert_kind_of Class, ::RecordingStudioOauth::Engine
  end

  def test_gemspec_pins
    gemspec = File.read(File.expand_path("../recording_studio_oauth.gemspec", __dir__))

    assert_includes gemspec, 'spec.add_dependency "recording_studio", "~> 4.2"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_accessible", "~> 0.9"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_api", "~> 0.5.2"'
    assert_includes gemspec, 'spec.add_dependency "recording_studio_site_settings", "~> 0.1"'
    assert_includes gemspec, 'spec.add_dependency "flat_pack", "~> 0.1.144"'
    refute_includes gemspec, "recording_studio_users"
    refute_includes gemspec, "~> 0.1.143"
  end

  def test_gemspec_excludes_cursor_config
    spec = Gem::Specification.load(File.expand_path("../recording_studio_oauth.gemspec", __dir__))
    cursor_files = spec.files.select { |path| path == ".cursor" || path.split("/").include?(".cursor") }

    assert_empty cursor_files, "gemspec must not package .cursor/ (got #{cursor_files.inspect})"
  end

  def test_cursor_environment_is_repo_managed_without_snapshot
    path = File.expand_path("../.cursor/environment.json", __dir__)
    json = JSON.parse(File.read(path))

    assert_equal "recording-studio-oauth", json["name"]
    assert_equal ".cursor/install.sh", json["install"]
    assert_equal ".cursor/start.sh", json["start"]
    refute json.key?("snapshot"), "snapshot pins a Personal build and skips install"
    refute json.key?("agentCanUpdateSnapshot")
  end

  def test_cursor_install_still_fetches_skills
    install_script = File.read(File.expand_path("../.cursor/install.sh", __dir__))

    assert_includes install_script, "fetch-skills.sh"
  end

  def test_dummy_gemfile_pins_verified_github_tags
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))

    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.9.1"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_api", tag: "v0.5.2"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_admin", tag: "v2.0.2"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_site_settings", tag: "v0.1.0"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.5.1"'
    assert_includes gemfile, 'github: "bowerbird-app/flatpack", tag: "v0.1.144"'
    assert_includes gemfile, 'github: "bowerbird-app/RecordingStudio_users", tag: "v0.10.0"'
    assert_includes gemfile, 'gem "recording_studio_user"'
    refute_includes gemfile, 'tag: "v0.1.143"'
  end

  def test_does_not_ship_copied_core_hooks_or_base_service
    refute File.exist?(File.expand_path("../lib/recording_studio_oauth/hooks.rb", __dir__))
    refute File.exist?(File.expand_path("../lib/recording_studio_oauth/services/base_service.rb", __dir__))
  end

  def test_dummy_app_uses_recording_studio_default_layout
    application_controller_path = File.expand_path("dummy/app/controllers/application_controller.rb", __dir__)
    controller_source = File.read(application_controller_path)

    assert_includes controller_source, "include RecordingStudio::UsesDefaultLayout"
    assert_includes controller_source, '"recording_studio/default_layout"'
    assert_includes controller_source, "return \"application\" if devise_controller?"
    assert_includes controller_source, "RecordingStudioUser"
    refute_includes controller_source, "flat_pack_sidebar"
  end

  def test_dummy_login_layout_keeps_flatpack_assets
    application_layout = File.read(File.expand_path("dummy/app/views/layouts/application.html.erb", __dir__))

    assert_includes application_layout, '<html data-theme="rounded">'
    assert_includes application_layout, 'stylesheet_link_tag "flat_pack/variables"'
    assert_includes application_layout, "javascript_importmap_tags"
    refute_includes application_layout, "mt-28"
  end

  def test_dummy_tailwind_keeps_flatpack_theme_selection_in_flatpack
    tailwind_source = File.read(File.expand_path("dummy/app/assets/tailwind/application.css", __dir__))

    assert_includes tailwind_source, '@import "./gem_sources.css"'
    assert_includes tailwind_source, "../../../vendor/bundle/**/flatpack/app/components/**/*.{rb,erb}"
    assert_includes tailwind_source, "flatpack-*/app/components/**/*.{rb,erb}"
    refute_includes tailwind_source, "@theme"
    refute_includes tailwind_source, "--color-fp-primary"
  end

  def test_product_readme_describes_the_authorization_server
    readme = File.read(File.expand_path("../README.md", __dir__))

    assert_includes readme, "authorization server"
    assert_includes readme, "resource server"
    assert_includes readme, "recording_studio_api"
    assert_includes readme, "register_oauth_grant"
    assert_includes readme, "TokenAuthenticator"
    assert_includes readme, "~> 0.5.2"
    assert_includes readme, "name_for"
    assert_includes readme, "Recording Studio Users"
    assert_includes readme, "email-first"
    refute_includes readme, "internal template"
    refute_includes readme, "respond_to?(:register_oauth_grant)"
  end

  def test_engine_does_not_ship_a_home_view
    view_path = File.expand_path("../app/views/recording_studio_oauth/home/index.html.erb", __dir__)

    refute File.exist?(view_path)
  end

  def test_connect_views_use_flatpack_not_button_group
    index = File.read(File.expand_path("../app/views/recording_studio_oauth/oauth_authorizations/index.html.erb", __dir__))
    consent = File.read(File.expand_path("../app/views/recording_studio_oauth/oauth_authorizations/new.html.erb", __dir__))
    error = File.read(File.expand_path("../app/views/recording_studio_oauth/oauth_authorizations/error.html.erb", __dir__))
    layout = File.read(File.expand_path("../app/views/layouts/recording_studio_oauth/authorization.html.erb", __dir__))

    assert_includes index, "FlatPack::List::Component"
    assert_includes index, "FlatPack::Card::Component"
    refute_includes index, "padding: :none"
    assert_includes index, "skip_connect_page_nav"
    assert_includes index, "connection_status_trailing"
    refute_includes index, "Grid::Component"
    refute_includes index, "cols: 2"
    refute_includes consent, "ButtonGroup"
    refute_includes consent, "Grid::Component"
    refute_includes consent, "cols: 2"
    refute_includes consent, "page_nav_back_url"
    refute_includes consent, "help_text"
    refute_includes consent, "Permission"
    assert_includes consent, 'text: "Connect"'
    assert_includes consent, 'value: "connect"'
    assert_includes consent, 'value: "cancel"'
    refute_includes error, "Grid::Component"
    refute_includes error, "cols: 2"
    assert_includes layout, "min-h-dvh"
    assert_includes layout, "max-w-sm"
    assert_includes layout, "FlatPack::PageNav::Component"
    assert_includes layout, "skip_connect_page_nav"
    refute_includes layout, "max-w-6xl"
  end

  def test_connect_title_reads_site_settings_name_for
    controller = File.read(File.expand_path("../app/controllers/recording_studio_oauth/oauth_authorizations_controller.rb", __dir__))

    assert_includes controller, "RecordingStudioSiteSettings.name_for"
    assert_includes controller, "RecordingStudioSiteSettings.site_root_for"
    assert_includes controller, "FlatPack::Button::Component"
    refute_includes controller, "RecordingStudioAttachable"
  end

  def test_connect_list_button_styles_use_flatpack_schemes
    controller = File.read(File.expand_path("../app/controllers/recording_studio_oauth/oauth_authorizations_controller.rb", __dir__))
    consent = File.read(File.expand_path("../app/views/recording_studio_oauth/oauth_authorizations/new.html.erb", __dir__))

    assert_includes controller, '"Connect" => :default'
    assert_includes controller, '"Reconnect" => :danger'
    assert_includes controller, '"Connected" => :success'
    refute_includes controller, '"Connect" => :primary'
    refute_includes controller, '"Reconnect" => :primary'
    refute_includes controller, '"Connected" => :secondary'
    assert_includes consent, "style: :primary"
    assert_includes consent, "style: :secondary"
  end

  def test_reconnect_button_wraps_a_flatpack_tooltip
    controller = File.read(File.expand_path("../app/controllers/recording_studio_oauth/oauth_authorizations_controller.rb", __dir__))

    assert_includes controller, "FlatPack::Tooltip::Component"
    assert_includes controller, "This connection is no longer live."
    assert_includes controller, "placement: :top"
    refute_includes controller, "title: RECONNECT"
    refute_includes controller, 'title: "This connection'
  end
end
