# Upgrading

## 0.15.0

No Oauth migration. Install Oauth `0.15.0`.

Ask connect vs reconnect without touching tokens:

```ruby
RecordingStudioOauth.connection_status(provider:, root:, actor:)
# :missing, :active, or :needs_reconnect

RecordingStudioOauth.connection_id_for(provider:, root:, actor:)
# id for DELETE /outbound/connections/:id, or nil
```

Those helpers use the same ownership and access rules as
`connection_for`. They never refresh. `connection_for` is unchanged.

## 0.14.1

No Oauth migration. Install Oauth `0.14.1` to allow Recording Studio Metrics
`>= 0.3, < 1.0`. Dummy and development pin Metrics tag `v0.5.0`. No code change.

## 0.14.0

Install Oauth `0.14.0`. Run `bin/rails generate recording_studio_oauth:migrations`
and `bin/rails db:migrate`. That adds `recording_studio_oauth_outbound_connections`
and `recording_studio_oauth_outbound_handshakes`, plus a foreign key from
handshake `root_recording_id` to recordings (`on_delete: :cascade`).

Configure Active Record encryption if the host does not already. This gem encrypts
outbound access tokens, refresh tokens, and handshake verifiers with `encrypts`.

Start Connect with `POST /outbound/:provider/connect`. GET is rejected.
Disconnect stays `DELETE /outbound/connections/:id`.

Inbound OAuth behavior, routes, and tables are unchanged.

Register an outbound provider in an initializer:

```ruby
RecordingStudioOauth.register_outbound_provider(
  key: :google_drive,
  authorize_url: "https://accounts.google.com/o/oauth2/v2/auth",
  token_url: "https://oauth2.googleapis.com/token",
  scopes: ["https://www.googleapis.com/auth/drive.readonly"],
  pkce: true,
  refresh: true,
  revoke_url: "https://oauth2.googleapis.com/revoke"
)
```

Put `client_id` and `client_secret` in
`credentials.recording_studio_oauth.outbound.google_drive`, or pass them as
registration arguments.

Look up a usable token with
`RecordingStudioOauth.connection_for(provider:, root:, actor:)`.
That returns the actor's own user-level connection when it exists, otherwise the
root-level connection if the actor has at least view access. It refreshes an
expired token. It returns `nil` when there is no usable connection.

Root admins create and disconnect a root-level connection. Anyone with view
access may use it. A user-level connection is only for that person. Roots with
`shared: true` cannot own a root-level connection.

The callback consumes the handshake row before it calls the provider token
endpoint. A failed exchange does not un-consume that row.

Refresh locks the connection row before it writes. If another process revoked
the row, changed status, or rotated the refresh token during the provider call,
this attempt writes nothing.

Logs filter the `code` query param as an exact key (`/\Acode\z/`). They do not
filter `code_challenge` or `country_code`.

Delete expired or consumed handshake rows with
`bin/rails recording_studio_oauth:cleanup_outbound_handshakes` or
`RecordingStudioOauth::OutboundHandshake.cleanup_stale`.

## 0.13.2

No Oauth migration. Install Oauth `0.13.2`. Registered-apps charts
(Self-registered apps, Connections granted, Connections revoked) show the last
30 days and hide x-axis labels. Card numbers still count current list rows.
Section actions stay secondary. Metrics timeseries APIs are unchanged.

## 0.13.1

No Oauth migration. Install Oauth `0.13.1` to allow Recording Studio API
`>= 0.5.2, < 0.15` (API 0.14.0). Dummy and development pin API tag `v0.14.0`
and Logs tag `v0.4.1`. API 0.14.0 needs Logs `~> 0.4.1`.

## 0.13.0

No Oauth migration. Install Oauth `0.13.0`. Registered apps `New app` is
secondary. List filters sit inline. Self-registered, granted, and revoked keep
their last-12-months area charts. Card numbers count the same current rows as
their lists. Granted and revoked open the Connections list
(`oauth_connections`) at Active or Revoked. Self-registered opens Registered
apps with Source self-registered. `connections=granted` and
`connections=revoked` still filter Registered apps. Metrics timeseries APIs and
the `recording_studio_metrics` `>= 0.3, < 0.6` range are unchanged.

