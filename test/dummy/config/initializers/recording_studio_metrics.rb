# frozen_string_literal: true

# Host-owned. Oauth registers metric definitions; it does not expose endpoints.
RecordingStudioMetrics::Api.register!(api: :operations)
