# frozen_string_literal: true

require "uri"

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

      redirect_to result.value.fetch(:location), allow_other_host: true
    end

    def callback
      result = Services::FinishOutboundConnect.call(
        state: params[:state],
        code: params[:code],
        actor: current_oauth_actor,
        callback_url: callback_absolute_url
      )
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

      OutboundConnection::OWNER_USER
    end

    def load_root_recording
      id = params[:root_recording_id].to_s.presence
      return if id.blank?

      RecordingStudio::Recording.find_by(id: id)
    end

    def callback_absolute_url
      origin = RecordingStudioOauth.configuration.public_origin.to_s.strip.presence
      return outbound_callback_url if origin.blank?

      uri = URI.parse(origin)
      outbound_callback_url(protocol: uri.scheme, host: uri.host, port: uri.port)
    rescue URI::InvalidURIError
      outbound_callback_url
    end

    def safe_return_to(value = params[:return_to])
      ReturnUrlRules.safe_relative_path(value) || "/"
    end

    def redirect_failed(result)
      redirect_to safe_return_to, alert: outbound_alert(result.error)
    end

    def outbound_alert(error)
      Copy.t("outbound.errors.#{error}", default: Copy.t("outbound.errors.invalid_request"))
    end
  end
end
