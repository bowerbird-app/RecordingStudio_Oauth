# frozen_string_literal: true

require_relative "hook_secret_catalog"
require_relative "hook_secret_values"
require_relative "hook_secret_records"
require_relative "hook_secret_collection"

module RecordingStudioOauth
  module Services
    module RedactsHookSecrets
      include HookSecretValues
      include HookSecretRecords
      include HookSecretCollection

      private

      def hook_result(result)
        redact_value(result, redaction_context(result))
      end

      def hook_subject
        context = redaction_context(nil)
        copy = dup
        HookSecretCatalog::SECRET_IVARS.each do |name|
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
          next unless HookSecretCatalog::PARAM_KEYS.include?(key.to_s)

          kept[key] = value
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
