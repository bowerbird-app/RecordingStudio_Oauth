# frozen_string_literal: true

namespace :recording_studio_oauth do
  desc "Delete expired or consumed outbound OAuth handshake rows"
  task cleanup_outbound_handshakes: :environment do
    RecordingStudioOauth::OutboundHandshake.cleanup_stale
  end
end
