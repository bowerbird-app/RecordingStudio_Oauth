# frozen_string_literal: true

module RecordingStudioOauth
  module Admin
    module_function

    def engine_mount_path
      RecordingStudioOauth.configuration.engine_mount_path.to_s.presence || "/recording_studio_oauth"
    end

    def new_oauth_client_path
      Engine.routes.url_helpers.new_admin_oauth_client_path(script_name: engine_mount_path)
    end

    def oauth_clients_path
      Engine.routes.url_helpers.admin_oauth_clients_path(script_name: engine_mount_path)
    end

    def oauth_client_path(client)
      Engine.routes.url_helpers.admin_oauth_client_path(client, script_name: engine_mount_path)
    end

    def revoke_oauth_client_path(client)
      Engine.routes.url_helpers.admin_revoke_oauth_client_path(client, script_name: engine_mount_path)
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

    class OauthClientsResource < RecordingStudioAdmin::Resource
      key "oauth_clients"
      section "oauth_apps"
      title "Registered apps"
      blast_radius :site

      action :create,
             text: "New app",
             method: :post,
             url: ->(_row, _context) { RecordingStudioOauth::Admin.oauth_clients_path },
             required_role: :view
    end

    class OauthClientsScreen < RecordingStudioAdmin::Screen
      key "oauth_clients"
      title "Registered apps"
      subtitle "Add an app, or revoke one to stop new connections."
      blast_radius :site
      query { |_context| OauthClient.order(:name) }

      button :new,
             text: "New app",
             style: :primary,
             url: ->(_context) { RecordingStudioOauth::Admin.new_oauth_client_path }

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
      RecordingStudioAdmin.register_resource(OauthClientsResource)
      RecordingStudioAdmin.register_screen(OauthClientsScreen)
      @registered = true
    end
  end
end
