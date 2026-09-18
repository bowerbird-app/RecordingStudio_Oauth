# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.2] - 2026-09-18

Public Registered Apps can finish Connect token exchange on a named API token URL.

### Fixed
- `AuthenticateOauthClient` accepts a public client with `api_key=public` on a named-API token request. WordPress Connect posts `authorization_code` (and later `refresh_token`) to `/recording_studio_api/apis/<named>/oauth/token`. Handmade public apps no longer need `api_key=wp_plugin_demo`.
- Confidential clients still must match the request API and present a valid secret. Public clients still must not send a secret.

### Notes
- Authorize stays on `/recording_studio_oauth/oauth/authorize`. This gem still does not mount a token endpoint.
- `client_credentials` stays in Recording Studio API and still requires a client bound to that named API.

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

[0.2.2]: https://github.com/bowerbird-app/RecordingStudio_Oauth/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/bowerbird-app/RecordingStudio_Oauth/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_Oauth/releases/tag/v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_Oauth/releases/tag/v0.1.0