## 0.12.7

No Oauth migration. Install Oauth `0.12.7` to allow Recording Studio Metrics
`>= 0.3, < 0.6` (Metrics 0.5.0). Dummy and development pin Metrics tag `v0.5.0`
and API tag `v0.13.1`. Registered-apps charts pass `{ x:, y: }` points from
`chart_series` through unchanged.

## 0.12.6

No Oauth migration. Install Oauth `0.12.6` to allow Recording Studio API
`>= 0.5.2, < 0.14` (API 0.13.0). Dummy and development pin API tag `v0.13.0` and Logs tag `v0.4.1`.

## 0.12.5

No Oauth migration. Install Oauth `0.12.5`. Staff Admin Registered apps shows
three charts (self-registered apps, connections granted, connections revoked).
They read the existing OAuth metrics and open the Registered apps list. Count
cards are compact on the first row. Charts sit on the row below and cover the
last 12 months. Granted and revoked charts open the list filtered to apps with
a grant or revoke in that window. The list filters Source, Status (active by
default), and API from `RecordingStudioApi.configuration.api_names`. Add the
same widget keys on a host dashboard section if you want them there too. Mark
compact on the two count widgets so they stay on the first row.

## 0.12.4

No Oauth migration. Install Oauth `0.12.4`. Connect public rows use
`config.connectable_root_recordable_type_names` (default `["Workspace"]`).
A parentless MessageGroup is not a Connect row. Nested grants stay hidden.
AdminRoot is still operations-only via `admin_root_recordable_type_names`.
If your Connect roots are not named `Workspace`, set the allowlist to those
type names.

## 0.12.3

No Oauth migration. Install Oauth `0.12.3`. Connect lists grants whose parent
is a top-level root. Nested grants (folder, support ticket message group) no
longer appear. Grant on the workspace, or on AdminRoot for operations apps,
if the person should Connect there. Existing authorizations stay as they are.

## 0.12.2

No Oauth migration. Install Oauth `0.12.2` to allow Recording Studio API
`>= 0.5.2, < 0.12` (API 0.11.0). Dummy still pins API tag `v0.10.0` until
0.11.0 is released.

## 0.11.0

No Oauth migration. Install Oauth `0.11.0` and move `recording_studio_metrics`
to `~> 0.3` (tag `v0.3.1`). The new `oauth_clients.self_registered_over_time`
metric registers automatically with the other OAuth metrics.

## 0.10.2

No Oauth migration or host code change. Install Oauth `0.10.2` to get the
named-API `POST /apis/:api_key/register` route that the metadata already
advertises.

## 0.10.1

No Oauth migration or host code change. Install Oauth `0.10.1`. Widen Recording
Studio API to `>= 0.5.2, < 0.8` (dummy tag `v0.7.0`). Metrics must be
`~> 0.2, >= 0.2.2` (dummy tag `v0.2.2`) so API `0.7` can resolve.

## 0.10.0

No Oauth migration. Install Oauth `0.10.0` and add `recording_studio_trashable`
at tag `v0.10.0` (`~> 0.10`). Load query helpers only
(`require "recording_studio_trashable/query"`; Gemfile `require: false` when
Bundler would auto-require the gem). Do not load the full Trashable engine for
these Oauth call sites.

Oauth Access grant voids and kept/trashed recording lookups use Trashable
sibling APIs (`void_recording!`, `recording_studio_trashable_kept?` /
`recording_studio_trashable_trashed?`, additive
`recording_studio_trashable_kept_sql`). Oauth does not use
`recording_studio_trashable_active` for those lookups: that scope unscopes
`trashed_at` first and is not identical to main's `where(trashed_at: nil)`.
Hosts that already have `trashed_at` on recordings do not need Trashable UI
migrations for these call sites.

## 0.9.0

