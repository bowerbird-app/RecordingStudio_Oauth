# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudioOauth::Configuration.new
  end

  def test_defaults
    assert_equal :authenticate_user!, @configuration.authentication_method
    assert_equal :current_user, @configuration.current_actor_method
    assert_equal ["AdminRoot"], @configuration.admin_root_recordable_type_names
    assert_equal "/recording_studio_api", @configuration.api_mount_path
    assert_instance_of RecordingStudio::Hooks, @configuration.hooks
  end

  def test_merge_updates_known_attributes
    @configuration.merge!(api_mount_path: "/api", authentication_method: :authenticate_person!)

    assert_equal "/api", @configuration.api_mount_path
    assert_equal :authenticate_person!, @configuration.authentication_method
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!(unknown_key: "ignored", api_mount_path: "/ok")

    refute_respond_to @configuration, :unknown_key
    assert_equal "/ok", @configuration.api_mount_path
  end

  def test_merge_with_non_enumerable_is_noop
    original = @configuration.to_h

    @configuration.merge!(nil)

    assert_equal original.fetch(:api_mount_path), @configuration.api_mount_path
  end

  def test_merge_accepts_string_keys
    @configuration.merge!("api_mount_path" => "/from-string")

    assert_equal "/from-string", @configuration.api_mount_path
  end

  def test_to_h_reports_registered_hook_counts
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.after_service { nil }

    result = @configuration.to_h

    assert_equal 2, result.fetch(:hooks_registered).fetch(:before_initialize)
    assert_equal 1, result.fetch(:hooks_registered).fetch(:after_service)
  end

  def test_configure_without_block_is_safe
    RecordingStudioOauth.configure

    assert_kind_of RecordingStudioOauth::Configuration, RecordingStudioOauth.configuration
  end
end
