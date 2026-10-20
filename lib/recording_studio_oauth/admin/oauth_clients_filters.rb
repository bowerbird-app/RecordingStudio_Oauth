# frozen_string_literal: true

module RecordingStudioOauth
  module Admin
    module OauthClientsFilters
      SOURCE_FILTERS = {
        "staff" => false,
        "self_registered" => true
      }.freeze
      STATUS_FILTERS = %w[active revoked].freeze
      CONNECTION_FILTERS = %w[granted revoked].freeze

      module_function

      def filtered_clients(context)
        apply_connections(RecordingStudioOauth::OauthClient.active.order(:name), request_param(context, :connections))
      end

      def filtered_connections(_context)
        RecordingStudioOauth::OauthAuthorization.active.includes(:oauth_client).order(created_at: :desc)
      end

      def apply_source(relation, value)
        return relation unless SOURCE_FILTERS.key?(value.to_s)

        relation.where(self_registered: SOURCE_FILTERS.fetch(value.to_s))
      end

      def apply_status(relation, value)
        case value.to_s
        when "revoked"
          relation.unscope(where: :revoked_at).where.not(revoked_at: nil)
        when "active"
          relation.unscope(where: :revoked_at).where(revoked_at: nil)
        else
          relation
        end
      end

      def apply_connections(relation, value)
        return relation unless CONNECTION_FILTERS.include?(value.to_s)

        started = MetricChartWidgets.execute_params[:start_at]
        grants = RecordingStudioOauth::OauthAuthorization.all
        scoped = if value.to_s == "granted"
                   grants.where(created_at: started..)
                 else
                   grants.where.not(revoked_at: nil).where(revoked_at: started..)
                 end
        relation.unscope(where: :revoked_at).where(id: scoped.select(:oauth_client_id))
      end

      def screen_path(context, extra = {}, screen: "oauth_clients")
        path = context.admin_screen_path(screen)
        query = extra.compact
        return path if query.empty?

        "#{path}?#{query.to_query}"
      end

      def request_param(context, key)
        params = context.respond_to?(:params) ? context.params : {}
        params[key] || params[key.to_s]
      end
    end
  end
end
