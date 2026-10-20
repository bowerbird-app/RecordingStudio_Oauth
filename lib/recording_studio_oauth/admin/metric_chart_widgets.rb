# frozen_string_literal: true

module RecordingStudioOauth
  module Admin
    module MetricChartWidgets
      SPECS = [
        {
          key: "oauth.self_registered_over_time",
          metric: "oauth_clients.self_registered_over_time",
          title: "Self-registered apps",
          info: "Apps that signed themselves up, counted on the day they appeared."
        },
        {
          key: "oauth.granted_over_time",
          metric: "oauth_authorizations.granted_over_time",
          title: "Connections granted",
          info: "New connections by day. Revoked ones still count here.",
          link_params: { connections: "granted" }
        },
        {
          key: "oauth.revoked_over_time",
          metric: "oauth_authorizations.revoked_over_time",
          title: "Connections revoked",
          info: "Connections ended that day.",
          link_params: { connections: "revoked" }
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
          value { |context| RecordingStudioOauth::Admin::MetricChartWidgets.total(metric, context) }
          chart_type :area
          series { |context| RecordingStudioOauth::Admin::MetricChartWidgets.series(metric, context) }
          chart_options { { height: 220 } }
          hide_change
          blast_radius :site
          link_to do |context|
            RecordingStudioOauth::Admin::OauthClientsFilters.screen_path(context, spec[:link_params] || {})
          end
          link_label "Registered apps"
        end
      end.freeze

      module_function

      def series(identifier, context)
        format_series(raw_series(identifier, context))
      end

      def total(identifier, context)
        series(identifier, context).sum { |row| Array(row[:data]).sum { |point| point[:y].to_i } }
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

      def format_series(rows)
        Array(rows).map do |row|
          {
            name: row[:name] || row["name"],
            data: Array(row[:data] || row["data"]).map { |point| format_point(point) }
          }
        end
      end

      def format_point(point)
        return { x: point[0], y: point[1].to_i } unless point.is_a?(Hash)

        keyed = point.transform_keys(&:to_sym)
        { x: keyed[:x] || keyed[:date], y: (keyed[:y] || keyed[:value]).to_i }
      end
    end
  end
end
