# frozen_string_literal: true

require "test_helper"

class OauthAuthorizationRolesTest < ActiveSupport::TestCase
  test "role names and ranks follow Accessible Access.roles" do
    names = RecordingStudioOauth::OauthAuthorization.role_names
    ranks = RecordingStudio::Access.roles

    assert_equal ranks.keys.map(&:to_s), names
    assert_equal ranks["view"] || ranks[:view], RecordingStudioOauth::OauthAuthorization.role_rank(:view)
    assert_equal ranks["admin"] || ranks[:admin], RecordingStudioOauth::OauthAuthorization.role_rank("admin")
    assert RecordingStudioOauth::OauthAuthorization.role_at_or_below?("view", "edit")
    refute RecordingStudioOauth::OauthAuthorization.role_at_or_below?("admin", "view")
  end
end
