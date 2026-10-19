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
          info: "New connections by day. Revoked ones still count here."
        },
        {
          key: "oauth.revoked_over_time",
          metric: "oauth_authorizations.revoked_over_time",
          title: "Connections revoked",
          info: "Connections ended that day."
        }
      ].freeze

      WIDGETS = SPECS.map do |spec|
        metric = spec.fetch(:metric)
        RecordingStudioAdmin::Widget.new(spec.fetch(:key)) do
          type :chart
          title spec.fetch(:title)
          info spec.fetch(:info)
          chart_type :area
          series { |context| RecordingStudioOauth::Admin::MetricChartWidgets.series(metric, context) }
          hide_change
          hide_period
          blast_radius :site
          link_to { |context| context.admin_screen_path("oauth_clients") }
          link_label "Registered apps"
        end
      end.freeze

      module_function

      def series(identifier, context)
        RecordingStudioMetrics::Admin.chart_series(
          identifier,
          admin_context: context,
          interval: :day,
          scope: :site,
          site_authorized: true
        )
      end

      def register!
        WIDGETS.each { |widget| RecordingStudioAdmin.register_widget(widget) }
      end
    end
  end
end
