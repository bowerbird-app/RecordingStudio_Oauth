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
        authorizations = connected_authorizations.to_a
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
        access = "inbound_access"
        manager = "inbound_manager"
        workspace = "inbound_workspace"
        grants = "inbound_grants"
        depends_on = "inbound_depends_on"
        auth_table = connection.quote_table_name(OauthAuthorization.table_name)
        recordings = connection.quote_table_name(RecordingStudio::Recording.table_name)
        accesses = connection.quote_table_name(RecordingStudio::Access.table_name)

        OauthAuthorization
          .joins(:oauth_client)
          .merge(OauthClient.active.for_plugin_key(plugin_key))
          .where(revoked_at: nil)
          .joins(<<~SQL.squish)
            INNER JOIN #{recordings} #{access}
              ON #{access}.id = #{auth_table}.access_recording_id
             AND #{kept_sql(access)}
            LEFT JOIN #{recordings} #{manager}
              ON #{manager}.id = #{auth_table}.manager_access_recording_id
            INNER JOIN #{recordings} #{workspace}
              ON #{workspace}.id = COALESCE(#{access}.parent_recording_id, #{access}.root_recording_id, #{manager}.parent_recording_id, #{manager}.root_recording_id)
             AND #{kept_sql(workspace)}
            INNER JOIN #{accesses} #{grants}
              ON #{grants}.id = #{access}.recordable_id
             AND #{access}.recordable_type = #{quote('RecordingStudio::Access')}
             AND #{grants}.actor_type = #{quote(OauthAuthorization.name)}
             AND #{grants}.actor_id = #{auth_table}.id
            LEFT JOIN #{recordings} #{depends_on}
              ON #{depends_on}.id = #{grants}.depends_on_recording_id
          SQL
          .where("#{workspace}.id = ?", root.id)
          .where(
            "#{grants}.depends_on_recording_id IS NULL OR (#{kept_sql(depends_on)} AND #{depends_on}.recordable_type = ?)",
            "RecordingStudio::Access"
          )
          .where(role_still_authorized_sql(grants))
          .where(usable_token_sql)
          .includes(:oauth_client)
      end

      def usable_token_sql
        auth_id = "#{OauthAuthorization.quoted_table_name}.#{connection.quote_column_name('id')}"
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

      def role_still_authorized_sql(grants)
        grant_rank = role_rank_sql("#{grants}.role")
        auth_rank = role_rank_sql("#{OauthAuthorization.quoted_table_name}.role")
        "#{grant_rank} >= #{auth_rank}"
      end

      def role_rank_sql(column)
        "CASE #{column} WHEN 'admin' THEN 2 WHEN 'edit' THEN 1 WHEN 'view' THEN 0 ELSE -1 END"
      end

      def kept_sql(table)
        RecordingStudio::Recording.recording_studio_trashable_kept_sql(table)
      end

      def quote(value)
        connection.quote(value)
      end

      def connection
        OauthAuthorization.connection
      end

      def service_args
        { plugin_key: plugin_key, root_id: root.respond_to?(:id) ? root.id : nil }
      end
    end
  end
end
