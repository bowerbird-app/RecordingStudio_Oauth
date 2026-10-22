# frozen_string_literal: true

class AddOutboundHandshakeRootForeignKey < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :recording_studio_oauth_outbound_handshakes,
                    :recording_studio_recordings,
                    column: :root_recording_id,
                    on_delete: :cascade
  end
end
