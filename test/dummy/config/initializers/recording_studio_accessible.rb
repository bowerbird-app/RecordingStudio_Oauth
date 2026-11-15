# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  config.access_actor_types = [
    "User",
    "RecordingStudioApi::ApiClient",
    "RecordingStudioOauth::OauthAuthorization"
  ]

  # Admin 2.15 site screens ask Accessible for this root. The same kept
  # Admin recording is the staff access recording.
  config.admin_root_resolver = lambda do
    admin_root = AdminRoot.find_by(name: "Admin")
    next unless admin_root

    RecordingStudio::Recording.kept.find_by(recordable: admin_root, parent_recording_id: nil)
  end
end
