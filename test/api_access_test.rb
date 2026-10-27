# frozen_string_literal: true

require "test_helper"

class ApiAccessTest < Minitest::Test
  def test_admin_root_recording_uses_admin_resolver_only
    captured = nil
    controller = Object.new
    recording = Object.new
    resolver = lambda do |context|
      captured = context
      recording
    end
    configuration = Struct.new(:access_recording_resolver).new(resolver)

    RecordingStudioAdmin.stub(:configuration, configuration) do
      result = RecordingStudioOauth::Api::Access.admin_root_recording(controller: controller)

      assert_same recording, result
      assert_equal controller, captured.controller
    end
  end

  def test_admin_root_recording_is_nil_without_resolver
    configuration = Struct.new(:access_recording_resolver).new(nil)

    RecordingStudioAdmin.stub(:configuration, configuration) do
      assert_nil RecordingStudioOauth::Api::Access.admin_root_recording
    end
  end

  def test_oauth_clients_controller_does_not_scan_admin_roots
    source = File.read(
      File.expand_path("../app/controllers/recording_studio_oauth/admin/oauth_clients_controller.rb", __dir__)
    )

    assert_includes source, "Api::Access.admin_root_recording(controller: self)"
    refute_includes source, "admin_root_recordable_type_names"
    refute_includes source, "Recording.unscoped"
  end
end
