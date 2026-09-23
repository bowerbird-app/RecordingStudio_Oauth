# frozen_string_literal: true

require "test_helper"

class ConnectOptionsTest < ActionDispatch::IntegrationTest
  include OauthDummyHelpers

  setup do
    @host_setting = RecordingStudioOauth::RegistrationSetting.current
    @host_setting.update!(allow_registration: false)
    @public_origin = RecordingStudioOauth.configuration.public_origin
    @registration_path = RecordingStudioOauth.configuration.registration_path
    RecordingStudioOauth.configuration.public_origin = nil
    RecordingStudioOauth.configuration.registration_path = "/users/sign_up"
  end

  teardown do
    RecordingStudioOauth.configuration.public_origin = @public_origin
    RecordingStudioOauth.configuration.registration_path = @registration_path
    @host_setting.update!(allow_registration: false)
  end

  test "global off and app on allows registration for that client" do
    client, = create_oauth_client(name: "Open App", allow_registration: true)
    @host_setting.update!(allow_registration: false)

    get "/recording_studio_oauth/connect/options", params: { client_id: client.client_id }

    assert_response :success
    assert_equal(
      {
        "registration" => true,
        "registration_url" => "http://www.example.com/users/sign_up"
      },
      response.parsed_body
    )
  end

  test "global on and app off does not allow registration for that client" do
    client, = create_oauth_client(name: "Closed App", allow_registration: false)
    @host_setting.update!(allow_registration: true)

    get "/recording_studio_oauth/connect/options", params: { client_id: client.client_id }

    assert_response :success
    assert_equal({ "registration" => false }, response.parsed_body)
    refute client.reload.allow_registration?
  end

  test "unknown client id is closed" do
    get "/recording_studio_oauth/connect/options", params: { client_id: "missing-client" }

    assert_response :success
    assert_equal({ "registration" => false }, response.parsed_body)
  end

  test "blank client id is closed" do
    get "/recording_studio_oauth/connect/options"

    assert_response :success
    assert_equal({ "registration" => false }, response.parsed_body)
  end

  test "a new app copies the host choice and a later host change leaves that app alone" do
    @host_setting.update!(allow_registration: true)

    created = RecordingStudioOauth::Services::CreateOauthClient.call(
      name: "Copied App",
      redirect_uris: ["https://example.com/callback"],
      confidential: false
    )

    assert created.success?
    client = created.value.fetch(:client)
    assert client.allow_registration?

    @host_setting.update!(allow_registration: false)
    client.reload
    assert client.allow_registration?

    get "/recording_studio_oauth/connect/options", params: { client_id: client.client_id }

    assert_equal true, response.parsed_body.fetch("registration")
  end

  test "signup url uses the configured public origin" do
    RecordingStudioOauth.configuration.public_origin = "https://public.example.com"
    client, = create_oauth_client(name: "Public Origin App", allow_registration: true)

    get "/recording_studio_oauth/connect/options", params: { client_id: client.client_id }

    assert_equal "https://public.example.com/users/sign_up", response.parsed_body.fetch("registration_url")
  end
end
