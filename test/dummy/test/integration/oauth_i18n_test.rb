# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class OauthI18nTest < ActionDispatch::IntegrationTest
  include OauthDummyHelpers
  include Devise::Test::IntegrationHelpers

  setup do
    @user = create_user
    @root_recording, @access_recording = create_access_recording_for(user: @user, workspace_name: "I18n Workspace")
    @pkce = pkce_pair
    @oauth_client, = create_oauth_client(name: "Notes App")
    sign_in @user
  end

  teardown do
    Current.actor = nil if defined?(Current)
  end

  test "language selector sits in the dummy top nav left of the root switcher" do
    get "/"

    assert_response :success
    assert_select "form[action='/recording_studio_internationalization/locale']"
    assert_includes response.body, "English"
    assert_includes response.body, "Français"
    assert_select "html[lang='en']"
    language_at = response.body.index("dummy-language-selector")
    switcher_at = response.body.index("recording-studio-root-switchable--root-switch-dropdown")
    assert language_at, "expected a language selector in the top nav"
    assert switcher_at, "expected a root switcher in the top nav"
    assert language_at < switcher_at, "language selector should sit left of the root switcher"
  end

  test "consent and connected-apps copy stay English by default" do
    get authorize_path, params: authorize_params

    assert_response :success
    assert_includes response.body, "Notes App wants to connect"
    assert_includes response.body, "Connect"
    assert_select "html[lang='en']"

    get authorize_path, params: authorize_params.merge(access_recording_id: @access_recording.id)

    assert_response :success
    assert_includes response.body, "I18n Workspace permissions"
    assert_includes response.body, "Connect"
    assert_includes response.body, "Cancel"
    refute_includes response.body, "Connecter"
    assert_select "html[lang='en']"

    get recording_studio_oauth.connected_apps_path

    assert_response :success
    assert_includes response.body, "Connected apps"
    assert_includes response.body, "Nothing connected yet"
    assert_select "html[lang='en']"
  end

  test "dummy French locale renders consent and connected-apps copy" do
    switch_to_french

    get authorize_path, params: authorize_params

    assert_response :success
    assert_includes response.body, "Notes App souhaite se connecter"
    refute_includes response.body, "Notes App wants to connect"
    assert_includes response.body, "Connecter"
    assert_select "html[lang='fr']"
    assert_includes response.body, "I18n Workspace"

    get authorize_path, params: authorize_params.merge(access_recording_id: @access_recording.id)

    assert_response :success
    assert_includes response.body, "Autorisations I18n Workspace"
    assert_includes response.body, "Connecter"
    assert_includes response.body, "Annuler"
    refute_includes response.body, "Cancel"
    assert_select "html[lang='fr']"

    get authorize_path, params: authorize_params.merge(response_type: "token")

    assert_response :bad_request
    assert_includes response.body, "Connexion impossible"
    refute_includes response.body, "Could not connect"
    assert_select "html[lang='fr']"

    approve_delegated_oauth(
      oauth_client: @oauth_client,
      user: @user,
      access_recording: @access_recording
    )
    get recording_studio_oauth.connected_apps_path

    assert_response :success
    assert_includes response.body, "Applications connectées"
    assert_includes response.body, "Retirer l’accès"
    assert_includes response.body, "Notes App"
    refute_includes response.body, "Connected apps"
    refute_includes response.body, "Remove access"
    assert_select "html[lang='fr']"
  end

  test "connect title argument override still wins over French locale" do
    switch_to_french

    title = RecordingStudioOauth::ConnectHandshake.title(
      plugin_name: "Notes App",
      site_names: %w[Studio],
      title: "Host connect title"
    )

    assert_equal "Host connect title", title
    I18n.with_locale(:fr) do
      assert_equal "Applications connectées", RecordingStudioOauth::Copy.t("connected_apps.title")
    end
  end

  test "revoking a connected app flashes the locale string" do
    approved = approve_delegated_oauth(
      oauth_client: @oauth_client,
      user: @user,
      access_recording: @access_recording
    )
    switch_to_french

    delete recording_studio_oauth.connected_app_path(approved.fetch(:authorization))

    assert_redirected_to recording_studio_oauth.connected_apps_path
    assert_equal "Accès de l’application retiré.", flash[:notice]
  end

  private

  def authorize_params
    {
      response_type: "code",
      client_id: @oauth_client.client_id,
      redirect_uri: "http://127.0.0.1/callback",
      state: "xyz",
      code_challenge: @pkce.fetch(:challenge),
      code_challenge_method: "S256"
    }
  end

  def switch_to_french
    patch "/recording_studio_internationalization/locale", params: { locale: "fr", return_to: "/" }
    follow_redirect!
  end
end
