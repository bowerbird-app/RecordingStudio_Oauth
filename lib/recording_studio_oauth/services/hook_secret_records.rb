# frozen_string_literal: true

module RecordingStudioOauth
  module Services
    module HookSecretRecords
      private

      def redact_record(record, context)
        if token_record?(record)
          context.copies[record] = nil
          return nil
        end
        return record unless copy_record?(record)

        copy = materialize_record(record, clear_secrets: secret_record?(record))
        context.copies[record] = copy
        retarget_loaded_associations(record, copy, context)
        seal_secret_associations(copy, context)
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

          target = redact_value(association.target, context)
          target = target.compact if target.is_a?(Array)
          copy.association(name).target = target
        end
      end

      def seal_secret_associations(copy, context)
        spec = HookSecretCatalog::SECRET_ASSOCIATIONS[copy.class.name]
        return if spec.nil?

        spec.fetch(:belongs).each do |name|
          association = copy.association(name)
          next if association.loaded?

          association.load_target
          association.target = redact_value(association.target, context)
        end

        spec.fetch(:collections).each do |name|
          association = copy.association(name)
          next if association.loaded?

          association.target = []
        end
      end

      def copy_record?(record)
        secret_record?(record) || loaded_secret?(record) || HookSecretCatalog::SECRET_ASSOCIATIONS.key?(record.class.name)
      end

      def secret_record?(record)
        HookSecretCatalog::SECRET_RECORD_READERS.key?(record.class.name)
      end

      def token_record?(record)
        HookSecretCatalog::TOKEN_RECORD_NAMES.include?(record.class.name)
      end

      def clear_secret_columns(raw)
        return unless raw.respond_to?(:[]=)

        HookSecretCatalog::SECRET_COLUMNS.each do |name|
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
        else token_record?(object) || secret_record?(object) || HookSecretCatalog::SECRET_ASSOCIATIONS.key?(object.class.name)
        end
      end
    end
  end
end
