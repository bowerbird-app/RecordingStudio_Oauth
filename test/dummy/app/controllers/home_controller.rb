class HomeController < ApplicationController
  def index
    @oauth_client = RecordingStudioOauth::OauthClient.find_by(name: "Seed Demo App")
    root = current_root_recording
    return if @oauth_client.blank? || root.blank? || current_user.blank?

    @inbound_status = RecordingStudioOauth.inbound_connection_status(
      plugin_key: @oauth_client.plugin_key,
      root: root,
      actor: current_user
    )
    @inbound_connections = RecordingStudioOauth.inbound_connections(
      plugin_key: @oauth_client.plugin_key,
      root: root,
      actor: current_user
    )
  end

  def connect_demo
    client = RecordingStudioOauth::OauthClient.find_by!(name: "Seed Demo App")
    verifier = "V#{SecureRandom.urlsafe_base64(32)}"
    verifier = verifier.ljust(43, "a")
    session[:oauth_code_verifier] = verifier

    redirect_to recording_studio_oauth.oauth_authorize_path(
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris.first,
      state: "dummy",
      code_challenge: RecordingStudioOauth::Pkce.s256_challenge(verifier),
      code_challenge_method: "S256"
    ), allow_other_host: false
  end
end
