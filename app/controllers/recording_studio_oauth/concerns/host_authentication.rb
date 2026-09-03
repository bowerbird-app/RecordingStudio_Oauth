# frozen_string_literal: true

module RecordingStudioOauth
  module Concerns
    module HostAuthentication
      extend ActiveSupport::Concern

      included do
        helper_method :current_oauth_actor
      end

      private

      def authenticate_host_user!
        method_name = RecordingStudioOauth.configuration.authentication_method
        return public_send(method_name) if respond_to?(method_name, true)
        return authenticate_user! if respond_to?(:authenticate_user!, true)

        head :unauthorized
      end

      def set_current_actor
        Current.actor = current_oauth_actor if defined?(Current) && Current.respond_to?(:actor=)
      end

      def current_oauth_actor
        method_name = RecordingStudioOauth.configuration.current_actor_method
        return public_send(method_name) if method_name.present? && respond_to?(method_name, true)
        return current_user if respond_to?(:current_user, true) && current_user.present?
        return Current.actor if defined?(Current) && Current.respond_to?(:actor)

        nil
      end
    end
  end
end