No migration. Install Oauth `0.9.0` and add `recording_studio_cache` at tag `v0.5.0`.

`/register` still rate-limits per IP with `config.self_registered_apps_per_minute`
(`0` / blank / nil still disables). The limiter is now
`RecordingStudioCache::RateLimiter` behind the same `RegisterRateLimit` API.
Cache keys stay `recording_studio_oauth/register/<IP>`. Cache connection / IO
errors still raise.


## 0.8.0

No migration. Install Oauth `0.8.0` and add `recording_studio_metrics` at tag `v0.2.0`.

This gem registers OAuth metrics. The host exposes them once:

```ruby
RecordingStudioMetrics::Api.register!(api: :operations)
```

Staff with AdminRoot `:view` can read them on the operations API. A public token or a non-admin operations token is denied.

## 0.7.0

No migration. Hosts can translate Connect and connected-apps copy.

Copy `recording_studio.oauth.*` from `config/locales/en.yml` into host locale files. The gem ships English only. Do not add Recording Studio Internationalization to this gem — add it on the host if you want a language selector.

Arguments and config that pass copy still win. Client app names, descriptions, workspace titles, and other stored data stay untranslated. Role labels look up `recording_studio.oauth.roles.<name>` and fall back to humanize.

Staff Registered-app admin, OAuth protocol error codes, and JSON `error` / `error_description` stay English.

## 0.6.3

No host code change for public Connect or public MCP. Named APIs now allow the MCP identifier as `resource`.

Ops MCP clients (ChatGPT Connect included) must send `resource` of the MCP URL:

`https://<host>/recording_studio_mcp/apis/operations`

Authorize stays `/recording_studio_oauth/apis/operations/oauth/authorize`. Token stays `/recording_studio_api/apis/operations/oauth/token`. A present `resource` that is not in that named registry is still `invalid_target`. Omit `resource` as before.

`GET /.well-known/oauth-protected-resource/recording_studio_mcp/apis/operations` is that identifier. `authorization_servers` is `/recording_studio_oauth/apis/operations`.

## 0.6.2

No host code change for public Connect. New apps still default to the public named API.

To register a staff operations app:

1. Define `config.api :operations` on Recording Studio API.
2. Create the Registered App with API set to Operations (`api_key: "operations"`). That string is the named API label, not a secret.
3. Connect at `/recording_studio_oauth/apis/operations/oauth/authorize`. Staff Admin appears on the list for people who already have Admin access. Public apps still skip it.

## 0.6.0

Run the new migration after you pull this version.

```bash
bin/rails generate recording_studio_oauth:migrations
bin/rails db:migrate
```

Hosts that already call `ProtectedResourceRegistry.draw_origin_well_known(self)` get RFC 8414 path insertion on the next boot. `GET /.well-known/oauth-authorization-server/recording_studio_oauth` returns metadata whose `issuer` is `https://<host>/recording_studio_oauth`. Keep that helper. Do not add OpenID Connect discovery.

Self-registered apps stay off. MCP Inspector and similar clients need:

```ruby
RecordingStudioOauth.configure do |config|
  config.allow_self_registered_apps = true
end
```

That advertises `registration_endpoint` and accepts `POST /recording_studio_oauth/register`. Dummy sets this on. `config.allow_registration` is still only the starting signup flag on a new app.

Optional: `config.self_registered_apps_per_minute` (default 10) rate-limits `/register` per IP. Set `0` to turn the limit off.

Registration does not grant access. People still Connect. Staff revoke a self-registered app from Registered apps.

Re-consent no longer revokes live tokens. ChatGPT and other clients that keep an old refresh token after a second Connect will not void the new pair. Replay of a rotated refresh token still voids the grant.

## 0.5.6

No host code change. Recording Studio API may be 0.5.2 through 0.6. Pin `>= 0.5.2, < 0.7`. Dummy uses `v0.6.0`. Connect, token exchange, and grant hooks stay the same. API 0.6's optional `progress_reporter` is unused here.

## 0.5.5

