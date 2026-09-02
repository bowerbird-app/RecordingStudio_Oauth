# Upgrading

## 0.1.0

First release. There is no previous version to upgrade from.

Add `recording_studio_oauth` to the host Gemfile, run the install and migrations generators, and allow `RecordingStudioOauth::OauthAuthorization` in Accessible `access_actor_types`.

Pin Recording Studio API to `~> 0.5.2`. Boot calls `RecordingStudioApi.register_oauth_grant` for `authorization_code` and `refresh_token`. That method is required. Keep the API engine as the token URL. Do not add a second `/oauth/token` in this gem.
