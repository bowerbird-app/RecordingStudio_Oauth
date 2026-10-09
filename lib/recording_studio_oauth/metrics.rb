# frozen_string_literal: true

require_relative "api/access"
require "recording_studio_metrics"

module RecordingStudioOauth
  module Metrics
    CLIENTS = :oauth_clients
    AUTHORIZATIONS = :oauth_authorizations
    API = :operations
    EXPOSE = { api: [API] }.freeze
    AUTHORIZE = ->(context) { RecordingStudioOauth::Api::Access.can_view?(context) }

    module_function

    def register!
      register_clients!
      register_authorizations!
    end

    def register_clients!
      RecordingStudioMetrics.register(
        CLIENTS,
        model: RecordingStudioOauth::OauthClient,
        blast_radius: :site,
        api_authorize: AUTHORIZE,
        scope: :active
      ) { RecordingStudioOauth::Metrics.define_clients(self) }
    end

    def register_authorizations!
      RecordingStudioMetrics.register(
        AUTHORIZATIONS,
        model: RecordingStudioOauth::OauthAuthorization,
        blast_radius: :site,
        api_authorize: AUTHORIZE
      ) { RecordingStudioOauth::Metrics.define_authorizations(self) }
    end

    def define_clients(dsl)
      dsl.count :total, title: "Registered apps", expose: EXPOSE
      dsl.breakdown :by_registration, title: "Apps by registration", field: :self_registered, expose: EXPOSE
    end

    def define_authorizations(dsl)
      dsl.timeseries :over_time, title: "New authorizations", field: :created_at, expose: EXPOSE
      dsl.breakdown :by_role, title: "Authorizations by role", field: :role, expose: EXPOSE, scope: :active
    end
  end
end
