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

    def edit_oauth_client_path(client)
      Engine.routes.url_helpers.edit_admin_oauth_client_path(client, script_name: engine_mount_path)
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
      widget "oauth.active_apps", view_variant: :compact
      widget "oauth.active_connections", view_variant: :compact
      widget "oauth.self_registered_over_time"
      widget "oauth.granted_over_time"
      widget "oauth.revoked_over_time"
      link :apps, text: "View apps", url: ->(context) { context.admin_screen_path("oauth_clients") }
      link :connections, text: "View connections", url: ->(context) { context.admin_screen_path("oauth_connections") }
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

      action :update,
             text: "Save app",
             method: :patch,
             url: ->(row, _context) { RecordingStudioOauth::Admin.oauth_client_path(row) },
             required_role: :view
    end

    SOURCE_CELLS = {
      false => {
        label: "Staff",
        style: :default,
        tooltip: "Someone on staff added this app."
      }.freeze,
      true => {
        label: "Self-registered",
        style: :info,
        tooltip: "This app signed itself up. Connecting still needs a person."
      }.freeze
    }.freeze

    def source_cell(row)
      SOURCE_CELLS.fetch(row.self_registered?)
    end

    SECRET_CELLS = {
      false => {
        label: "Public",
        style: :default,
        tooltip: "Cannot hide a password. No secret. Uses PKCE."
      }.freeze,
      true => {
        label: "Has a secret",
        style: :info,
        tooltip: "Lives on a server. Proves itself with a secret."
      }.freeze
    }.freeze

    def secret_cell(row)
      SECRET_CELLS.fetch(row.confidential?)
    end

    STATUS_CELLS = {
      false => {
        label: "Active",
        style: :success
      }.freeze,
      true => {
        label: "Revoked",
        style: :danger
      }.freeze
    }.freeze

    def status_cell(row)
      STATUS_CELLS.fetch(row.revoked?)
    end

    class OauthClientsScreen < RecordingStudioAdmin::Screen
      key "oauth_clients"
      title "Registered apps"
      subtitle "Add an app, or revoke one to stop new connections."
      blast_radius :site
      query { |context| OauthClientsFilters.filtered_clients(context) }
      filter_presentation :inline

      filter :source,
             options: OauthClientsFilters::SOURCE_FILTERS.keys,
             apply: ->(relation, value, _context) { OauthClientsFilters.apply_source(relation, value) }
      filter :status,
             options: OauthClientsFilters::STATUS_FILTERS,
             default: :active,
             apply: ->(relation, value, _context) { OauthClientsFilters.apply_status(relation, value) }
      filter :api,
             param: :api_key,
             field: :api_key,
             options: -> { RecordingStudioOauth::Integration.api_names }

      button :new,
             text: "New app",
             url: ->(_context) { RecordingStudioOauth::Admin.new_oauth_client_path }

      table do
        column :name
        column :self_registered,
               title: "Source",
               display: :badge,
               value: ->(row, _context) { RecordingStudioOauth::Admin.source_cell(row)[:label] },
               display_options: lambda { |row, _context, _value|
                 cell = RecordingStudioOauth::Admin.source_cell(row)
                 { text: cell[:label], style: cell[:style], size: :sm }
               },
               tooltip: ->(row, _context) { RecordingStudioOauth::Admin.source_cell(row)[:tooltip] }
        column :api_key,
               title: "API",
               value: ->(row, _context) { RecordingStudioOauth::Integration.human_api_name(row.api_key) },
               tooltip: ->(_row, _context) { "Named API this app uses. A label, not a secret." }
        column :confidential,
               title: "Secret",
               display: :badge,
               value: ->(row, _context) { RecordingStudioOauth::Admin.secret_cell(row)[:label] },
               display_options: lambda { |row, _context, _value|
                 cell = RecordingStudioOauth::Admin.secret_cell(row)
                 { text: cell[:label], style: cell[:style], size: :sm }
               },
               tooltip: ->(row, _context) { RecordingStudioOauth::Admin.secret_cell(row)[:tooltip] }
        column :revoked_at,
               title: "Status",
               display: :badge,
               value: ->(row, _context) { RecordingStudioOauth::Admin.status_cell(row)[:label] },
               display_options: lambda { |row, _context, _value|
                 cell = RecordingStudioOauth::Admin.status_cell(row)
                 { text: cell[:label], style: cell[:style], size: :sm }
               }
        action :edit,
               text: "Edit",
               url: ->(row, _context) { RecordingStudioOauth::Admin.edit_oauth_client_path(row) }
        action :revoke,
               text: "Revoke",
               url: ->(row, _context) { RecordingStudioOauth::Admin.revoke_oauth_client_path(row) },
               method: :post,
               confirm: ->(row, _context) { "Revoke #{row.name}?" },
               destructive: true,
               visible_if: ->(row, _context) { row.revoked_at.nil? }
      end
    end

    class OauthConnectionsScreen < RecordingStudioAdmin::Screen
      key "oauth_connections"
      title "Connections"
      subtitle "See who still has an app connected."
      blast_radius :site
      query { |context| OauthClientsFilters.filtered_connections(context) }
      filter_presentation :inline

      filter :status,
             options: OauthClientsFilters::STATUS_FILTERS,
             default: :active,
             apply: ->(relation, value, _context) { OauthClientsFilters.apply_status(relation, value) }

      table do
        default_sort :created_at, direction: :desc
        column :app,
               title: "App",
               sortable: false,
               value: ->(row, _context) { row.oauth_client&.name }
        column :role
        column :revoked_at,
               title: "Status",
               display: :badge,
               value: ->(row, _context) { RecordingStudioOauth::Admin.status_cell(row)[:label] },
               display_options: lambda { |row, _context, _value|
                 cell = RecordingStudioOauth::Admin.status_cell(row)
                 { text: cell[:label], style: cell[:style], size: :sm }
               }
      end
    end

    def register!
      return unless defined?(RecordingStudioAdmin)
      return if @registered

      RecordingStudioAdmin.register_widget(ActiveAppsWidget)
      RecordingStudioAdmin.register_widget(ActiveConnectionsWidget)
      MetricChartWidgets.register!
      RecordingStudioAdmin.register_section(OauthAppsSection)
      RecordingStudioAdmin.register_resource(OauthClientsResource)
      RecordingStudioAdmin.register_screen(OauthClientsScreen)
      RecordingStudioAdmin.register_screen(OauthConnectionsScreen)
      @registered = true
    end
  end
end
