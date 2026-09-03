# frozen_string_literal: true

module RecordingStudioOauth
  class ApplicationController < ActionController::Base
    include RecordingStudio::UsesDefaultLayout
    include Devise::Controllers::Helpers if defined?(Devise)

    protect_from_forgery with: :exception

    helper RecordingStudio::LayoutHelper
  end
end
