# frozen_string_literal: true

RecordingStudioApi.configure do |config|
  config.openapi_title = "Recording Studio API"
  config.openapi_description = "Resource server for Recording Studio. Connect lives on recording_studio_oauth."
  config.documentation_enabled = true
  config.documentation_access = :public
  config.layout_name = "recording_studio/default_layout"
  config.admin_layout_name = "recording_studio/default_layout"
  config.rate_limit_oauth_enabled = false if config.respond_to?(:rate_limit_oauth_enabled=)
  config.rate_limit_api_pre_auth_enabled = false if config.respond_to?(:rate_limit_api_pre_auth_enabled=)
  config.rate_limit_api_enabled = false if config.respond_to?(:rate_limit_api_enabled=)
  config.api_request_logging_enabled = false if config.respond_to?(:api_request_logging_enabled=)
  config.api_management_authorization_required = false if config.respond_to?(:api_management_authorization_required=)
end

RecordingStudioApi.register_recordable_type_api(
  "Workspace",
  serializer: ->(recordable, **) { { name: recordable.name } },
  output_keys: %i[name],
  writable_attributes: %i[name],
  operations: %i[index show]
)

RecordingStudioApi.register_recordable_type_api(
  "Folder",
  serializer: ->(recordable, **) { { name: recordable.name } },
  output_keys: %i[name],
  writable_attributes: %i[name],
  operations: %i[index show]
)
