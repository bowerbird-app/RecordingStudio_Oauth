# frozen_string_literal: true

module RecordingStudioOauth
  module Admin
    module MetricChartWidgets
      SPECS = [
        {
          key: "oauth.self_registered_over_time",
          title: "Self-registered apps",
          info: "Apps that signed themselves up and can still Connect.",
          count: -> { OauthClient.active.where(self_registered: true).count },
          screen: "oauth_clients",
          link_params: { source: "self_registered" },
          link_label: "Registered apps"
        },
        {
          key: "oauth.granted_over_time",
          title: "Connections granted",
          info: "Connections that are still on.",
          count: -> { OauthAuthorization.active.count },
          screen: "oauth_connections",
          link_params: { status: "active" },
          link_label: "Connections"
        },
        {
          key: "oauth.revoked_over_time",
          title: "Connections revoked",
          info: "Connections that were ended.",
          count: -> { OauthAuthorization.where.not(revoked_at: nil).count },
          screen: "oauth_connections",
          link_params: { status: "revoked" },
          link_label: "Connections"
        }
      ].freeze

      WIDGETS = SPECS.map do |spec|
        RecordingStudioAdmin::Widget.new(spec.fetch(:key)) do
          type :number
          title spec.fetch(:title)
          info spec.fetch(:info)
          value { spec.fetch(:count).call }
          hide_change
          hide_period
          blast_radius :site
          link_to do |context|
            RecordingStudioOauth::Admin::OauthClientsFilters.screen_path(
              context,
              spec.fetch(:link_params),
              screen: spec.fetch(:screen)
            )
          end
          link_label spec.fetch(:link_label)
        end
      end.freeze

      module_function

      def register!
        WIDGETS.each { |widget| RecordingStudioAdmin.register_widget(widget) }
      end
    end
  end
end
