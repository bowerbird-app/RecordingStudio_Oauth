# frozen_string_literal: true

require "test_helper"

class GrantRegistrationTest < Minitest::Test
  def test_register_does_not_raise
    RecordingStudioOauth::GrantRegistration.register!
  end
end
