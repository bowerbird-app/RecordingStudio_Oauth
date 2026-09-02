# frozen_string_literal: true

module RecordingStudioOauth
  module Admin
    module_function

    def revoke_oauth_client_path(client)
      mount = RecordingStudioOauth.configuration.engine_mount_path.to_s.presence || "/recording_studio_oauth"
      Engine.routes.url_helpers.admin_revoke_oauth_client_path(client, script_name: mount)
    end

    ActiveAppsWidget = RecordingStudioAdmin::Widget.new("oauth.active_apps") do
      type :number
      title "Registered apps"
      info "Apps people can Connect."
      value { RecordingStudioOauth::OauthClient.active.count }
      hide_change
      hide_period
      blast_radius :site
      link_to { |context| context.admin_screen_path("oauth_clients") }
    end

    ActiveConnectionsWidget = RecordingStudioAdmin::Widget.new("oauth.active_connections") do
      type :number
      title "Active connections"
      info "People who currently have an app connected."
      value { RecordingStudioOauth::OauthAuthorization.active.count }
      hide_change
      hide_period
      blast_radius :site
      link_to { |context| context.admin_screen_path("oauth_clients") }
    end

    class OauthAppsSection < RecordingStudioAdmin::Section
      key "oauth_apps"
      title "Registered apps"
      subtitle "Apps people can Connect."
      blast_radius :site
      widget "oauth.active_apps"
      widget "oauth.active_connections"
      link :apps, text: "View apps", url: ->(context) { context.admin_screen_path("oauth_clients") }
    end

    class OauthClientsScreen < RecordingStudioAdmin::Screen
      key "oauth_clients"
      title "Registered apps"
      subtitle "Revoke an app to stop new connections."
      blast_radius :site
      query { |_context| OauthClient.order(:name) }

      table do
        column :name
        column :confidential, title: "Secret", value: ->(row, _context) { row.confidential? ? "Has a secret" : "Public" }
        column :revoked_at, title: "Status", value: ->(row, _context) { row.revoked? ? "Revoked" : "Active" }
        action :revoke,
               text: "Revoke",
               url: ->(row, _context) { RecordingStudioOauth::Admin.revoke_oauth_client_path(row) },
               method: :post,
               confirm: ->(row, _context) { "Revoke #{row.name}?" },
               destructive: true,
               visible_if: ->(row, _context) { row.revoked_at.nil? }
      end
    end

    def register!
      return unless defined?(RecordingStudioAdmin)
      return if @registered

      RecordingStudioAdmin.register_widget(ActiveAppsWidget)
      RecordingStudioAdmin.register_widget(ActiveConnectionsWidget)
      RecordingStudioAdmin.register_section(OauthAppsSection)
      RecordingStudioAdmin.register_screen(OauthClientsScreen)
      @registered = true
    end
  end
end
