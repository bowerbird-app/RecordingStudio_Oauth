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
                  :layout_name
    attr_reader :hooks

    def initialize
      @authentication_method = :authenticate_user!
      @current_actor_method = :current_user
      @admin_root_recordable_type_names = ["AdminRoot"]
      @authorization_code_ttl = 10.minutes
      @access_token_ttl = 1.hour
      @refresh_token_ttl = 30.days
      @api_mount_path = "/recording_studio_api"
      @layout_name = "recording_studio/default_layout"
      @hooks = RecordingStudio::Hooks.new
    end

    def to_h
      {
        authentication_method: authentication_method,
        current_actor_method: current_actor_method,
        admin_root_recordable_type_names: admin_root_recordable_type_names,
        authorization_code_ttl: authorization_code_ttl,
        access_token_ttl: access_token_ttl,
        refresh_token_ttl: refresh_token_ttl,
        api_mount_path: api_mount_path,
        layout_name: layout_name,
        hooks_registered: hooks.instance_variable_get(:@registry).transform_values(&:size)
      }
    end

    def merge!(hash)
      return unless hash.respond_to?(:each)

      hash.each do |k, v|
        key = k.to_s
        setter = "#{key}="
        public_send(setter, v) if respond_to?(setter)
      end
    end
  end
end