Pin Accessible `~> 0.11` and match dummy tags for Admin, Attachable, Site Settings, and Root Switchable as in `MIGRATION_NOTES.md`. Run new Accessible and Attachable dummy migrations on hosts that copy engine migrations into the app. Access roles are strings (`view`, `edit`, `admin`). Dummy grants go through Accessible services.

## 0.5.3

Run the new migration after you pull this version.

```bash
bin/rails generate recording_studio_oauth:migrations
bin/rails db:migrate
```

On each Registered App that should check a channel session token, turn on Token verification and set Channel, Who the token is for, and Session token secret. Who the token is for is the channel's own app id. It is not the `rsoauth_oc_…` Registered App id. Turning Token verification off clears those three.

Hosts call `RecordingStudioOauth.verify_session_token`, read claims themselves, then call `RecordingStudioOauth.record_external_install` with `provider` and `external_id`. An install row can exist before merchant Connect. Bind `root_recording` and `connected_by` only when Connect finishes.

See `docs/session-tokens.md`.

## 0.5.2

No host steps. The create and edit forms put Allow registration above Use central relay with the same gap as the other fields.

## 0.5.1

Set the starting value for a new app in `config/initializers/recording_studio_oauth.rb`:

```ruby
RecordingStudioOauth.configure do |config|
  config.allow_registration = false
end
```

`false` keeps the next app closed. `true` checks Allow registration on the next app you create. Apps that already exist keep the flag they have. Changing this setting does not rewrite them.

Each app still has its own Allow registration checkbox. Connect options still uses that checkbox.

The Registration page and the Registration button on Registered apps are gone.

Run the migration that drops `recording_studio_oauth_registration_settings`:

```bash
bin/rails generate recording_studio_oauth:migrations
bin/rails db:migrate
```

## 0.5.0

Run the new migration after you pull this version.

```bash
bin/rails generate recording_studio_oauth:migrations
bin/rails db:migrate
```

Existing Registered Apps get Allow registration off. The site choice also starts off, so a new app stays off until staff turn the site choice on or check the box on that app.

In Admin, open Registered apps and choose Registration. That checkbox is the starting value for the next app you create. Each app still has its own Allow registration checkbox. Connect options uses the app checkbox.

A WordPress plugin can ask this host, with no login:

```text
GET /recording_studio_oauth/connect/options?client_id=<RECORDING_STUDIO_CLIENT_ID>
```

When that app allows registration the body is:

```json
{ "registration": true, "registration_url": "https://<host>/users/sign_up" }
```

When it does not, or the client id is unknown, the body is:

```json
{ "registration": false }
```

`registration_url` is left out when `registration` is false. The default path is `/users/sign_up`, the Users signup page this dummy mounts with Devise. If your host mounts signup somewhere else, set `config.registration_path`. If the public host differs from the request host, set `config.public_origin` and the absolute URL uses that origin.

This gem does not change the WordPress plugin, and it does not send someone from signup back into Connect.

See `docs/connect-options.md`.

## 0.4.2

No host steps. On the Registered App create and edit forms, **Exact return URLs** sits below **Allowed return patterns** with the same gap as the other fields.

## 0.4.1

No host steps. On the Registered App create and edit forms, **Create app** and **Save** sit under **Use central relay**.

## 0.4.0

`/recording_studio_oauth/wordpress/connect` and `/recording_studio_oauth/wordpress/callback` are gone. Nothing redirects from them.

`RecordingStudioOauth.wordpress_relay_connect_url` and `wordpress_relay_callback_url` are gone. Use `central_relay_connect_url(base_url:)` and `central_relay_callback_url(base_url:)`.

To keep a WordPress app on the central relay:

1. Set the Registered App redirect URI to `https://<your-host>/recording_studio_oauth/callback`.
2. Turn on Use central relay.
3. Add this allowed return pattern, one line:

```text
https://*/wp-admin/admin-post.php?action=recording_studio_oauth_callback
```

4. Point the client at `https://<your-host>/recording_studio_oauth/connect` with `client_id`, `return_to`, `state`, and PKCE S256.
5. On token exchange, send the fixed callback as `redirect_uri`.

