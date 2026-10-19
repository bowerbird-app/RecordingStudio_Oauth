# frozen_string_literal: true

RecordingStudioAdmin.configure do |config|
  config.default_mount_path = "/admin"
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user
  config.async_widgets.enabled = false
  config.access_recording_resolver = lambda do |_context|
    admin_root = AdminRoot.find_by(name: "Admin")
    next unless admin_root

    # Same base as main (no unscoped) plus additive kept_sql (not the shared
    # active scope, which unscopes trashed_at first).
    RecordingStudio::Recording
      .where(RecordingStudio::Recording.recording_studio_trashable_kept_sql)
      .find_by(recordable: admin_root, parent_recording_id: nil)
  end
  config.site_admin_recording_resolver = config.access_recording_resolver
  config.engine_layout = "recording_studio/default_layout"
end

class DummyAdminRootSection < RecordingStudioAdmin::Section
  key "root"
  title "Admin"
  blast_radius :site
  widget "oauth.active_apps", view_variant: :compact
  widget "oauth.active_connections", view_variant: :compact
  widget "oauth.self_registered_over_time"
  widget "oauth.granted_over_time"
  widget "oauth.revoked_over_time"
  link :oauth_apps, text: "Registered apps", url: ->(context) { context.admin_section_path("oauth_apps") }
end

Rails.application.config.to_prepare do
  RecordingStudioAdmin.register_section(DummyAdminRootSection)
end
