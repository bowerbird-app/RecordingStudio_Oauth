# frozen_string_literal: true

module RecordingStudioOauth
  module Services
    class CreateOauthClient < RecordingStudio::Services::BaseService
      DEFAULT_API_KEY = "public"
      PUBLIC_SECRET_CHOICE = "public"
      HAS_SECRET_CHOICE = "has_secret"
      SECRET_CHOICES = [
        ["Public", PUBLIC_SECRET_CHOICE],
        ["Has a secret", HAS_SECRET_CHOICE]
      ].freeze

      def self.redirect_uris_from_lines(text)
        text.to_s.split(/\r?\n/).map(&:strip).compact_blank
      end

      def self.confidential?(secret_choice)
        secret_choice.to_s == HAS_SECRET_CHOICE
      end

      def initialize(name:, redirect_uris:, confidential:, use_central_relay: false, allowed_return_patterns: [], exact_return_urls: [], allow_registration: nil)
        @name = name.to_s
        @redirect_uris = Array(redirect_uris)
        @confidential = ActiveModel::Type::Boolean.new.cast(confidential)
        @use_central_relay = ActiveModel::Type::Boolean.new.cast(use_central_relay) == true
        @allowed_return_patterns = Array(allowed_return_patterns)
        @exact_return_urls = Array(exact_return_urls)
        @allow_registration = if allow_registration.nil?
          RegistrationSetting.allow_registration?
        else
          ActiveModel::Type::Boolean.new.cast(allow_registration) == true
        end
      end

      private

      attr_reader :name, :redirect_uris, :confidential, :use_central_relay, :allowed_return_patterns, :exact_return_urls, :allow_registration

      def perform
        secret_token = nil
        client = OauthClient.new(
          name: name,
          redirect_uris: redirect_uris,
          confidential: confidential,
          api_key: DEFAULT_API_KEY,
          use_central_relay: use_central_relay,
          allowed_return_patterns: allowed_return_patterns,
          exact_return_urls: exact_return_urls,
          allow_registration: allow_registration
        )

        if confidential
          generated = OauthClientSecret.generate
          client.client_secret_digest = generated.fetch(:digest)
          secret_token = generated.fetch(:token)
        end

        if client.save
          success({ client: client, client_secret: secret_token })
        else
          failure(client.errors.full_messages.to_sentence, errors: [client])
        end
      end

      def service_args
        { name: name, confidential: confidential }
      end
    end
  end
end
