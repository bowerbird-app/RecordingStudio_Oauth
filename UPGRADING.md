# Upgrading

## 0.1.0

First release. There is no previous version to upgrade from.

Add `recording_studio_oauth` to the host Gemfile, run the install and migrations generators, and allow `RecordingStudioOauth::OauthAuthorization` in Accessible `access_actor_types`.

Keep Recording Studio API as the token URL. Do not add a second `/oauth/token` in this gem.
