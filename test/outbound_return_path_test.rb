# frozen_string_literal: true

require "test_helper"

class OutboundReturnPathTest < Minitest::Test
  def test_keeps_a_relative_app_path
    assert_equal "/workspace", RecordingStudioOauth::ReturnUrlRules.safe_relative_path("/workspace")
  end

  def test_rejects_protocol_relative_and_off_site_targets
    ["//evil", "/\\evil", "https://evil", "javascript:alert(1)"].each do |value|
      assert_nil RecordingStudioOauth::ReturnUrlRules.safe_relative_path(value), value
    end
  end

  def test_rejects_whitespace_and_control_characters
    [" /workspace", "/workspace\n", "/workspace\t", "/workspace\r", "/workspace\u007F"].each do |value|
      assert_nil RecordingStudioOauth::ReturnUrlRules.safe_relative_path(value)
    end
  end
end
