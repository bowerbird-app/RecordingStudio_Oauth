# Upgrading

## 0.1.1

This gem still does not depend on Users. Connect is unchanged.

If the host wants social login and the preferred email-first sign-in path on the way into Connect:

1. Add and mount [Recording Studio Users](https://github.com/bowerbird-app/RecordingStudio_users) (`v0.10.0` or newer).
2. Skip Devise sessions, registrations, and passwords; point OmniAuth callbacks at Users; call `recording_studio_user_auth_for :users`.
3. Set `primary_login_type` (`:email` default → password on screen 2, or `:otp` when OTP is enabled).
4. Put OmniAuth provider secrets under Rails credentials `omniauth:` (or set `omniauth_providers`).
5. Confirm an unauthenticated `/oauth/authorize` request returns to Connect after sign-in (Devise stores the return path).

## 0.1.0

First release. There is no previous version to upgrade from.

Add `recording_studio_oauth` to the host Gemfile, run the install and migrations generators, and allow `RecordingStudioOauth::OauthAuthorization` in Accessible `access_actor_types`.

Pin Recording Studio API to `~> 0.5.2`. Boot calls `RecordingStudioApi.register_oauth_grant` for `authorization_code` and `refresh_token`, and `RecordingStudioApi.register_token_authenticator` for `rsoauth_at_` bearer tokens. Those methods are required. Keep the API engine as the token URL. Do not add a second `/oauth/token` in this gem.
