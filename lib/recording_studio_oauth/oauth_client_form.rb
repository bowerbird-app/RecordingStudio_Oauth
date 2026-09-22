# frozen_string_literal: true

module RecordingStudioOauth
  class OauthClientForm
    def initialize(params)
      @params = params.fetch(:oauth_client, {}).permit(
        :name,
        :redirect_uris,
        :secret,
        :use_central_relay,
        :allowed_return_patterns,
        :exact_return_urls
      )
    end

    def secret_choice
      params[:secret].presence || Services::CreateOauthClient::PUBLIC_SECRET_CHOICE
    end

    def create_args
      shared_args.merge(
        confidential: Services::CreateOauthClient.confidential?(secret_choice)
      )
    end

    def update_args(client)
      shared_args.merge(client: client)
    end

    private

    attr_reader :params

    def shared_args
      {
        name: params[:name],
        redirect_uris: lines(params[:redirect_uris]),
        use_central_relay: relay_flag,
        allowed_return_patterns: lines(params[:allowed_return_patterns]),
        exact_return_urls: lines(params[:exact_return_urls])
      }
    end

    def lines(text)
      Services::CreateOauthClient.redirect_uris_from_lines(text)
    end

    def relay_flag
      value = params[:use_central_relay]
      value.is_a?(Array) ? value.last : value
    end
  end
end
