# frozen_string_literal: true

require "i18n"

module RecordingStudioOauth
  module Copy
    PREFIX = "recording_studio.oauth"
    UNSET = Object.new.freeze

    module_function

    def t(key, **)
      I18n.t("#{PREFIX}.#{key}", **)
    end

    def l(object, **)
      I18n.l(object, **)
    end

    def provided?(value)
      !value.equal?(UNSET)
    end

    def value(override, key, **)
      provided?(override) ? override : t(key, **)
    end

    # Host config that still matches the English default follows the locale.
    # A different string (including blank after presence) is host copy and wins.
    def defaulted(value, default, key, **)
      return t(key, **) if value.nil? || value == default

      value
    end

    def role_name(role)
      name = role.to_s
      t("roles.#{name}", default: name.humanize)
    end

    def scope_description(name, fallback)
      t("scopes.#{name}", default: fallback)
    end

    def error_page_description(error)
      description = error[:error_description].to_s.presence
      key = ERROR_DESCRIPTION_KEYS[description]
      key ? t(key) : (description || t("errors.invalid_request"))
    end

    ERROR_DESCRIPTION_KEYS = {
      "response_type must be code" => "errors.unsupported_response_type",
      "resource is not a registered protected resource" => "errors.invalid_target",
      "client is invalid" => "errors.invalid_client",
      "redirect_uri does not match" => "errors.invalid_request",
      "This app is not registered." => "errors.not_registered",
      "That return address is not allowed." => "errors.return_not_allowed",
      "This app is not set up for the central relay." => "errors.relay_not_set_up",
      "Connect needs a proof key." => "errors.proof_key_required"
    }.freeze
  end
end
