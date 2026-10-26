# frozen_string_literal: true

require "recording_studio_oauth/outbound/provider"
require "recording_studio_oauth/outbound/https_url"
require "recording_studio_oauth/outbound/registry"
require "recording_studio_oauth/outbound/access"
require "recording_studio_oauth/outbound/live_connection"
require "recording_studio_oauth/outbound/token_client"

module RecordingStudioOauth
  module Outbound
    module_function

    def registry
      @registry ||= Registry.new
    end

    def register_provider(**)
      registry.register(**)
    end

    def provider(key)
      registry.fetch(key)
    end

    def providers
      registry.all.values.map(&:public_attributes).freeze
    end

    def reset_providers!
      registry.reset!
    end

    def connection_for(provider:, root:, actor:)
      Services::LookupOutboundConnection.call(provider: provider, root: root, actor: actor).value
    end

    def connection_status(provider:, root:, actor:)
      status_for(LiveConnection.find(provider: provider, root: root, actor: actor))
    end

    # Workspace slot and personal slot for one provider, without merging them.
    # Both are :missing when the actor may not view the root.
    def combined_connection_status(provider:, root:, actor:)
      provider_key = provider.to_s
      {
        workspace: status_for(
          LiveConnection.root_owned(provider_key: provider_key, root: root, actor: actor)
        ),
        personal: status_for(
          LiveConnection.user_owned(provider_key: provider_key, actor: actor, root: root)
        )
      }.freeze
    end

    def connection_id_for(provider:, root:, actor:)
      LiveConnection.find(provider: provider, root: root, actor: actor)&.id
    end

    # Counts working personal connections (`active`) for that provider on that
    # workspace. Does not count `needs_reconnect` (including leftover null-root
    # rows), revoked rows, workspace-owned rows, or other workspaces.
    def connected_user_count(provider:, root:)
      provider_key = provider.to_s
      return 0 if root.nil? || provider_key.blank?
      return 0 unless root.respond_to?(:id)

      OutboundConnection.usable.for_provider(provider_key).where(
        root_recording_id: root.id
      ).where.not(owner_actor_id: nil).count
    end

    def status_for(row)
      return :missing if row.nil?
      return :needs_reconnect if row.needs_reconnect?

      :active
    end
    private_class_method :status_for
  end
end
