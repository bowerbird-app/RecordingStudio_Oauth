# frozen_string_literal: true

module RecordingStudioOauth
  class Configuration
    ACCESS_ROLE_RANKS = { view: 0, edit: 1, admin: 2 }.freeze

    attr_accessor :authentication_method,
                  :current_actor_method,
                  :admin_root_recordable_type_names,
                  :authorization_code_ttl,
                  :access_token_ttl,
                  :refresh_token_ttl,
                  :api_mount_path,
                  :engine_mount_path,
                  :mcp_mount_path,
                  :register_origin_as_protected_resource,
                  :extra_protected_resource_paths,
                  :public_origin,
                  :registration_path,
                  :layout_name
    attr_reader :allow_registration, :hooks

    def initialize
      @authentication_method = :authenticate_user!
      @current_actor_method = :current_user
      @admin_root_recordable_type_names = ["AdminRoot"]
      @authorization_code_ttl = 10.minutes
      @access_token_ttl = 1.hour
      @refresh_token_ttl = 30.days
      @api_mount_path = "/recording_studio_api"
      @engine_mount_path = "/recording_studio_oauth"
      @mcp_mount_path = "/recording_studio_mcp"
      @register_origin_as_protected_resource = false
      @extra_protected_resource_paths = []
      @public_origin = nil
      @registration_path = "/users/sign_up"
      @layout_name = "recording_studio/default_layout"
      @allow_registration = false
      @hooks = RecordingStudio::Hooks.new
    end

    def allow_registration=(value)
      @allow_registration = ActiveModel::Type::Boolean.new.cast(value) == true
    end

    def allow_registration?
      allow_registration == true
    end

    def to_h
      connection_settings.merge(mount_settings, registration_settings, hooks_registered: registered_hook_counts)
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |k, v|
        key = k.to_s
        setter = "#{key}="
        public_send(setter, v) if respond_to?(setter)
      end
    end

    private

    def connection_settings
      {
        authentication_method: authentication_method,
        current_actor_method: current_actor_method,
        admin_root_recordable_type_names: admin_root_recordable_type_names,
        authorization_code_ttl: authorization_code_ttl,
        access_token_ttl: access_token_ttl,
        refresh_token_ttl: refresh_token_ttl,
        layout_name: layout_name
      }
    end

    def mount_settings
      {
        api_mount_path: api_mount_path,
        engine_mount_path: engine_mount_path,
        mcp_mount_path: mcp_mount_path,
        register_origin_as_protected_resource: register_origin_as_protected_resource,
        extra_protected_resource_paths: extra_protected_resource_paths
      }
    end

    def registration_settings
      {
        public_origin: public_origin,
        registration_path: registration_path,
        allow_registration: allow_registration?
      }
    end

    def registered_hook_counts
      hooks.instance_variable_get(:@registry).transform_values(&:size)
    end
  end
end
