# frozen_string_literal: true

module RecordingStudioOauth
  module Admin
    module OauthClientsFilters
      SOURCE_FILTERS = {
        "staff" => false,
        "self_registered" => true
      }.freeze
      STATUS_FILTERS = %w[active revoked].freeze

      module_function

      def filtered_clients(_context)
        OauthClient.active.order(:name)
      end

      def filtered_connections(_context)
        OauthAuthorization.active.includes(:oauth_client).order(created_at: :desc)
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

      def screen_path(context, extra = {}, screen: "oauth_clients")
        path = context.admin_screen_path(screen)
        query = extra.compact
        return path if query.empty?

        "#{path}?#{query.to_query}"
      end
    end
  end
end
