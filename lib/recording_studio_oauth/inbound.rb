# frozen_string_literal: true

module RecordingStudioOauth
  module Inbound
    module_function

    # Connected means an OauthAuthorization that is still active (not revoked,
    # granted access recording kept, Accessible still authorizes that grant on
    # the workspace from workspace_recording), on a non-revoked OauthClient with
    # this plugin_key, in this workspace, with a usable token: an OauthAccessToken
    # that is unexpired and not revoked, or an OauthRefreshToken that is unexpired
    # and not revoked (the models' `active` scopes).
    def connection_status(plugin_key:, root:, actor:)
      payload = lookup(plugin_key: plugin_key, root: root, actor: actor)
      { connected: payload.fetch(:connected), connected_count: payload.fetch(:connected_count) }.freeze
    end

    def connections(plugin_key:, root:, actor:)
      lookup(plugin_key: plugin_key, root: root, actor: actor).fetch(:people)
    end

    def lookup(plugin_key:, root:, actor:)
      Services::LookupInboundConnection.call(plugin_key: plugin_key, root: root, actor: actor).value
    end
    private_class_method :lookup
  end
end