Existing apps stay off the relay, so their current redirect URI list still works. The WordPress plugin template still calls the old paths until that repo is updated. This gem does not change it.

See `docs/central-connect-relay.md`.

## 0.3.0

No change for hosts that do not run WordPress Connect.

To share one WordPress Registered App across many sites:

1. Register one public app named WordPress, or keep the name you already use.
2. Set its redirect URI to `https://<your-host>/recording_studio_oauth/wordpress/callback`. Use `RecordingStudioOauth.wordpress_relay_callback_url(base_url:)` if you seed the app.
3. Point the WordPress plugin at `https://<your-host>/recording_studio_oauth/wordpress/connect` with `client_id`, `return_to`, `state`, and PKCE S256.
4. On token exchange, send that same relay callback as `redirect_uri`. Do not send the WordPress admin-post URL.

`return_to` must be the site's `admin-post.php?action=recording_studio_oauth_callback` URL. Extra query keys are rejected. The plugin Settings UI and ZIP client id stay in the WordPress plugin repo.

0.4.0 removes these paths. Follow the 0.4.0 section.

## 0.2.2

No host code change. A public app created in Registered Apps (`api_key` defaults to `public`) can exchange an authorization code, and refresh the issued tokens, on a named API token URL such as `/recording_studio_api/apis/wp_plugin_demo/oauth/token`. Confidential clients still have to match that API.

WordPress Connect still cannot call `/recording_studio_api/apis/wp_plugin_demo/v1/...` with that bearer until Recording Studio API accepts a public Oauth client on a named resource path. Do not remove the `api_key=wp_plugin_demo` seed until that API change lands.

## 0.2.1

No host code change. Connect and Cancel on the permission screen submit as a full page navigation so an off-host `redirect_uri` is not fetched by Turbo Drive. Workspace list GET links stay on Turbo.

## 0.2.0

Protected resource identities are a registry. The public authorization server advertises the API path and the MCP mount. Tokens stay unbound `rsoauth_at_` bearers.

### Origin well-known

`GET /.well-known/oauth-protected-resource` on the host origin no longer returns the API document. That URL is 404 unless you set `register_origin_as_protected_resource = true`. ChatGPT and API clients keep using `/recording_studio_oauth/.well-known/oauth-protected-resource`.

Draw the origin path-inserted routes in the host:

```ruby
RecordingStudioOauth::ProtectedResourceRegistry.draw_origin_well_known(self)
```

That serves `/.well-known/oauth-protected-resource/recording_studio_mcp` and `/.well-known/oauth-protected-resource/recording_studio_api/api`.

The install generator adds this call. Existing hosts need it in `config/routes.rb`.

### Config

New keys on `RecordingStudioOauth.configuration`:

- `mcp_mount_path`, default `/recording_studio_mcp`
- `register_origin_as_protected_resource`, default `false`
- `extra_protected_resource_paths`, default `[]`
- `public_origin`, optional. Token-time `resource` checks use this host when there is no request.

### Authorize and token

A present `resource` parameter must match a registry entry. Unknown values return `invalid_target`. You can still omit the parameter. The value is not stored on codes, grants, or tokens. `TokenAuthenticator` is unchanged.

### MCP 401

This gem does not change RecordingStudio_MCP. Point `WWW-Authenticate` `resource_metadata` at the MCP well-known URL. See README.

## 0.1.0

First release. There is no previous version to upgrade from.

Add `recording_studio_oauth` to the host Gemfile, run the install and migrations generators, and allow `RecordingStudioOauth::OauthAuthorization` in Accessible `access_actor_types`.

Pin Recording Studio API to `~> 0.5.2`. Boot calls `RecordingStudioApi.register_oauth_grant` for `authorization_code` and `refresh_token`, and `RecordingStudioApi.register_token_authenticator` for `rsoauth_at_` bearer tokens. Those methods are required. Keep the API engine as the token URL. Do not add a second `/oauth/token` in this gem.
