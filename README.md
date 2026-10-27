# Recording Studio OAuth

This gem is the **authorization server**. Third-party apps register once. People Connect. The app gets its own access, not yours.

[Recording Studio API](https://github.com/bowerbird-app/RecordingStudio_api) is the **resource server**. Token URL stays `/recording_studio_api/oauth/token`. Machine API keys stay there too. This gem does not fork a second token endpoint.

It is not Users. It is not Doorkeeper. It is not OIDC or SAML. It is not OAuth scopes. The app does not act as the person. Dynamic Client Registration is optional and off for hosts.

## What you get

**OauthClient** is a registry row: name, client id, redirect URIs, public or confidential, named API, optional plugin key, revoked. It is not a recordable and not a child of Access. `api_key` is the named API label (`public`, `operations`, …), not a secret. New apps default to `public`. `plugin_key` is an optional lowercase label staff set on a registered app so a host can ask who is connected through that plugin. It is not unique. Self-registered apps cannot set it.

**OauthAuthorization** is an Accessible actor. Connect grants Access on the parent of the Access the person clicked, `depends_on:` that Access. The app's Access is a sibling of theirs. Same app and same node reconnects. Asking for more than they have, or a missing Access, rejects. Nothing is silently clamped.

Public clients must use PKCE S256. Refresh tokens rotate. Reusing an authorization code or a **rotated** refresh token voids the grant. Re-consent for the same app keeps live tokens. A refresh token revoked for any other reason returns `invalid_grant` and leaves the rest of the grant alone. Disconnect still voids the grant. Re-consent drops unused codes so they cannot void a later grant.

RFC 8414 discovery lives here. `authorization_endpoint` is this engine. `token_endpoint` and `revocation_endpoint` point at the API mount. Path-inserted metadata is at `/.well-known/oauth-authorization-server/recording_studio_oauth`. `issuer` is the mount URL. This gem is not an OpenID Connect provider, so `openid-configuration` stays 404.

## Protected resources

This gem is one authorization server. It advertises more than one protected-resource identity. Tokens stay opaque `rsoauth_at_` bearers with no audience.

| Kind | Identifier | Origin well-known |
| --- | --- | --- |
| API | `https://app.example.com/recording_studio_api/api` | `/.well-known/oauth-protected-resource/recording_studio_api/api` |
| MCP | `https://app.example.com/recording_studio_mcp` | `/.well-known/oauth-protected-resource/recording_studio_mcp` |
| Named API | `https://app.example.com/recording_studio_api/apis/operations` | `/.well-known/oauth-protected-resource/recording_studio_api/apis/operations` |
| Named MCP | `https://app.example.com/recording_studio_mcp/apis/operations` | `/.well-known/oauth-protected-resource/recording_studio_mcp/apis/operations` |

The engine URL `/recording_studio_oauth/.well-known/oauth-protected-resource` still serves the API identifier. Origin unsuffixed `/.well-known/oauth-protected-resource` is 404 unless you set `register_origin_as_protected_resource = true`.

Draw origin well-known in the host (authorization-server path insertion and protected-resource path insertion):

```ruby
mount RecordingStudioOauth::Engine, at: "/recording_studio_oauth"
RecordingStudioOauth::ProtectedResourceRegistry.draw_origin_well_known(self)
```

The MCP gem or host owns the 401. Point `resource_metadata` at the MCP document:

```http
WWW-Authenticate: Bearer realm="RecordingStudioMcp", resource_metadata="https://app.example.com/.well-known/oauth-protected-resource/recording_studio_mcp"
```

Build that header with:

```ruby
RecordingStudioOauth.protected_resources.www_authenticate_challenge(base_url: request.base_url)
```

The document at that URL is:

```json
{
  "resource": "https://app.example.com/recording_studio_mcp",
  "authorization_servers": ["https://app.example.com/recording_studio_oauth"],
  "bearer_methods_supported": ["header"]
}
```

`authorization_servers` is this gem's issuer. Token exchange stays `/recording_studio_api/oauth/token`. A token minted after an MCP `resource` value is still an `rsoauth_at_` bearer and authenticates on API and MCP.

API 401 stays `Bearer realm="RecordingStudioApi"`. Do not reuse that realm as MCP identity.

```ruby
RecordingStudioOauth.configure do |config|
  config.mcp_mount_path = "/recording_studio_mcp"
  config.register_origin_as_protected_resource = false
  config.extra_protected_resource_paths = []
  config.public_origin = "https://app.example.com"
end
```

A present `resource` on authorize or token must match a registry entry for that named API. Unknown values return `invalid_target`. Omit the parameter as before. The value is not stored. Ops MCP clients must send the named MCP URL, not the public MCP mount.

## Connect

Two screens, Flatpack, `data-theme="rounded"`. Connect uses a login-style frame: viewport-centered, `max-w-sm`. The access list has no back control. Permission and error keep a round PageNav back button. Connected apps and staff admin stay on the Recording Studio default layout. That layout draws one page title from `content_for :title` and `content_for :subtitle`. Set `RecordingStudioOauth.configuration.layout` to `nil` for that default, `false` for no layout, a layout name, or `->(controller:) { ... }`. Do not set `layout "recording_studio/default_layout"`.

The list title is `{app} wants to connect to {site}`. The app name is the registered OauthClient. The site name comes from Recording Studio Site Settings (`name_for`). If there is no site name, the title stops at `{app} wants to connect`. Several workspaces that share one site name keep that sentence. Different site names put each `name_for` on the row instead.

1. A list in a card with default padding. Each row is a workspace the person can already use. Trailing Flatpack buttons are Connect (default), Connected (success), or Reconnect (danger). Reconnect has a tooltip: "This connection is no longer live." Staff Admin is not a row for public apps. An operations app (`api_key: "operations"`) can Connect there. The list is flat, not a tree. Nested grants (folder, ticket) do not appear. Public rows use `config.connectable_root_recordable_type_names`. The default is `["Workspace"]`. A parentless MessageGroup, Press Kit, or other root is not a Connect row unless you add its type name. Staff Admin still uses `config.admin_root_recordable_type_names` and operations apps only.
2. `{picked parent} permissions`. Role picker when they have more than View, with no field label or help. Connect and Cancel are separate buttons. Cancel is `access_denied`. Those two submit with `data-turbo="false"` so an off-host `redirect_uri` is a full page navigation. Workspace list GET links stay on Turbo.

People can see and remove connected apps. Staff can register an app from Admin, copy the client id (and secret once), and revoke it. Registered apps shows Secret, API, and Status. Hover or focus explains Public versus Has a secret. Active and Revoked need no extra line. API is the named API label, not a secret.

To let ChatGPT or Grok Connect as staff later, create an operations app: pick Operations on New app (`api_key: "operations"`), then send the person to `/recording_studio_oauth/apis/operations/oauth/authorize`. Ops MCP Connect must pass `resource=https://<host>/recording_studio_mcp/apis/operations`. Public Connect stays on `/recording_studio_oauth/oauth/authorize` and still hides staff Admin.

## Install

1. Add the gem and pin Recording Studio `>= 6.1.0` (tag `v6.1.0`), Accessible `~> 0.11`, Admin `~> 2.0`, API `>= 0.5.2, < 0.17`, Cache `~> 0.5`, Site Settings `~> 0.2`, Flatpack `>= 0.1.315` (git ref `1fcbafe94f8eb118f0a22182f63f5110fcc97a56`, version `0.1.319`), Trashable `~> 0.10`, and `view_component` `>= 4.14, < 5`.
   Also add `recording_studio_metrics` `>= 0.3, < 1.0` (tag `v0.5.0`) and call `RecordingStudioMetrics::Api.register!(api: :operations)` once.
   Trashable owns Access grant voids and kept/trashed recording lookups via the query-only entry (`require "recording_studio_trashable/query"`: `void_recording!`, predicates, additive `recording_studio_trashable_kept_sql`). Pin git tag `v0.10.0` with `require: false` when Bundler would auto-require the gem.
2. Run `bin/rails generate recording_studio_oauth:install`.
3. Run `bin/rails generate recording_studio_oauth:migrations` and migrate.
4. Allow `RecordingStudioOauth::OauthAuthorization` in Accessible `access_actor_types`.
5. Enable `:accessible` on the root recordables people Connect from. Nested grants do not appear on Connect. Set `config.connectable_root_recordable_type_names` to those type names (`["Workspace"]` by default). Do not add conversation types such as `RecordingStudioMessages::MessageGroup`.
6. Host authentication stays on the host. Dummy uses Devise. Do not add Users as a dependency of this gem.
7. Install Recording Studio Site Settings (and Attachable, which that gem needs). Register `RecordingStudioSiteSettings::SiteSetting` and `RecordingStudioAttachable::Attachment`. Set `site_root_types` so Connect can read a site name.
8. If you mount staff admin, pin Turbo and Recording Studio Admin's screen controllers in the host importmap (see `test/dummy/config/importmap.rb`).

Boot registers `authorization_code` and `refresh_token` with `RecordingStudioApi.register_oauth_grant`. That hook is required. Boot also registers `RecordingStudioOauth::TokenAuthenticator` so `rsoauth_at_` tokens authenticate on the API resource server. Token exchange uses the API engine's existing `/oauth/token`, including a named path such as `/apis/wp_plugin_demo/oauth/token`. A public Registered App (`api_key=public`) can complete `authorization_code` and `refresh_token` on that named path. The minted bearer still authenticates on the public API. Recording Studio API still requires `api_client.api_key` to match a named resource path. Confidential clients still have to match the request API. `client_credentials` stays built into API. Do not copy Connect into the API gem.

## Translating

Connect and connected-apps copy lives under `recording_studio.oauth.*`. This gem ships **English only** in `config/locales/en.yml`. Hosts own other languages. Copy `recording_studio.oauth.*` into `config/locales/<locale>.yml` and list that locale in `config.i18n.available_locales`.

```erb
<%= t("recording_studio.oauth.connect.allow") %>
<%= t("recording_studio.oauth.connected_apps.title") %>
```

Do not add [Recording Studio Internationalization](https://github.com/bowerbird-app/RecordingStudio_Internationalization) as a dependency of this gem. It is optional on the host. The dummy uses it to switch English and French.

Arguments and host config that pass copy still win over locale defaults. Stored names stay data: client app names, descriptions, workspace titles, and other database content are not translated. Role labels look up `recording_studio.oauth.roles.<name>` and fall back to humanize. Human-readable scope descriptions look up `recording_studio.oauth.scopes.<name>` and fall back to the existing text.

Staff Registered-app admin screens stay English. OAuth protocol error codes and JSON `error` / `error_description` fields stay English. Dummy demo and docs pages stay English.

## Dummy

`test/dummy` on port 3000. Sign in with `admin@admin.com` / `Password`. Dummy credentials (`test/dummy/config/credentials.yml.enc`) are encrypted with the shared RecordingStudio_* development master key. Set `RAILS_MASTER_KEY` or put that key in `test/dummy/config/master.key` (gitignored). Keep the encrypted file; do not generate a per-repo dummy key. Seed Demo App is registered. Studio Workspace starts Connected (success), Docs Workspace starts as Reconnect (danger), Admin is staff-only for public apps. Product Docs is a folder under Studio Workspace and is not a Connect row. Dummy names an `operations` API so Registered apps can create an operations OauthClient. Switch to Admin, then Registered apps can add an app, show credentials once, and revoke. Both Studio Workspace and Docs Workspace seed site name `Studio` through Site Settings. Dummy Tailwind imports resolved engine paths from `gem_sources.css` before each build so Flatpack classes are not missed when gems sit under `/usr/local/lib/ruby/gems`.

Dummy offers English and French. The language selector sits in the top nav, left of the workspace switcher. French keys live in `test/dummy/config/locales/fr.yml`. The engine does not ship French. Dummy pins Recording Studio `v6.1.0`, Accessible `v0.18.0`, Attachable `v0.15.0`, Admin `v2.7.0`, Site Settings `v0.2.0`, Flatpack `0.1.319` (ref `1fcbafe94f8eb118f0a22182f63f5110fcc97a56`), and Recording Studio Internationalization `v0.1.2` (dummy only).

Dummy also pins Metrics `v0.5.0`, API `v0.14.0`, and Logs `v0.4.1`.

## Central Connect relay

A Registered App can use one fixed redirect on the host that mounts this engine. Staff turn on Use central relay and list the return addresses that app may use. Other apps keep a normal redirect URI list.

The redirect URI is:

`https://<host>/recording_studio_oauth/callback`

The app sends the person to:

```text
GET /recording_studio_oauth/connect
  client_id
  return_to
  state
  code_challenge
  code_challenge_method=S256
```

`return_to` must match one of that app's patterns or exact URLs. A star in a pattern matches any text. It is not a regular expression. Token exchange sends the fixed callback as `redirect_uri`. The code verifier stays with the app.

A WordPress site can use `https://*/wp-admin/admin-post.php?action=recording_studio_oauth_callback`. The WordPress plugin still calls the old `/wordpress/` paths until its own update.

See `docs/central-connect-relay.md`.

## Registration

Staff choose whether new apps start with registration allowed. Set `config.allow_registration` in `config/initializers/recording_studio_oauth.rb`. It starts off. Each Registered App has its own Allow registration checkbox. The app checkbox wins. The site choice only fills in a new app.

WordPress, or any other client, can read that choice without logging in:

```text
GET /recording_studio_oauth/connect/options?client_id=<client id>
```

```json
{ "registration": true, "registration_url": "https://<host>/users/sign_up" }
```

`registration` is false for an app that disallows it, and for an unknown client id. `registration_url` is omitted in that case. The path defaults to `/users/sign_up`. Set `config.registration_path` when the host mounts Users somewhere else. Set `config.public_origin` when the absolute URL should use a public origin.

Signup is the host Users page. This gem does not resume Connect after signup.

See `docs/connect-options.md`.

## Self-registered apps

MCP Inspector and other MCP clients can register without a staff-created app. That is RFC 7591 Dynamic Client Registration. It is off for hosts.

```ruby
RecordingStudioOauth.configure do |config|
  config.allow_self_registered_apps = true
end
```

When it is on, authorization-server metadata includes `registration_endpoint`, and `POST /recording_studio_oauth/register` creates an OauthClient. Dummy turns this on.

Defaults:

- Public client, `token_endpoint_auth_method` `none`, PKCE S256 required
- `client_secret_basic` or `client_secret_post` when requested; the secret is returned once and `client_secret_expires_at` is `0`
- Redirect URIs must be https, or http on localhost, 127.0.0.1, or `[::1]`, with any port. Fragments and wildcard hosts are rejected
- `/register` is limited to `config.self_registered_apps_per_minute` (default 10) per IP
- The app shows in Admin Registered apps as Self-registered. Staff can revoke it. Registration does not Connect

`config.allow_registration` is still the starting signup flag on a new app. It does not turn self-registered apps on.

MCP 2025-11-25 prefers Client ID Metadata Documents. This gem ships DCR, which Inspector v2.9.0 uses. CIMD is not implemented.

See `docs/self-registered-apps.md`.

## Session tokens and external installs

A channel host can prove a session JWT with HS256, then map that install to a workspace. Oauth checks signature, audience, `exp`, and `nbf`. The host reads claims and chooses `external_id`. Channel columns do not go on users or workspaces.

Who the token is for is the channel's own app id (`aud`). The Registered App id `rsoauth_oc_…` is merchant Connect only. Installed is not Connected.

```ruby
result = RecordingStudioOauth.verify_session_token(
  client_id: registered_app.client_id,
  token: session_token
)
RecordingStudioOauth.record_external_install(
  client: result.value.fetch(:client),
  provider: "channel",
  external_id: host_computed_id
)
```

See `docs/session-tokens.md`.

## Operations metrics

The gem depends on `recording_studio_metrics` and registers site-wide OAuth metrics. The host exposes them once:

```ruby
RecordingStudioMetrics::Api.register!(api: :operations)
```

Staff with AdminRoot `:view` can read them. A public token or a non-admin operations token is denied.

Staff Admin Registered apps charts `oauth_clients.self_registered_over_time`,
`oauth_authorizations.granted_over_time`, and `oauth_authorizations.revoked_over_time`.
Count cards sit on the first row. Charts sit on the row below and cover the last
30 days, without x-axis labels. Chart headlines count the same current rows as their target lists
(active self-registered apps, active connections, revoked connections).
Self-registered opens Registered apps with Source self-registered. Granted
opens Connections at Active. Revoked opens Connections at Revoked. Old
`connections=granted` and `connections=revoked` links still filter Registered
apps to that 12-month window. The list filters Source, Status (Active by
default), and API inline. `New app` is a normal button. Host dashboard sections
can list the same widget keys (`oauth.self_registered_over_time`,
`oauth.granted_over_time`, `oauth.revoked_over_time`). Mark the two count
widgets compact so they stay on the first row.

| Method | Path |
| --- | --- |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics` |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/oauth_clients/total` |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/oauth_clients/by_registration` |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/oauth_clients/self_registered_over_time` |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/oauth_authorizations/over_time` |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/oauth_authorizations/granted_over_time` |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/oauth_authorizations/revoked_over_time` |
| `GET` | `/recording_studio_api/apis/operations/v1/metrics/oauth_authorizations/by_role` |

`oauth_clients.total` is the Admin Registered-apps count (`OauthClient.active`). `oauth_clients.by_registration` splits that set on `self_registered`. `oauth_clients.self_registered_over_time` (unit `count`) is new self-registered (dynamic client registration) apps by `created_at`. It takes `from` / `to` (or `start` / `end`) and `interval` (`day`, `week`, `month`, `year`), and `group_by=confidential` (the list's "Secret" column: public vs confidential client) or `group_by=api_key` (the list's "API" column, a named API label). Groups under the Metrics `min_group_size` (5) fold into `other`, so groups plus `other` equal the total. There is no grouping by name, client id or redirect URI. Metrics still do not take the Registered apps Source, Status, or API list filters. Same Admin root `:view` check and site scope as that list. Revoked apps stay in the period they signed up in, so its buckets can add up to more than the self-registered row of `by_registration`. `oauth_authorizations.over_time` is new grants by `created_at`. `oauth_authorizations.by_role` uses `OauthAuthorization.active`. `oauth_authorizations.granted_over_time` (unit `count`) is grants by `created_at`, including ones revoked later. `oauth_authorizations.revoked_over_time` (unit `count`) is revocations by `revoked_at`. Both take `from` / `to` and `interval`, and `group_by=role` only (groups under `min_group_size` 5 fold into `other`). There is no grouping by app, actor or recording, and no filters, because the metrics APIs do not take list filters. Admin Connections (`oauth_connections`) lists current grants and revokes (Status Active by default) and does not apply those timeseries windows. Same Admin root `:view` check and site scope as the other OAuth metrics.

## Outbound connections

This gem is also the **connection layer** when this app talks to a third-party
provider such as Google Drive. Later addon gems register a provider here, store
tokens here, and look up a live access token here. Attachable and a Plugins
directory stay out of this gem.

`OutboundConnection` is a normal table, not a Recording. Tokens are infrastructure, not
tree content. A workspace-owned row has no person owner. A personal row belongs
to the person who connected, and it also stores the workspace they chose. Those
shapes stay two owners, not one polymorphic owner. Access rules and unique
indexes differ, so mixing them in one association would hide that.

Register a provider. Unknown keys raise.

```ruby
RecordingStudioOauth.register_outbound_provider(
  key: :google_drive,
  kind: :root,
  authorize_url: "https://accounts.google.com/o/oauth2/v2/auth",
  token_url: "https://oauth2.googleapis.com/token",
  scopes: ["https://www.googleapis.com/auth/drive.readonly"],
  pkce: true,
  refresh: true,
  revoke_url: "https://oauth2.googleapis.com/revoke"
)
```

`kind` is required and must be `:root` (workspace Connect) or `:user` (personal
Connect). `owner=root` only works for `:root` providers. `owner=user` only works
for `:user` providers. Omitting `owner` still defaults to workspace when
`root_recording_id` is present, and to personal when it is not.

Read `client_id` and `client_secret` from
`credentials.recording_studio_oauth.outbound.google_drive`, or pass them in the
register call. Dummy registers `:fake_drive` (`kind: :root`) and
`:fake_drive_user` (`kind: :user`). Both share the local `/fake_oauth/*`
adapter. Display name, description, and icon stay in the host or Plugins, keyed
by provider key.

List registered providers without secrets:

```ruby
RecordingStudioOauth.outbound_providers
# [{ key:, kind: }, ...]
```

That list is key and kind only; endpoints, `client_id` and secrets are never listed.

Routes on the engine mount:

- `POST /outbound/:provider/connect?owner=root&root_recording_id=` (workspace, admin only)
- `POST /outbound/:provider/connect?owner=user&root_recording_id=` (that person, on that workspace)
- `GET /outbound/callback`
- `DELETE /outbound/connections/:id`

PKCE and state live on a server-side handshake row. The callback consumes that
row before it exchanges the authorization code. A failed token request leaves
the handshake consumed, so the same state cannot be retried. Access and refresh
tokens never go in the session. They use Active Record encryption.

Logs filter the `code` parameter exactly (`/\Acode\z/`), plus `access_token` and
`refresh_token`. Keys that only contain "code", such as `code_challenge` or
`country_code`, stay visible.

Expired or consumed handshake rows are junk. Delete them with
`bin/rails recording_studio_oauth:cleanup_outbound_handshakes`, or call
`RecordingStudioOauth::OutboundHandshake.cleanup_stale`. Deleting a root
recording also deletes its handshake rows (foreign key `on_delete: :cascade`).

Look up a usable connection:

```ruby
connection = RecordingStudioOauth.connection_for(
  provider: :google_drive,
  root: workspace_root_recording,
  actor: current_user
)
connection&.access_token
```

Ask whether that person already has a live connection, without tokens and
without a refresh:

```ruby
status = RecordingStudioOauth.connection_status(
  provider: :google_drive,
  root: workspace_root_recording,
  actor: current_user
)
# :missing, :active, or :needs_reconnect

connection_id = RecordingStudioOauth.connection_id_for(
  provider: :google_drive,
  root: workspace_root_recording,
  actor: current_user
)
# DELETE /outbound/connections/:id
```

Resolution: the actor's own personal connection for that provider on the passed
root when the actor may view that root, else the workspace-owned one if the
actor may use it. A personal row for workspace A is not returned when lookup
passes workspace B. Losing view access on the stored root returns `nil`; the
row stays in the table and works again if access returns. Leftover personal
rows with no root (from before 0.16) become `needs_reconnect` and are not
attached to a workspace. Lookup never returns them.

Expired tokens refresh. Refresh writes under a row lock and no-ops if the row
was revoked, the status moved, or the refresh token rotated while the provider
call was in flight. A permanent OAuth failure (HTTP 400 or 401 with
`invalid_grant`, `invalid_client`, or `unauthorized_client`) marks
`needs_reconnect` and lookup returns `nil`. A 500 body that says `invalid_grant`
stays transient. Refresh does not raise into callers.

Count working personal connections on a workspace, without tokens:

```ruby
count = RecordingStudioOauth.connected_user_count(
  provider: :google_drive,
  root: workspace_root_recording
)
```

That integer is `active` personal rows only. It excludes `needs_reconnect`
(including leftover null-root rows), revoked rows, workspace-owned rows, and
other workspaces. Pass a blank provider or a nil root and it is `0`.

Access uses Recording Studio Accessible on the root. No Pundit. No extra grants.

- Only root admins can create or disconnect a workspace-owned connection.
- Anyone with at least view access can use a workspace-owned connection.
- Anyone with at least view access can Connect a personal row on that workspace.
- A personal connection is only usable by the person who made it, and only on
  the workspace stored on that row, while they can still view that workspace.
- Roots with `shared: true` cannot hold an outbound connection.

`connection_status` uses the same ownership and access rules. It returns
`:missing` when there is no live row the actor may use, `:needs_reconnect`
when that row needs a new Connect, and `:active` otherwise. An expired token
still counts as `:active` here; `connection_for` is the call that refreshes.
A live user-owned row is reported even when a usable root-owned row also
exists. `connection_id_for` returns that live row's id, or `nil`.

Ask for both slots without merging them:

```ruby
RecordingStudioOauth.combined_connection_status(
  provider: :google_drive,
  root: workspace_root_recording,
  actor: current_user
)
# { workspace: :missing|:active|:needs_reconnect,
#   personal: :missing|:active|:needs_reconnect }
```

Both slots are `:missing` when the actor may not view the root.

## Inbound plugin connections

Staff can set `plugin_key` on a registered app (letters, digits, underscores, start with a letter, 64 characters max). Example keys in a host might look like `chatgpt` or `grok_bot`. This gem does not know those products.

Ask whether the current person is connected through that key in a workspace, and how many people are:

```ruby
RecordingStudioOauth.inbound_connection_status(
  plugin_key: :inbound_demo,
  root: workspace_root_recording,
  actor: current_user
)
# { connected: true/false, connected_count: Integer or nil }
```

`connected` is true when that actor has an active inbound authorization on a non-revoked app with that key in that workspace, and the grant still has a usable token (an unexpired, non-revoked access token, or an unexpired, non-revoked refresh token). It is false when the actor cannot view the root, the root is blank, or the key is blank or unknown.

`connected_count` is the number of distinct people connected that way. It is returned only when the actor is an admin of that root. Everyone else gets `nil`. It never includes names, emails, or tokens.

List those people:

```ruby
RecordingStudioOauth.inbound_connections(
  plugin_key: :inbound_demo,
  root: workspace_root_recording,
  actor: current_user
)
# [{ actor_type:, actor_id:, role:, connected_at:, last_used_at:, app_name: }, ...]
```

Root admins get one row per person, ordered by `connected_at`. `role` is the highest grant among that person's live authorizations under the key. `connected_at` is the earliest of those authorizations. `last_used_at` is the latest access-token `last_used_at`, or `nil`. `app_name` joins distinct registered-app names in alphabetical order when the person connected through more than one app. Non-admins and people who cannot view the root get `[]`. The host resolves `actor_type` / `actor_id` to a display name. `connected_count` is that array's size.

## Version

0.19.0
