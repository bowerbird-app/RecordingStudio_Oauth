# frozen_string_literal: true

require "test_helper"

class OauthAuthorizationRolesTest < Minitest::Test
  def test_oauth_does_not_keep_a_parallel_rank_table
    configuration = File.read(File.expand_path("../lib/recording_studio_oauth/configuration.rb", __dir__))
    model = File.read(File.expand_path("../app/models/recording_studio_oauth/oauth_authorization.rb", __dir__))

    refute_includes configuration, "ACCESS_ROLE_RANKS"
    refute_includes model, "ACCESS_ROLE_RANKS"
    assert_includes model, "def self.role_names"
    assert_includes model, "RecordingStudio::Access.roles"
    assert_includes model, "RecordingStudio::AccessRoles::ORDER"
    refute_includes model, "ROLES = %w[view edit admin]"
  end
end
