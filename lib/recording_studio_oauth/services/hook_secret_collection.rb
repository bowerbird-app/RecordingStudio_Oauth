# frozen_string_literal: true

module RecordingStudioOauth
  module Services
    module HookSecretCollection
      private

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
        if HookSecretCatalog::SECRET_KEYS.include?(key.to_s) && value.is_a?(String)
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
          texts << value if HookSecretCatalog::SECRET_IVARS.include?(name) && value.is_a?(String)
          collect_secrets(value, texts, seen)
        end
      end

      def collect_record_secrets(record, texts, seen)
        Array(HookSecretCatalog::SECRET_RECORD_READERS[record.class.name]).each do |name|
          value = record.public_send(name)
          texts << value if value.is_a?(String)
        end
        loaded_associations(record).each_value do |association|
          next unless association.loaded?

          collect_secrets(association.target, texts, seen)
        end
      end

      def service?(object)
        object.class < RecordingStudio::Services::BaseService
      end
    end
  end
end
