# frozen_string_literal: true

require "test_helper"

class AdminDefinitionsTest < Minitest::Test
  def test_registered_apps_screen_has_new_app_button
    admin = File.read(File.expand_path("../lib/recording_studio_oauth/admin.rb", __dir__))

    assert_includes admin, "button :new"
    assert_includes admin, 'text: "New app"'
    assert_includes admin, "style: :primary"
    assert_includes admin, "new_oauth_client_path"
    assert_includes admin, "class OauthClientsResource"
    assert_includes admin, "action :create"
    assert_includes admin, "register_resource(OauthClientsResource)"
    refute_includes admin, "Revoke an app to stop new connections."
  end

  def test_admin_create_is_owned_by_this_gem
    controller = File.read(File.expand_path("../app/controllers/recording_studio_oauth/admin/oauth_clients_controller.rb", __dir__))
    routes = File.read(File.expand_path("../config/routes.rb", __dir__))
    engine = File.read(File.expand_path("../lib/recording_studio_oauth/engine.rb", __dir__))

    assert_includes controller, "include RecordingStudioAdmin::AdminActionAuditing"
    assert_includes controller, "authorize_resource!"
    assert_includes controller, "perform_recording_studio_admin_action!"
    assert_includes controller, "Services::CreateOauthClient.call"
    assert_includes controller, "flash[:oauth_client_secret]"
    refute_includes controller, "Pundit"
    refute_includes controller, "Doorkeeper"
    refute_includes controller, "layout \"recording_studio_oauth/authorization\""
    assert_includes routes, "resources :oauth_clients, only: %i[new create show]"
    assert_includes engine, "create_oauth_client"
  end

  def test_admin_new_and_credentials_views_use_flatpack_and_default_layout
    new_view = File.read(File.expand_path("../app/views/recording_studio_oauth/admin/oauth_clients/new.html.erb", __dir__))
    show_view = File.read(File.expand_path("../app/views/recording_studio_oauth/admin/oauth_clients/show.html.erb", __dir__))

    assert_includes new_view, "FlatPack::TextInput::Component"
    assert_includes new_view, "FlatPack::TextArea::Component"
    assert_includes new_view, "FlatPack::Select::Component"
    assert_includes new_view, 'text: "Create app"'
    assert_includes new_view, 'label: "Name"'
    assert_includes new_view, 'label: "Redirect URLs"'
    assert_includes new_view, 'label: "Secret"'
    refute_includes new_view, "Card::Component"
    refute_includes new_view, "max-w-sm"
    assert_includes show_view, "quick_copy: true"
    assert_includes show_view, 'text: "Done"'
    refute_includes show_view, "oauth_client_secret_digest"
    refute_includes show_view, "authorization"
  end
end
