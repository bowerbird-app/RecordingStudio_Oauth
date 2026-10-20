# frozen_string_literal: true

module RecordingStudioOauth
  module Admin
    module MetricChartWidgets
      SPECS = [
        {
          key: "oauth.self_registered_over_time",
          metric: "oauth_clients.self_registered_over_time",
          title: "Self-registered apps",
          info: "Apps that signed themselves up and can still Connect.",
          count: -> { OauthClient.active.where(self_registered: true).count },
          screen: "oauth_clients",
          link_params: { source: "self_registered" },
          link_label: "Registered apps"
        },
        {
          key: "oauth.granted_over_time",
          metric: "oauth_authorizations.granted_over_time",
          title: "Connections granted",
          info: "Connections that are still on.",
          count: -> { OauthAuthorization.active.count },
          screen: "oauth_connections",
          link_params: { status: "active" },
          link_label: "Connections"
        },
        {
          key: "oauth.revoked_over_time",
          metric: "oauth_authorizations.revoked_over_time",
          title: "Connections revoked",
          info: "Connections that were ended.",
          count: -> { OauthAuthorization.where.not(revoked_at: nil).count },
          screen: "oauth_connections",
          link_params: { status: "revoked" },
          link_label: "Connections"
        }
      ].freeze
      PERIOD_LABEL = "Last 12 months"

      WIDGETS = SPECS.map do |spec|
        metric = spec.fetch(:metric)
        RecordingStudioAdmin::Widget.new(spec.fetch(:key)) do
          type :chart
          title spec.fetch(:title)
          info spec.fetch(:info)
          metadata { { period_label: RecordingStudioOauth::Admin::MetricChartWidgets::PERIOD_LABEL } }
          value { spec.fetch(:count).call }
          chart_type :area
          series { |context| RecordingStudioOauth::Admin::MetricChartWidgets.series(metric, context) }
          chart_options { { height: 220 } }
          hide_change
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

      def series(identifier, context)
        raw_series(identifier, context)
      end

      def total(identifier, context)
        series(identifier, context).sum do |row|
          Array(row[:data] || row["data"]).sum { |point| point_y(point) }
        end
      end

      def register!
        WIDGETS.each { |widget| RecordingStudioAdmin.register_widget(widget) }
      end

      def execute_params
        {
          interval: :day,
          start_at: 365.days.ago,
          scope: :site,
          site_authorized: true
        }
      end

      def raw_series(identifier, context)
        RecordingStudioMetrics::Admin.chart_series(
          identifier,
          admin_context: context,
          **execute_params
        )
      end

      def point_y(point)
        return 0 unless point.is_a?(Hash)

        (point[:y] || point["y"]).to_i
      end
    end
  end
end
