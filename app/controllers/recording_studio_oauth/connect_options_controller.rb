# frozen_string_literal: true

module RecordingStudioOauth
  class ConnectOptionsController < ActionController::API
    def show
      render json: RecordingStudioOauth.registration_options(client_id: params[:client_id], base_url: request.base_url)
    end
  end
end
