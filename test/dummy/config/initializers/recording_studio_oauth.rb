# frozen_string_literal: true

RecordingStudioOauth.configure do |config|
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user
  config.admin_root_recordable_type_names = ["AdminRoot"]
  config.connectable_root_recordable_type_names = ["Workspace"]
  config.api_mount_path = "/recording_studio_api"
  config.engine_mount_path = "/recording_studio_oauth"
  config.mcp_mount_path = "/recording_studio_mcp"
  config.register_origin_as_protected_resource = false
  config.extra_protected_resource_paths = []
  config.allow_registration = false
  config.allow_self_registered_apps = true
  config.layout = ->(controller:) { "application" if controller.devise_controller? }
end

require Rails.root.join("app/models/fake_oauth")

fake_drive_http = {
  authorize_url: "/fake_oauth/authorize",
  token_url: "/fake_oauth/token",
  revoke_url: "/fake_oauth/revoke",
  scopes: ["files.read"],
  client_id: FakeOauth::CLIENT_ID,
  client_secret: FakeOauth::CLIENT_SECRET,
  pkce: true,
  refresh: true,
  http: FakeOauth
}

RecordingStudioOauth.register_outbound_provider(
  **fake_drive_http,
  key: :fake_drive,
  kind: :root
)

RecordingStudioOauth.register_outbound_provider(
  **fake_drive_http,
  key: :fake_drive_user,
  kind: :user
)
