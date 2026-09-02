# frozen_string_literal: true

require "recording_studio"
require "recording_studio_accessible"
require "recording_studio_admin"
require "recording_studio_api"
require "active_record"
require "recording_studio_site_settings"
require "flat_pack"
require "recording_studio_oauth/connect_handshake"
require "recording_studio_oauth/token_digest"
require "recording_studio_oauth/pkce"
require "recording_studio_oauth/authorization_code"
require "recording_studio_oauth/refresh_token"
require "recording_studio_oauth/access_token"
require "recording_studio_oauth/oauth_client_secret"
require "recording_studio_oauth/oauth_error_mapper"
require "recording_studio_oauth/integration"
require "recording_studio_oauth/grant_registration"
require "recording_studio_oauth/services/authenticate_oauth_client"
require "recording_studio_oauth/services/resolve_oauth_client"
require "recording_studio_oauth/services/create_oauth_authorization"
require "recording_studio_oauth/services/void_oauth_authorization"
require "recording_studio_oauth/services/issue_delegated_access_token"
require "recording_studio_oauth/admin"

module RecordingStudioOauth
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioOauth

    class << self
      def apply_model_extensions(target)
        apply_extensions(target, extensions_for(:model, extension_keys_for(target)))
      end

      def apply_controller_extensions(target)
        apply_extensions(target, extensions_for(:controller, extension_keys_for(target)))
      end

      private

      def extensions_for(kind, names)
        hooks = RecordingStudioOauth.configuration.hooks
        Array(names).flat_map do |name|
          if kind == :model
            hooks.model_extensions_for(name)
          else
            hooks.controller_extensions_for(name)
          end
        end
      end

      def apply_extensions(target, extensions)
        return unless target

        applied = target.instance_variable_get(:@recording_studio_oauth_applied_extensions) || identity_hash

        extensions.flatten.compact.each do |extension|
          next if applied[extension]

          target.class_eval(&extension)
          applied[extension] = true
        end

        target.instance_variable_set(:@recording_studio_oauth_applied_extensions, applied)
      end

      def extension_keys_for(target)
        names = [target.name, target.name&.demodulize].compact.uniq
        names.map(&:to_sym)
      end

      def identity_hash
        {}.compare_by_identity
      end
    end

    initializer "recording_studio_oauth.append_migrations" do |app|
      unless app.root.to_s.match root.to_s
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end

    initializer "recording_studio_oauth.assets" do |app|
      app.config.assets.precompile += %w[recording_studio_oauth_manifest.js] if app.config.respond_to?(:assets)
    end

    initializer "recording_studio_oauth.recording_studio_capabilities" do
      next unless RecordingStudio.respond_to?(:capabilities)

      capabilities = RecordingStudio.capabilities
      next unless capabilities.respond_to?(:declare_from_engine)

      capabilities.declare_from_engine(self)
    end

    initializer "recording_studio_oauth.before_initialize", before: "recording_studio_oauth.load_config" do |_app|
      RecordingStudioOauth.configuration.hooks.run(:before_initialize, self)
    end

    initializer "recording_studio_oauth.load_config" do |app|
      if app.respond_to?(:config_for)
        begin
          yaml = begin
            app.config_for(:recording_studio_oauth)
          rescue StandardError
            nil
          end
          RecordingStudioOauth.configuration.merge!(yaml) if yaml.respond_to?(:each)
        rescue StandardError
          nil
        end
      end

      if app.config.respond_to?(:x) && app.config.x.respond_to?(:recording_studio_oauth)
        xcfg = app.config.x.recording_studio_oauth
        if xcfg.respond_to?(:to_h)
          RecordingStudioOauth.configuration.merge!(xcfg.to_h)
        else
          begin
            hash = {}
            xcfg.each_pair { |k, v| hash[k] = v } if xcfg.respond_to?(:each_pair)
            RecordingStudioOauth.configuration.merge!(hash) if hash&.any?
          rescue StandardError
            nil
          end
        end
      end

      RecordingStudioOauth.configuration.hooks.run(:on_configuration, RecordingStudioOauth.configuration)
    end

    initializer "recording_studio_oauth.after_initialize", after: "recording_studio_oauth.load_config" do |_app|
      RecordingStudioOauth.configuration.hooks.run(:after_initialize, self)
    end

    initializer "recording_studio_oauth.apply_model_extensions" do
      config.to_prepare do
        next unless defined?(ActiveRecord::Base)

        ActiveRecord::Base.descendants.each do |model|
          next if model.abstract_class?

          RecordingStudioOauth::Engine.apply_model_extensions(model)
        end
      end
    end

    initializer "recording_studio_oauth.apply_controller_extensions" do
      config.to_prepare do
        next unless defined?(ActionController::Base)

        ActionController::Base.descendants.each do |controller|
          RecordingStudioOauth::Engine.apply_controller_extensions(controller)
        end
      end
    end

    config.to_prepare do
      RecordingStudioOauth::GrantRegistration.register!
      RecordingStudioOauth::Admin.register! if defined?(RecordingStudioAdmin)
    end
  end
end
