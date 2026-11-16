# frozen_string_literal: true

module RecordingStudioOauth
  module Services
    module RedactsHookSecrets
      FILTERED = "[FILTERED]"
      SECRET_KEYS = %w[
        token
        access_token
        refresh_token
        client_secret
        code
        code_verifier
        id_token
        password
        assertion
        client_assertion
        device_code
        user_code
        authorization_code
        session_token_secret
        state_secret
        secret
        nonce
        state
      ].freeze
      PARAM_KEYS = %w[
        grant_type
        client_id
        redirect_uri
        scope
        resource
        token_type_hint
        response_type
        code_challenge
        code_challenge_method
      ].freeze
      SECRET_IVARS = %i[
        @client_secret
        @session_token_secret
        @state_secret
        @code
        @code_verifier
        @refresh_token
        @token
        @secret
        @attempt_refresh_token
        @authorization_header
        @state
        @site_state
      ].freeze
      SECRET_COLUMNS = %w[
        access_token
        refresh_token
        code_verifier
        session_token_secret_ciphertext
      ].freeze
      SECRET_RECORD_READERS = {
        "RecordingStudioOauth::OutboundConnection" => %i[access_token refresh_token],
        "RecordingStudioOauth::OutboundHandshake" => %i[code_verifier nonce],
        "RecordingStudioOauth::OauthClient" => %i[session_token_secret]
      }.freeze
      TOKEN_RECORD_NAMES = %w[
        RecordingStudioOauth::OauthAccessToken
        RecordingStudioOauth::OauthRefreshToken
        RecordingStudioOauth::OauthAuthorizationCode
      ].freeze

      private

      def hook_result(result)
        redact_value(result, redaction_context(result))
      end

      def hook_subject
        context = redaction_context(nil)
        copy = dup
        SECRET_IVARS.each do |name|
          copy.remove_instance_variable(name) if copy.instance_variable_defined?(name)
        end
        allowlist_subject_params(copy)
        copy.instance_variables.each do |name|
          copy.instance_variable_set(name, redact_value(copy.instance_variable_get(name), context))
        end
        copy
      end

      def redaction_context(result)
        texts = []
        seen = {}.compare_by_identity
        collect_secrets(self, texts, seen)
        collect_secrets(result, texts, seen) unless result.nil?
        Redaction.new(texts.grep(String).reject(&:empty?).uniq.sort_by { |item| -item.length })
      end

      def allowlist_subject_params(copy)
        return unless copy.instance_variable_defined?(:@params)

        copy.instance_variable_set(:@params, allowlisted_params(copy.instance_variable_get(:@params)))
      end

      def allowlisted_params(params)
        params_hash(params).each_with_object({}) do |(key, value), kept|
          next unless PARAM_KEYS.include?(key.to_s)

          kept[key] = value
        end
      end

      def redact_value(object, context)
        return nil if object.nil?
        return context.copies[object] if context.copies.key?(object)

        case object
        when RecordingStudio::Services::BaseService::Result
          redacted = RecordingStudio::Services::BaseService::Result.new(
            success: object.success?,
            value: redact_value(object.value, context),
            error: redact_value(object.error, context),
            errors: redact_value(object.errors, context)
          )
          context.copies[object] = redacted
        when Hash
          context.copies[object] = redact_hash(object, context)
        when Array
          context.copies[object] = object.map { |item| redact_value(item, context) }
        when String
          scrub_secret(object, context.texts)
        else
          return redact_parameters(object, context) if parameters?(object)
          return redact_shaped(object, context) if shaped?(object)
          return redact_record(object, context) if object.is_a?(ActiveRecord::Base)

          object
        end
      end

      def redact_hash(object, context)
        object.each_with_object({}) do |(key, value), redacted|
          redacted[key] = SECRET_KEYS.include?(key.to_s) ? nil : redact_value(value, context)
        end
      end

      def redact_parameters(object, context)
        context.copies[object] = redact_hash(parameters_hash(object), context)
      end

      def redact_shaped(object, context)
        context.copies[object] = redact_hash(object.to_h, context)
      end

      def redact_record(record, context)
        if token_record?(record)
          context.copies[record] = nil
          return nil
        end
        return record unless secret_record?(record) || loaded_secret?(record)

        copy = materialize_record(record, clear_secrets: secret_record?(record))
        context.copies[record] = copy
        retarget_loaded_associations(record, copy, context)
        copy.readonly!
        copy
      end

      def materialize_record(record, clear_secrets:)
        raw = record.attributes_before_type_cast.dup
        clear_secret_columns(raw) if clear_secrets
        copy = record.class.instantiate(raw.to_h)
        copy.nonce = nil if handshake?(copy)
        copy
      end

      def retarget_loaded_associations(record, copy, context)
        loaded_associations(record).each_key do |name|
          association = record.association(name)
          next unless association.loaded?

          copy.association(name).target = redact_value(association.target, context)
        end
      end

      def collect_secrets(object, texts, seen)
        return if object.nil? || seen[object]

        seen[object] = true
        case object
        when Hash
          object.each { |key, value| collect_pair(key, value, texts, seen) }
        when Array
          object.each { |item| collect_secrets(item, texts, seen) }
        when RecordingStudio::Services::BaseService::Result
          collect_secrets(object.value, texts, seen)
          collect_secrets(object.error, texts, seen)
          collect_secrets(object.errors, texts, seen)
        else
          collect_parameters(object, texts, seen) if parameters?(object)
          collect_shaped(object, texts, seen) if shaped?(object)
          collect_service_ivars(object, texts, seen) if service?(object)
          collect_record_secrets(object, texts, seen) if object.is_a?(ActiveRecord::Base)
        end
      end

      def collect_pair(key, value, texts, seen)
        if SECRET_KEYS.include?(key.to_s) && value.is_a?(String)
          texts << value
        else
          collect_secrets(value, texts, seen)
        end
      end

      def collect_parameters(object, texts, seen)
        collect_secrets(parameters_hash(object), texts, seen)
      end

      def collect_shaped(object, texts, seen)
        collect_secrets(object.to_h, texts, seen)
      end

      def collect_service_ivars(object, texts, seen)
        object.instance_variables.each do |name|
          value = object.instance_variable_get(name)
          texts << value if SECRET_IVARS.include?(name) && value.is_a?(String)
          collect_secrets(value, texts, seen)
        end
      end

      def collect_record_secrets(record, texts, seen)
        Array(SECRET_RECORD_READERS[record.class.name]).each do |name|
          value = record.public_send(name)
          texts << value if value.is_a?(String)
        end
        loaded_associations(record).each_value do |association|
          next unless association.loaded?

          collect_secrets(association.target, texts, seen)
        end
      end

      def scrub_secret(text, texts)
        return nil if texts.any? { |secret| long_secret?(secret) && text == secret }

        scrubbed = texts.reduce(text) do |current, secret|
          next current unless long_secret?(secret) && current.include?(secret)

          current.gsub(secret, FILTERED)
        end
        scrubbed == text ? text : scrubbed
      end

      def long_secret?(secret)
        secret.length >= 8
      end

      def params_hash(params)
        return parameters_hash(params) if parameters?(params)
        return params if params.is_a?(Hash)

        {}
      end

      def parameters_hash(params)
        params.to_unsafe_h
      end

      def parameters?(object)
        defined?(ActionController::Parameters) && object.is_a?(ActionController::Parameters)
      end

      def shaped?(object)
        object.is_a?(Struct) || (defined?(Data) && object.is_a?(Data))
      end

      def service?(object)
        object.class < RecordingStudio::Services::BaseService
      end

      def secret_record?(record)
        SECRET_RECORD_READERS.key?(record.class.name)
      end

      def token_record?(record)
        TOKEN_RECORD_NAMES.include?(record.class.name)
      end

      def clear_secret_columns(raw)
        return unless raw.respond_to?(:[]=)

        SECRET_COLUMNS.each do |name|
          if raw.key?(name)
            raw[name] = nil
          elsif raw.key?(name.to_sym)
            raw[name.to_sym] = nil
          end
        end
      end

      def handshake?(record)
        record.instance_of?(RecordingStudioOauth::OutboundHandshake)
      end

      def loaded_associations(record)
        return {} unless record.instance_variable_defined?(:@association_cache)

        record.instance_variable_get(:@association_cache) || {}
      end

      def loaded_secret?(record)
        loaded_associations(record).each_value.any? do |association|
          association.loaded? && secretish?(association.target)
        end
      end

      def secretish?(object)
        case object
        when nil then false
        when Array then object.any? { |item| secretish?(item) }
        else token_record?(object) || secret_record?(object)
        end
      end

      Redaction = Struct.new(:texts, :copies) do
        def initialize(texts)
          super(texts, {}.compare_by_identity)
        end
      end
      private_constant :Redaction
    end
  end
end
