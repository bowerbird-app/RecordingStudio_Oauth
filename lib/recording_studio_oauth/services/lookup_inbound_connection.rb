# frozen_string_literal: true

module RecordingStudioOauth
  module Services
    class LookupInboundConnection < RecordingStudio::Services::BaseService
      def initialize(plugin_key:, root:, actor:)
        @plugin_key = OauthClient.normalize_plugin_key(plugin_key)
        @root = root
        @actor = actor
      end

      private

      attr_reader :plugin_key, :root, :actor

      def perform
        success(
          {
            connected: connected?,
            connected_count: connected_count,
            people: people
          }.freeze
        )
      end

      # Builds the people list on purpose (small scale: one plugin_key in one workspace).
      def connected?
        return false unless may_view_root?
        return false if plugin_key.blank?

        people_rows.any? { |row| same_actor?(row) }
      end

      def connected_count
        return unless may_manage_root?
        return 0 if plugin_key.blank?

        people_rows.size
      end

      def people
        return [] unless may_manage_root?
        return [] if plugin_key.blank?

        people_rows
      end

      def people_rows
        @people_rows ||= build_people_rows
      end

      def may_view_root?
        Outbound::Access.may_use_root?(actor: actor, root: root)
      end

      def may_manage_root?
        Outbound::Access.may_manage_root?(actor: actor, root: root)
      end

      def same_actor?(row)
        row.fetch(:actor_type) == actor_type && row.fetch(:actor_id).to_s == actor.id.to_s
      end

      def actor_type
        return if actor.nil?

        actor.class.base_class.name
      end

      def build_people_rows
        authorizations = connected_authorizations
        return [] if authorizations.empty?

        last_used_by_id = OauthAccessToken.where(oauth_authorization_id: authorizations.map(&:id))
                                          .group(:oauth_authorization_id)
                                          .maximum(:last_used_at)

        grouped = authorizations.group_by { |row| [row.manager_actor_type, row.manager_actor_id.to_s] }
        grouped.map { |(_key, rows)| person_hash(rows, last_used_by_id) }
               .sort_by { |row| [row.fetch(:connected_at).to_f, row.fetch(:actor_type), row.fetch(:actor_id)] }
               .map(&:freeze)
               .freeze
      end

      def person_hash(rows, last_used_by_id)
        earliest = rows.min_by(&:created_at)
        names = rows.map { |row| row.oauth_client.name.to_s }.uniq.sort
        last_used = rows.map { |row| last_used_by_id[row.id] }.compact.max
        role = rows.max_by { |row| OauthAuthorization.role_rank(row.role).to_i }.role

        {
          actor_type: earliest.manager_actor_type,
          actor_id: earliest.manager_actor_id,
          role: role,
          connected_at: earliest.created_at,
          last_used_at: last_used,
          app_name: names.join(", ")
        }
      end

      def connected_authorizations
        @connected_authorizations ||= candidate_authorizations
                                      .select { |authorization| authorization.workspace_recording == root }
                                      .select(&:active?)
      end

      def candidate_authorizations
        return [] if plugin_key.blank? || root.nil?

        OauthAuthorization
          .joins(:oauth_client)
          .merge(OauthClient.active.for_plugin_key(plugin_key))
          .where(revoked_at: nil)
          .where(usable_token_sql)
          .includes(
            :oauth_client,
            access_recording: [ :parent_recording, :root_recording ],
            manager_access_recording: [ :parent_recording, :root_recording ]
          )
          .to_a
      end

      def usable_token_sql
        auth_id = "#{OauthAuthorization.quoted_table_name}.#{OauthAuthorization.connection.quote_column_name('id')}"
        access_exists = OauthAccessToken.active
                                        .where("#{OauthAccessToken.quoted_table_name}.oauth_authorization_id = #{auth_id}")
                                        .select(1)
                                        .arel
                                        .exists
        refresh_exists = OauthRefreshToken.active
                                          .where("#{OauthRefreshToken.quoted_table_name}.oauth_authorization_id = #{auth_id}")
                                          .select(1)
                                          .arel
                                          .exists
        access_exists.or(refresh_exists)
      end

      def service_args
        { plugin_key: plugin_key, root_id: root.respond_to?(:id) ? root.id : nil }
      end
    end
  end
end
