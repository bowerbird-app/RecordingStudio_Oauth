# frozen_string_literal: true

module RecordingStudioOauth
  class RegistrationSetting < ApplicationRecord
    self.table_name = "recording_studio_oauth_registration_settings"

    SINGLETON_KEY = 1

    validates :singleton_key, presence: true, uniqueness: true

    def self.allow_registration?
      find_by(singleton_key: SINGLETON_KEY)&.allow_registration? || false
    end

    def self.current
      find_or_create_by!(singleton_key: SINGLETON_KEY)
    rescue ActiveRecord::RecordNotUnique
      find_by!(singleton_key: SINGLETON_KEY)
    end
  end
end
