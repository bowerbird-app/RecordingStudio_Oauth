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

  config.api :operations do |api|
    api.openapi_title = "Operations API"
    api.openapi_description = "Staff Admin API. operations is a named API label, not a secret."
  end
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

RecordingStudioApi.register_recordable_type_api(
  "AdminRoot",
  api: :operations,
  operations: %i[index show],
  serializer: ->(recordable, **) { { name: recordable.name } },
  output_keys: %i[name]
)
RecordingStudioApi.register_recordable_type_api(
  "Workspace",
  api: :operations,
  operations: %i[index show],
  serializer: ->(recordable, **) { { name: recordable.name } },
  output_keys: %i[name]
)

# API 0.5.2 still reads the old Access integer-enum map. Accessible 0.11 stores
# role names as strings and no longer defines Access.roles.
Rails.application.config.to_prepare do
  next unless defined?(RecordingStudio::Access)
  next if RecordingStudio::Access.respond_to?(:roles)
  next unless defined?(RecordingStudio::AccessRoles::ORDER)

  RecordingStudio::Access.define_singleton_method(:roles) do
    RecordingStudio::AccessRoles::ORDER
  end
end

