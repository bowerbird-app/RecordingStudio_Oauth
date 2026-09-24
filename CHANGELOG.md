# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.3] - 2026-09-24

Channel hosts can prove a session JWT and map that install to a workspace without channel columns on users or workspaces.

### Added
- `RecordingStudioOauth.verify_session_token` checks HS256 with the Registered App signing secret and Who the token is for (`aud`). It also checks `exp` and `nbf`. It returns the raw claims. The host interprets channel claims.
- `recording_studio_oauth_external_installs` maps `provider` + `external_id` + Registered App to an optional root recording and `connected_by`. `RecordingStudioOauth.record_external_install` upserts that row.
- Registered App create and edit take Channel, Who the token is for, and Session token secret.

### Notes
- Installed is not Connected. A verify upsert can exist before merchant Connect binds a workspace.
- The channel app id is the token `aud`. The Registered App id `rsoauth_oc_…` is Connect login only.
- Session token secret is stored encrypted. The Connect secret stays a digest and is not reused for HMAC.

## [0.5.2] - 2026-09-23

### Fixed
- The Registered App create and edit forms stack Allow registration above Use central relay with the same gap as the other fields.

## [0.5.1] - 2026-09-23

The site registration choice lives in `config/initializers/recording_studio_oauth.rb`. Registered apps no longer shows that control.

### Changed
- `config.allow_registration` is the starting value for a new Registered App. It defaults to false. Connect options still read each app's Allow registration flag.

### Removed
- The Registration button on Registered apps, the Admin Registration page, and `RegistrationSetting`. The migration drops `recording_studio_oauth_registration_settings`. Existing apps keep their own flag.

## [0.5.0] - 2026-09-23

Staff can allow registration for the site, and turn it on or off for each Registered App. The app choice is the one a public Connect options request returns.

### Added
- Site registration choice in Admin, on Registered apps, under Registration. New apps start with that choice. The choice starts off.
- Allow registration on the Registered App create and edit forms.
- `GET /recording_studio_oauth/connect/options?client_id=`. The JSON is `{ "registration": true, "registration_url": "https://<host>/users/sign_up" }` when that app allows registration. Otherwise `{ "registration": false }`. An unknown client id is closed.
- `RecordingStudioOauth.registration_allowed?(client_id:)` and `registration_url(base_url:)`.
- `config.registration_path`, default `/users/sign_up`. `config.public_origin` is used in the absolute URL when it is set.

### Notes
- Existing Registered Apps stay off until staff turn Allow registration on for that app.
- Changing the site choice does not change apps that already exist.
- The WordPress plugin is unchanged in this release. It can fetch Connect options with the same client id it stores as `RECORDING_STUDIO_CLIENT_ID`.
- Signup stays on the host Users page. This release does not resume Connect after signup.

## [0.4.2] - 2026-09-22

### Fixed
- On the Registered App form, **Exact return URLs** keeps the same gap above it as the other fields.

## [0.4.1] - 2026-09-22

### Fixed
- On the Registered App form, **Create app** and **Save** sit on their own row under **Use central relay**. They no longer share that line when the return rules are hidden.

## [0.4.0] - 2026-09-22

Any Registered App can use the central Connect relay. Staff turn it on and list return patterns or exact URLs. The WordPress-only paths are gone.

### Added
- `GET /recording_studio_oauth/connect` starts Connect for an app with Use central relay on. It signs `return_to` into `state` and sends the person to authorize with the fixed callback as `redirect_uri`.
- `GET /recording_studio_oauth/callback` is that fixed redirect. It returns the authorization code only when `return_to` matches the app's patterns or exact URLs.
- Registered App fields `use_central_relay`, `allowed_return_patterns`, and `exact_return_urls`. Patterns use `*` as a wildcard, not a regular expression.
- `RecordingStudioOauth.central_relay_callback_url(base_url:)` and `central_relay_connect_url(base_url:)`.
- Staff can edit a Registered App, including the relay rules.

### Removed
- `GET /recording_studio_oauth/wordpress/connect` and `GET /recording_studio_oauth/wordpress/callback`. There is no redirect from those paths.
- `WordPressCallbackUrl`, `WordPressRelay`, `WordPressRelayState`, and `RecordingStudioOauth.wordpress_relay_callback_url` / `wordpress_relay_connect_url`.

### Notes
- Apps that already exist stay off the relay until staff turn it on. An app with the relay off cannot use `/callback` as an open return path.
- Token exchange still uses the fixed callback as `redirect_uri`, not the client's return address.
- For WordPress, set the redirect to `{host}/recording_studio_oauth/callback`, turn Use central relay on, and add `https://*/wp-admin/admin-post.php?action=recording_studio_oauth_callback`. The WordPress plugin repo still points at the old paths until a later change.

## [0.3.0] - 2026-09-21

A host can mount one WordPress Connect relay so many WordPress sites share one Registered App.

### Added
- `GET /recording_studio_oauth/wordpress/connect` starts Connect. It signs the WordPress `return_to` into `state` and sends the person to authorize with the fixed relay `redirect_uri`.
- `GET /recording_studio_oauth/wordpress/callback` is the Registered App redirect. It returns the authorization code only to the WordPress callback bound at start.
- `WordPressCallbackUrl` allows only `…/wp-admin/admin-post.php?action=recording_studio_oauth_callback`.
- `RecordingStudioOauth.wordpress_relay_callback_url(base_url:)` and `wordpress_relay_connect_url(base_url:)` for host seeds and the WordPress plugin.

### Notes
- Register one public WordPress app. Put the relay callback on that app. Do not add each WordPress origin as a redirect URI.
- Token exchange still uses `/recording_studio_api/oauth/token` (or a named API token URL). `redirect_uri` there is the relay callback, not the WordPress admin-post URL.
- The code verifier stays on the WordPress site. The relay never reads it and never stores the authorization code.

