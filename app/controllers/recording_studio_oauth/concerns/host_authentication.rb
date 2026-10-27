# frozen_string_literal: true

module RecordingStudioOauth
  module Concerns
    module HostAuthentication
      extend ActiveSupport::Concern

      included do
        include RecordingStudioAccessible::ControllerAuth

        recording_studio_auth(
          config: -> { RecordingStudioOauth.configuration },
          prefix: :oauth,
          authenticate_method: :authenticate_host_user!,
          actor_method: :current_oauth_actor,
          set_current_actor_method: :set_current_actor,
          actor_resolution: :method_then_current
        )
        helper_method :current_oauth_actor
      end
    end
  end
end
