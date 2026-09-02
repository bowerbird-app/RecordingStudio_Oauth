# frozen_string_literal: true

module RecordingStudioOauth
  module ConnectHandshake
    module_function

    def title(plugin_name:, site_names:)
      plugin = plugin_name.to_s
      names = Array(site_names).map { |name| present_name(name) }
      if names.uniq.one? && names.first.present?
        "#{plugin} wants to connect to #{names.first}"
      else
        "#{plugin} wants to connect"
      end
    end

    def row_label(parent_name:, site_name:, shared_site_name:)
      if shared_site_name
        parent_name.to_s
      else
        present_name(site_name) || parent_name.to_s
      end
    end

    def shared_site_name?(site_names)
      names = Array(site_names).map { |name| present_name(name) }
      names.uniq.one? && names.first.present?
    end

    def present_name(name)
      name.to_s.strip.presence
    end
  end
end
