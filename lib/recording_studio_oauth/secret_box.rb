# frozen_string_literal: true

require "active_support/key_generator"
require "active_support/message_encryptor"

module RecordingStudioOauth
  module SecretBox
    PURPOSE = "recording-studio-oauth-session-token-secret"

    module_function

    def encrypt(plain)
      return if plain.blank?

      encryptor.encrypt_and_sign(plain.to_s)
    end

    def decrypt(cipher)
      return if cipher.blank?

      encryptor.decrypt_and_verify(cipher)
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      nil
    end

    def encryptor
      key = ActiveSupport::KeyGenerator.new(TokenDigest.pepper).generate_key(PURPOSE, 32)
      ActiveSupport::MessageEncryptor.new(key, serializer: JSON)
    end
  end
end
