# frozen_string_literal: true

# Sibling engines in the dummy (such as Site Settings v0.2.0) still include
# RecordingStudio::UsesDefaultLayout until they upgrade to Recording Studio 6.1.
unless defined?(RecordingStudio::UsesDefaultLayout)
  module RecordingStudio
    module UsesDefaultLayout
      extend ActiveSupport::Concern

      included do
        layout(RecordingStudio::DEFAULT_LAYOUT)
        helper RecordingStudio::LayoutHelper
      end
    end
  end
end

RecordingStudio.configure do |config|
  config.recordable_types = [
    "Workspace",
    "Folder",
    "Page",
    "AdminRoot",
    "SharedRoot",
    "RecordingStudioSiteSettings::SiteSetting",
    "RecordingStudioAttachable::Attachment",
    "RecordingStudioAttachable::Library",
    "RecordingStudioAttachable::Placement"
  ]
  config.require_recordable_declarations = true
  config.app_name = "Recording Studio OAuth" if config.respond_to?(:app_name=)
  config.actor = -> { Current.actor }
  config.event_notifications_enabled = true
  config.idempotency_mode = :return_existing
  config.recordable_dup_strategy = :dup
end
