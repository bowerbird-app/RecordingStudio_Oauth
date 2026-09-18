# frozen_string_literal: true

require "test_helper"

class AuthenticateOauthClientTest < ActiveSupport::TestCase
  include OauthDummyHelpers

  setup do
    RecordingStudioApi.configuration.api(:wp_plugin_demo)
  end

  test "public client registered on public authenticates on a named API" do
    client, = create_oauth_client(name: "Handmade Public App")

    result = RecordingStudioOauth::Services::AuthenticateOauthClient.call(
      client_id: client.client_id,
      api: "wp_plugin_demo"
    )

    assert result.success?
    assert_equal client.id, result.value.id
  end

  test "confidential client registered on public fails on a named API" do
    client, secret = create_oauth_client(name: "Handmade Secret App", confidential: true)

    result = RecordingStudioOauth::Services::AuthenticateOauthClient.call(
      client_id: client.client_id,
      client_secret: secret,
      api: "wp_plugin_demo"
    )

    assert result.failure?
    assert_equal "client is not registered for this API", result.error
  end

  test "confidential client registered on the named API authenticates there" do
    client, secret = create_oauth_client(
      name: "Named Secret App",
      confidential: true,
      api: "wp_plugin_demo"
    )

    result = RecordingStudioOauth::Services::AuthenticateOauthClient.call(
      client_id: client.client_id,
      client_secret: secret,
      api: "wp_plugin_demo"
    )

    assert result.success?
    assert_equal client.id, result.value.id
  end

  test "confidential client registered on the named API fails with the wrong secret" do
    client, = create_oauth_client(
      name: "Named Secret App",
      confidential: true,
      api: "wp_plugin_demo"
    )

    result = RecordingStudioOauth::Services::AuthenticateOauthClient.call(
      client_id: client.client_id,
      client_secret: "wrong-secret",
      api: "wp_plugin_demo"
    )

    assert result.failure?
    assert_equal "client authentication failed", result.error
  end

  test "public client must not send a client secret" do
    client, = create_oauth_client(name: "Handmade Public App")

    result = RecordingStudioOauth::Services::AuthenticateOauthClient.call(
      client_id: client.client_id,
      client_secret: "unexpected-secret",
      api: "wp_plugin_demo"
    )

    assert result.failure?
    assert_equal "public clients must not send a client secret", result.error
  end
end
