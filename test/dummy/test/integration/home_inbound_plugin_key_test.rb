# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class HomeInboundPluginKeyTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "home shows the seed plugin key and inbound connection status" do
    load Rails.root.join("db/seeds.rb")
    user = User.find_by!(email: "admin@admin.com")
    studio = Workspace.find_by!(name: "Studio Workspace")
    sign_in user
    switch_to_studio!(RecordingStudio.root_recording_for(studio))

    get root_path

    assert_response :success
    assert_includes response.body, "inbound_demo"
    assert_includes response.body, "Inbound connected: yes"
    assert_includes response.body, "People connected: 1"
  end

  private

  def switch_to_studio!(root_recording)
    patch recording_studio_root_switchable.root_switch_path(scope: "all_workspaces"), params: {
      root_switch: {
        root_recording_id: root_recording.id,
        return_to: "/"
      }
    }
    follow_redirect! if response.redirect?
  end
end
