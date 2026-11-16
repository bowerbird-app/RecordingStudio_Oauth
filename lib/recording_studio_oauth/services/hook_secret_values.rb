# frozen_string_literal: true

module RecordingStudioOauth
  module Services
    module HookSecretValues
      private

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
          redacted[key] = HookSecretCatalog::SECRET_KEYS.include?(key.to_s) ? nil : redact_value(value, context)
        end
      end

      def redact_parameters(object, context)
        context.copies[object] = redact_hash(parameters_hash(object), context)
      end

      def redact_shaped(object, context)
        context.copies[object] = redact_hash(object.to_h, context)
      end

      def scrub_secret(text, texts)
        return nil if texts.any? { |secret| long_secret?(secret) && text == secret }

        scrubbed = texts.reduce(text) do |current, secret|
          next current unless long_secret?(secret) && current.include?(secret)

          current.gsub(secret, HookSecretCatalog::FILTERED)
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
    end
  end
end
