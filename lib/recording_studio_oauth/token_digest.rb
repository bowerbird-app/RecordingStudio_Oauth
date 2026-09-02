# frozen_string_literal: true

require "digest"
require "openssl"

module RecordingStudioOauth
  module TokenDigest
    module_function

    def digest(token)
      OpenSSL::HMAC.hexdigest("SHA256", pepper, token.to_s)
    end

    def matches?(stored_digest, token)
      return false if stored_digest.blank? || token.blank?

      candidate = digest(token)
      return false unless stored_digest.bytesize == candidate.bytesize

      ActiveSupport::SecurityUtils.secure_compare(stored_digest, candidate)
    end

    def digest_candidates(token)
      [digest(token)]
    end

    def find_by_digest(scope, column, token)
      digest_candidates(token).each do |candidate|
        record = scope.find_by(column => candidate)
        return record if record
      end
      nil
    end

    def pepper
      return Rails.application.secret_key_base.to_s if defined?(Rails) && Rails.application&.secret_key_base.present?

      raise "secret_key_base is required to digest OAuth secrets"
    end
  end
end
