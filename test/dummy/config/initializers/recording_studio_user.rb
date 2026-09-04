# frozen_string_literal: true

# Route configuration must load before Rails draws routes.
RecordingStudioUser.configure do |config|
  config.user_class_name = "User"
  config.mount_path = "/recording_studio_users"
  config.profile_route_path = "profile"
  config.admin_route_path = "admin"
  # Layout for the engine's signed-in screens. Sign in and sign up keep the
  # gem's own centered layout, "recording_studio_user/auth".
  config.layout = "recording_studio/default_layout"
  config.additional_profile_attributes = []
  config.require_password_confirmation = false
  # Preferred sign-in path after email: :email → password (default), :otp → code.
  config.primary_login_type = :email
  # OmniAuth. Leave empty so Continue-with buttons follow Rails credentials under
  # `omniauth:`. Dummy test/dev registers a fake Google client so the OAuth
  # journey can show social on screen 1 without shipping real secrets.
  config.omniauth_providers = if Rails.env.local?
    {
      google_oauth2: {
        client_id: "dummy-google-client-id",
        client_secret: "dummy-google-client-secret"
      }
    }
  else
    {}
  end
  config.omniauth_create_account = true
  config.otp_enabled = false
end
