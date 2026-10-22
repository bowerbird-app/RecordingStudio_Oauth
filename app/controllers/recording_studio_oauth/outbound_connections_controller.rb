# frozen_string_literal: true

module RecordingStudioOauth
  class OutboundConnectionsController < ApplicationController
    include Concerns::HostAuthentication

    before_action :authenticate_host_user!
    before_action :set_current_actor

    def connect
      result = Services::StartOutboundConnect.call(
        provider: params[:provider],
        actor: current_oauth_actor,
        owner_kind: owner_kind_from_params,
        root: load_root_recording,
        return_to: safe_return_to,
        callback_url: callback_absolute_url
      )
      return redirect_failed(result) if result.failure?

      write_handshake_cookie(result.value.fetch(:handshake))
      redirect_to result.value.fetch(:location), allow_other_host: true
    end

    def callback
      handshake = read_handshake_cookie
      result = Services::FinishOutboundConnect.call(
        handshake: handshake,
        state: params[:state],
        code: params[:code],
        actor: current_oauth_actor,
        callback_url: callback_absolute_url
      )
      clear_handshake_cookie
      return redirect_failed(result) if result.failure?

      redirect_to safe_return_to(result.value[:return_to]), notice: Copy.t("outbound.flashes.connected")
    end

    def destroy
      connection = OutboundConnection.find_by(id: params[:id])
      result = Services::DisconnectOutboundConnection.call(connection: connection, actor: current_oauth_actor)
      return redirect_failed(result) if result.failure?

      redirect_to safe_return_to, notice: Copy.t("outbound.flashes.disconnected")
    end

    private

    def owner_kind_from_params
      requested = params[:owner].to_s
      return requested if [OutboundConnection::OWNER_ROOT, OutboundConnection::OWNER_USER].include?(requested)
      return OutboundConnection::OWNER_ROOT if params[:root_recording_id].present?

      OutboundConnection::OWNER_USER
    end

    def load_root_recording
      id = params[:root_recording_id].to_s.presence
      return if id.blank?

      RecordingStudio::Recording.find_by(id: id)
    end

    def write_handshake_cookie(handshake)
      cookies.encrypted[Outbound::Handshake::COOKIE_NAME] = {
        value: handshake.payload.to_json,
        expires: 10.minutes.from_now,
        httponly: true,
        same_site: :lax
      }
    end

    def read_handshake_cookie
      Outbound::Handshake.from_cookie(cookies.encrypted[Outbound::Handshake::COOKIE_NAME])
    end

    def clear_handshake_cookie
      cookies.delete(Outbound::Handshake::COOKIE_NAME)
    end

    def callback_absolute_url
      origin = RecordingStudioOauth.configuration.public_origin.to_s.strip.presence
      return "#{origin.chomp('/')}#{engine_mount}/outbound/callback" if origin.present?

      outbound_callback_url
    end

    def engine_mount
      RecordingStudioOauth.configuration.engine_mount_path.to_s.presence || "/recording_studio_oauth"
    end

    def safe_return_to(value = params[:return_to])
      path = value.to_s
      return "/" if path.blank?
      return "/" unless path.start_with?("/") && !path.start_with?("//")

      path
    end

    def redirect_failed(result)
      redirect_to safe_return_to, alert: outbound_alert(result.error)
    end

    def outbound_alert(error)
      key = error.is_a?(Symbol) ? error : :invalid_request
      Copy.t("outbound.errors.#{key}", default: Copy.t("outbound.errors.invalid_request"))
    end
  end
end
