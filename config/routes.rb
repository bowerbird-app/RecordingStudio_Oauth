# frozen_string_literal: true

RecordingStudioOauth::Engine.routes.draw do
  get "/.well-known/oauth-authorization-server",
      to: "oauth_discoveries#authorization_server",
      defaults: { api_key: "public" },
      as: :oauth_authorization_server_metadata
  get "/.well-known/oauth-protected-resource",
      to: "oauth_discoveries#protected_resource",
      defaults: { api_key: "public" },
      as: :oauth_protected_resource_metadata
  match "/oauth/authorize",
        to: "oauth_authorizations#new",
        via: :get,
        defaults: { api_key: "public" },
        as: :oauth_authorize
  match "/oauth/authorize",
        to: "oauth_authorizations#create",
        via: :post,
        defaults: { api_key: "public" }
  get "/connect",
      to: "central_relays#start",
      as: :central_oauth_connect
  get "/connect/options",
      to: "connect_options#show",
      as: :connect_options
  get "/callback",
      to: "central_relays#callback",
      as: :central_oauth_callback

  resources :connected_apps, only: %i[index destroy]

  namespace :admin do
    resource :registration_setting, only: %i[show update], controller: "registration_settings"
    resources :oauth_clients, only: %i[new create show edit update]
    post "oauth_clients/:id/revoke", to: "oauth_clients#revoke", as: :revoke_oauth_client
  end

  match "/apis/:api_key/oauth/authorize",
        to: "oauth_authorizations#new",
        via: :get,
        as: :named_api_oauth_authorize
  match "/apis/:api_key/oauth/authorize",
        to: "oauth_authorizations#create",
        via: :post
  get "/apis/:api_key/.well-known/oauth-authorization-server",
      to: "oauth_discoveries#authorization_server"
  get "/apis/:api_key/.well-known/oauth-protected-resource",
      to: "oauth_discoveries#protected_resource"
end
