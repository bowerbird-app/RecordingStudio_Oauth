# frozen_string_literal: true

class AddRegistrationPolicyToRecordingStudioOauth < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_studio_oauth_clients, :allow_registration, :boolean, null: false, default: false

    create_table :recording_studio_oauth_registration_settings, id: :uuid do |t|
      t.boolean :allow_registration, null: false, default: false
      t.integer :singleton_key, null: false, default: 1

      t.timestamps
    end

    add_index :recording_studio_oauth_registration_settings,
              :singleton_key,
              unique: true,
              name: "index_rs_oauth_registration_settings_on_singleton_key"
  end
end
