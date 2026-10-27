# frozen_string_literal: true

require "test_helper"

class OauthAuthorizationRolesTest < Minitest::Test
  def test_role_names_and_ranks_come_from_accessible
    names = RecordingStudioOauth::OauthAuthorization.role_names

    assert_includes names, "view"
    assert_includes names, "edit"
    assert_includes names, "admin"
    assert_equal 0, RecordingStudioOauth::OauthAuthorization.role_rank(:view)
    assert_equal 1, RecordingStudioOauth::OauthAuthorization.role_rank("edit")
    assert_equal 2, RecordingStudioOauth::OauthAuthorization.role_rank(:admin)
    assert RecordingStudioOauth::OauthAuthorization.role_at_or_below?("view", "edit")
    refute RecordingStudioOauth::OauthAuthorization.role_at_or_below?("admin", "view")
  end

  def test_oauth_does_not_keep_a_parallel_rank_table
    configuration = File.read(File.expand_path("../lib/recording_studio_oauth/configuration.rb", __dir__))
    model = File.read(File.expand_path("../app/models/recording_studio_oauth/oauth_authorization.rb", __dir__))

    refute_includes configuration, "ACCESS_ROLE_RANKS"
    refute_includes model, "ACCESS_ROLE_RANKS"
    assert_includes model, "RecordingStudio::Access.roles"
    assert_includes model, "RecordingStudio::AccessRoles::ORDER"
  end
end
