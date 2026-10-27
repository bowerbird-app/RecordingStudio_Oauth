# frozen_string_literal: true

module RecordingStudioOauth
  class ApplicationController < ActionController::Base
    include Devise::Controllers::Helpers if defined?(Devise)

    protect_from_forgery with: :exception

    recording_studio_layout { RecordingStudioOauth.configuration.layout }
  end
end
