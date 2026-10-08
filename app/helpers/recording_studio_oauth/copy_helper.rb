# frozen_string_literal: true

module RecordingStudioOauth
  module CopyHelper
    def oauth_t(...)
      Copy.t(...)
    end

    def oauth_copy(override, key, **)
      Copy.value(override, key, **)
    end

    def oauth_role_name(role)
      Copy.role_name(role)
    end

    def oauth_scope_description(name, fallback)
      Copy.scope_description(name, fallback)
    end

    def oauth_error_page_description(error)
      Copy.error_page_description(error)
    end

    def oauth_document_attributes(extra = {})
      attributes = { lang: I18n.locale.to_s }.merge(extra)
      attributes.merge!(recording_studio_locale_attributes) if respond_to?(:recording_studio_locale_attributes)
      return attributes unless respond_to?(:flat_pack_copy_data)

      attributes[:data] = (attributes[:data] || {}).merge(flat_pack_copy_data)
      attributes
    end
  end
end
