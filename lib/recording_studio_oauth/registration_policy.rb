# frozen_string_literal: true

module RecordingStudioOauth
  module RegistrationPolicy
    module_function

    def allowed?(client)
      return false if client.nil?

      client.allow_registration? == true
    end

    def flag?(value)
      value = value.last if value.is_a?(Array)
      ActiveModel::Type::Boolean.new.cast(value) == true
    end

    def registration_url(base_url:)
      "#{origin_for(base_url)}#{registration_path}"
    end

    def registration_path
      path = RecordingStudioOauth.configuration.registration_path.to_s.strip
      path = "/users/sign_up" if path.empty?
      path.start_with?("/") ? path : "/#{path}"
    end

    def origin_for(base_url)
      configured = RecordingStudioOauth.configuration.public_origin.to_s.strip.chomp("/")
      return configured if configured.present?

      base_url.to_s.chomp("/")
    end

    def payload(client, base_url:)
      allowed = allowed?(client)
      body = { registration: allowed }
      body[:registration_url] = registration_url(base_url: base_url) if allowed
      body
    end
  end
end
