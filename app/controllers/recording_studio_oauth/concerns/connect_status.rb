# frozen_string_literal: true

module RecordingStudioOauth
  module Concerns
    module ConnectStatus
      extend ActiveSupport::Concern

      CONNECT_BUTTON_STYLE = {
        "connect" => :default,
        "reconnect" => :danger,
        "connected" => :success
      }.freeze

      included do
        helper_method :connection_status_for, :connection_status_trailing
      end

      private

      def connection_status_for(access_recording)
        Copy.t("connect.status.#{connection_status_key_for(access_recording)}")
      end

      def connection_status_trailing(access_recording)
        status_key = connection_status_key_for(access_recording)
        button = connect_status_button(status_key, access_recording)
        return button unless status_key == "reconnect"

        view_context.render(FlatPack::Tooltip::Component.new(text: Copy.t("connect.reconnect_hint"), placement: :top)) { button }
      end

      def connect_status_button(status_key, access_recording)
        view_context.render FlatPack::Button::Component.new(
          text: Copy.t("connect.status.#{status_key}"),
          style: CONNECT_BUTTON_STYLE.fetch(status_key),
          size: :sm,
          href: connect_choice_url(access_recording)
        )
      end

      def connection_status_key_for(access_recording)
        authorizations = OauthAuthorization.where(
          oauth_client: @oauth_client,
          manager_actor: current_oauth_actor,
          manager_access_recording: access_recording
        )
        return "connect" if authorizations.none?
        return "connected" if authorizations.any?(&:active?)

        "reconnect"
      end
    end
  end
end
