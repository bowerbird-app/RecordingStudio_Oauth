# frozen_string_literal: true

require "test_helper"

class OauthClientPluginKeyTest < ActiveSupport::TestCase
  include OauthDummyHelpers

  test "blank plugin_key becomes nil" do
    client, = create_oauth_client(plugin_key: "  ")

    assert_nil client.plugin_key
    assert client.valid?
  end

  test "plugin_key is stripped and downcased" do
    client, = create_oauth_client(plugin_key: "  Inbound_Demo  ")

    assert_equal "inbound_demo", client.plugin_key
  end

  test "plugin_key must start with a letter and use lowercase letters digits and underscores" do
    client, = create_oauth_client
    client.plugin_key = "1bad"
    refute client.valid?
    assert client.errors[:plugin_key].any?

    client.plugin_key = "bad-key"
    refute client.valid?

    client.plugin_key = "ok_key2"
    assert client.valid?

    client.plugin_key = "a" + ("b" * 63)
    assert client.valid?

    client.plugin_key = "a" + ("b" * 64)
    refute client.valid?
  end

  test "two clients may share a plugin_key" do
    first, = create_oauth_client(name: "App One", plugin_key: "shared_inbound_key")
    second, = create_oauth_client(name: "App Two", plugin_key: "shared_inbound_key")

    assert_equal "shared_inbound_key", first.plugin_key
    assert_equal first.plugin_key, second.plugin_key
    assert_equal 2, RecordingStudioOauth::OauthClient.where(plugin_key: "shared_inbound_key").count
  end
end
