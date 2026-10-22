# frozen_string_literal: true

require "uri"

class FakeOauthController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token, only: %i[token revoke]

  def authorize
    unless FakeOauth.valid_client?(params[:client_id])
      render plain: "unknown client", status: :bad_request
      return
    end

    code = FakeOauth.issue_code(
      access_token: "fake-access-#{SecureRandom.hex(8)}",
      refresh_token: "fake-refresh-#{SecureRandom.hex(8)}",
      user_id: "acct-demo",
      email: "demo@fake-drive.test"
    )
    redirect_to callback_location(code), allow_other_host: true
  end

  def token
    status, body = FakeOauth.call(request.url, params.to_unsafe_h)
    render json: body, status: status
  end

  def revoke
    status, body = FakeOauth.call(request.url, params.to_unsafe_h)
    render json: body, status: status
  end

  private

  def callback_location(code)
    uri = URI.parse(params[:redirect_uri].to_s)
    query = URI.decode_www_form(uri.query.to_s)
    query << ["code", code]
    query << ["state", params[:state].to_s]
    uri.query = URI.encode_www_form(query)
    uri.to_s
  end
end
