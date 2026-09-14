# frozen_string_literal: true

module RecordingStudioOauth
  module ProtectedResources
    module_function

    def register(identifier)
      raise ArgumentError, "protected resource identifier is required" if identifier.nil?

      mutex.synchronize do
        identifiers << identifier unless identifiers.include?(identifier)
      end
      identifier
    end

    def clear!
      mutex.synchronize { identifiers.clear }
    end

    def registered_identifiers
      mutex.synchronize { identifiers.dup }
    end

    def api_resource_identifier(request, api_key: "public")
      api_mount = RecordingStudioOauth.configuration.api_mount_path.presence || "/recording_studio_api"
      key = api_key.to_s.presence || "public"
      if key == "public"
        "#{request.base_url}#{api_mount}/api"
      else
        "#{request.base_url}#{api_mount}/apis/#{key}"
      end
    end

    def allowed_identifiers(request, api_key: "public")
      values = [api_resource_identifier(request, api_key: api_key), request.base_url]
      registered_identifiers.each do |entry|
        resolved = resolve(entry, request)
        values << resolved if resolved.present?
      end
      values.uniq
    end

    def allowed?(resource, request:, api_key: "public")
      return true if resource.blank?

      allowed_identifiers(request, api_key: api_key).include?(resource.to_s)
    end

    def resolve(entry, request)
      case entry
      when Proc
        entry.call(request)
      else
        entry.to_s.presence
      end
    end
    private_class_method :resolve

    def identifiers
      @identifiers ||= []
    end
    private_class_method :identifiers

    def mutex
      @mutex ||= Mutex.new
    end
    private_class_method :mutex
  end
end