## [0.2.2] - 2026-09-18

Public Registered Apps can finish Connect token exchange on a named API token URL.

### Fixed
- `AuthenticateOauthClient` accepts a public client with `api_key=public` on a named-API token request. WordPress Connect posts `authorization_code` (and later `refresh_token`) to `/recording_studio_api/apis/<named>/oauth/token`. Handmade public apps no longer need `api_key=wp_plugin_demo`.
- Confidential clients still must match the request API and present a valid secret. Public clients still must not send a secret.

### Notes
- Authorize stays on `/recording_studio_oauth/oauth/authorize`. This gem still does not mount a token endpoint.
- `client_credentials` stays in Recording Studio API and still requires a client bound to that named API.
- A token minted this way still authenticates on the public API. Recording Studio API `TokenAuthenticationBase` still rejects that bearer on `/apis/<named>/...` because `OauthClient#api_key` is `public`. That check is in RecordingStudio_API.

## [0.2.1] - 2026-09-18

Connect and Cancel on the permission screen leave Turbo Drive so the grant can finish on an off-host `redirect_uri`.

### Fixed
- The consent form sets `data-turbo="false"`. Turbo Drive no longer fetches the client `redirect_uri` after Connect or Cancel. A WordPress callback such as `http://localhost:8888/wp-admin/admin-post.php` is a full page navigation. The workspace list stays a same-origin GET and keeps Turbo.

### Notes
- Hosts do not change config or routes.
- Do not add CORS headers on the client callback to paper over this.

## [0.2.0] - 2026-09-14

Protected resource identities for API and MCP on one authorization server.

### Added
- `ProtectedResource` and `ProtectedResourceRegistry`. Path is the identity. The absolute URI is `identifier_for(base_url:)`.
- Config: `mcp_mount_path` (default `/recording_studio_mcp`), `register_origin_as_protected_resource` (default `false`), `extra_protected_resource_paths` (default `[]`), and optional `public_origin` for token-time allow when there is no request.
- Origin path-inserted RFC 9728 metadata via `ProtectedResourceRegistry.draw_origin_well_known`.
- `invalid_target` when authorize or token send an unknown `resource`.

### Changed
- Origin unsuffixed `/.well-known/oauth-protected-resource` is 404 by default. It no longer serves the API document.
- Origin-root discovery issuer fallback reads `engine_mount_path`.

### Notes
- Tokens stay opaque `rsoauth_at_` bearers with no audience.
- Named API keys still advertise only that API's identifier.
- This gem does not change RecordingStudio_MCP. MCP 401 should send `resource_metadata` for the MCP well-known URL.

## [0.1.0] - 2026-09-02

First release of the Recording Studio authorization server.

### Added
- `OauthClient` registry (name, client id, redirect URIs, public or confidential, named API, revoked)
- `OauthAuthorization` as an Accessible actor, with authorization codes, rotating refresh tokens, and delegated access tokens
- Two-screen Connect: list of workspaces and folders, then permission capped at the person's own access
- Connected apps
- Staff admin of registered apps (Accessible grants on an admin root, not nominated admins). Staff can register an app from Registered apps, copy the client id and one-time secret, and revoke. Secret and Status on that table are Flatpack badges. Secret has a short tooltip. Status does not.
- RFC 8414 discovery that points `token_endpoint` at Recording Studio API
- Registers `authorization_code` and `refresh_token` on Recording Studio API 0.5.2 via `RecordingStudioApi.register_oauth_grant`
- Registers `RecordingStudioOauth::TokenAuthenticator` so `rsoauth_at_` bearer tokens authenticate on the API resource server
- Dummy host with Seed Demo App
- Dummy Tailwind writes resolved gem `@source` paths so Flatpack classes emit on Cloud Agent install paths
- Connect, permission, and error sit in a viewport-centered `max-w-sm` frame like login. Connected apps and staff admin stay on default layout.
- Connect title is `{app} wants to connect to {site}` from OauthClient plus Site Settings `name_for`
- Connect list has no PageNav. The list sits in a Card with default padding. Trailing status is a Flatpack Button (Connect default, Connected success, Reconnect danger). Reconnect wraps a Flatpack Tooltip. Permission title is `{picked parent} permissions`. Primary action is Connect.

### Notes
- This gem is not Users, Doorkeeper, DCR, OIDC, SAML, or OAuth scopes
- Machine API keys stay in Recording Studio API
- Recording Studio API `~> 0.5.2` is required for the grant hook and token authenticator
- Flatpack `~> 0.1.144` so Site Settings `v0.1.0` can install
- Site Settings `~> 0.1` / dummy tag `v0.1.0`. Dummy also pins Attachable `v0.5.1` because that gem requires it.

[0.5.3]: https://github.com/bowerbird-app/RecordingStudio_Oauth/compare/v0.5.2...v0.5.3
[0.5.2]: https://github.com/bowerbird-app/RecordingStudio_Oauth/compare/v0.5.1...v0.5.2
[0.5.1]: https://github.com/bowerbird-app/RecordingStudio_Oauth/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/bowerbird-app/RecordingStudio_Oauth/compare/v0.4.2...v0.5.0
[0.4.2]: https://github.com/bowerbird-app/RecordingStudio_Oauth/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/bowerbird-app/RecordingStudio_Oauth/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_Oauth/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_Oauth/compare/v0.2.2...v0.3.0
[0.2.2]: https://github.com/bowerbird-app/RecordingStudio_Oauth/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/bowerbird-app/RecordingStudio_Oauth/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_Oauth/releases/tag/v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_Oauth/releases/tag/v0.1.0
