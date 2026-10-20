# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.13.1] - 2026-10-20

### Changed
- Allow `recording_studio_api` `>= 0.5.2, < 0.15` so hosts can run API 0.14.0.
  Development and dummy Gemfiles pin API tag `v0.14.0` and Logs tag `v0.4.1`.

### Upgrade notes
- Bump to `0.13.1`. No migration.
- Pin Recording Studio API at tag `v0.14.0` (or any `>= 0.5.2, < 0.15`).
- API 0.14.0 needs `recording_studio_logs ~> 0.4.1`. Dummy and development already pin Logs tag `v0.4.1`.

## [0.13.0] - 2026-10-20

### Fixed
- Admin Registered apps `New app` is a normal button, not primary.
- Registered apps shows Source, Status, and API filters inline. Status still
  defaults to Active.
- Self-registered apps, Connections granted, and Connections revoked keep their
  area charts (last 12 months, Metrics `chart_series`, 365-day window). Card
  numbers count the same current rows as their target lists, so older rows still
  show on the headline.
- Connections granted opens the Connections list at Active. Connections revoked
  opens it at Revoked. Self-registered apps opens Registered apps filtered to
  self-registered (Active by default). `connections=granted` and
  `connections=revoked` still filter Registered apps.

### Added
- Staff Admin Connections list (`oauth_connections`): app, role, and status.
  Status defaults to Active. Granted and revoked charts deep-link here.

### Upgrade notes
- Bump to `0.13.0`. No migration.
- Widget keys are unchanged. Charts still read Metrics timeseries. Card numbers
  are live list counts, not last-12-months totals. Host dashboards that listed
  the same keys get the new counts and links. Metrics timeseries APIs are
  unchanged. `recording_studio_metrics` stays `>= 0.3, < 0.6`.

## [0.12.7] - 2026-10-20

### Changed
- Allow `recording_studio_metrics` `>= 0.3, < 0.6` so hosts can run Metrics 0.5.0.
  Development and dummy Gemfiles pin Metrics tag `v0.5.0` and API tag `v0.13.1`.
- Admin Registered-apps charts pass `RecordingStudioMetrics::Admin.chart_series` through unchanged. Metrics 0.5.0 already emits `{ x:, y: }` points, so this gem no longer remaps `[date, value]` pairs.

### Upgrade notes
- Bump to `0.12.7`. No migration.
- Pin Recording Studio Metrics at tag `v0.5.0` (or any `>= 0.3, < 0.6`). Charts expect `{ x:, y: }` points from `chart_series`.
- Pin Recording Studio API at tag `v0.13.1` (or any `>= 0.5.2, < 0.14`).

## [0.12.6] - 2026-10-20

### Changed
- Allow `recording_studio_api` `>= 0.5.2, < 0.14` so hosts can run API 0.13.0.
  Development and dummy Gemfiles pin API tag `v0.13.0` and Logs tag `v0.4.1`.

### Upgrade notes
- Bump to `0.12.6`. No migration.
- Pin Recording Studio API at tag `v0.13.0` (or any `>= 0.5.2, < 0.14`).

## [0.12.5] - 2026-10-19

### Added
- Admin Registered-apps dashboard charts for `oauth_clients.self_registered_over_time`,
  `oauth_authorizations.granted_over_time`, and `oauth_authorizations.revoked_over_time`.
  Each chart reads `RecordingStudioMetrics` and links to the Registered apps screen.
  Charts cover the last 365 days, not the 30-day default, so rows on Registered
  apps still appear on the cards. Compact count cards sit on the first row. The
  three charts sit on the row below. Connections granted and Connections revoked
  open the list filtered to apps with a grant or revoke in that window. The list
  filters Source (staff or self-registered), Status (active by default, or
  revoked), and API (named APIs the host registered).

### Upgrade notes
- Bump to `0.12.5`. No migration.
- Hosts that already mount staff Admin get the three charts on Registered apps
  and on any host section that lists the new widget keys.

## [0.12.4] - 2026-10-16

### Fixed
- Connect public rows are an allowlist of recordable types
  (`config.connectable_root_recordable_type_names`, default `["Workspace"]`).
  A parentless MessageGroup (or any other non-workspace root) is no longer a
  Connect row. Nested grants stay excluded. AdminRoot is unchanged: operations
  apps only, via `admin_root_recordable_type_names`.

### Upgrade notes
- Bump to `0.12.4`. No migration.
- Hosts whose Connect roots are not named `Workspace` must set
  `config.connectable_root_recordable_type_names` to those type names.
  Adding a type includes it. Message groups stay off the list.

## [0.12.3] - 2026-10-16

### Fixed
- Connect lists only grants whose parent is a top-level root (a workspace, or
  AdminRoot for operations apps). Nested grants such as a folder or a support
  ticket message group no longer appear as Connect rows.

### Upgrade notes
- Bump to `0.12.3`. No migration.
- People with a grant only on a nested recording no longer see a Connect row
  for it. Grant them on the workspace (or AdminRoot for operations apps) if
  they should Connect there. Existing authorizations are unchanged.

## [0.12.2] - 2026-10-15

### Changed
- Allow `recording_studio_api` `>= 0.5.2, < 0.12` so hosts can run API 0.11.0.
  Development and dummy Gemfiles still pin API tag `v0.10.0` until 0.11.0 is released.

### Upgrade notes
- Bump to `0.12.2`. No migration.

## [0.12.1] - 2026-10-14

### Changed
- Allow `recording_studio_api` `>= 0.5.2, < 0.11` so hosts can run API 0.10.0.
  Development and dummy Gemfiles pin API tag `v0.10.0`.

## [0.12.0] - 2026-10-14

### Added
- `oauth_authorizations.granted_over_time` (timeseries, unit `count`): authorizations granted per period by `created_at`. Ones revoked later still count.
- `oauth_authorizations.revoked_over_time` (timeseries, unit `count`): authorizations revoked per period by `revoked_at`.
- Both take `from` / `to` and `interval`, plus `group_by=role`; groups under `min_group_size` (5) fold into `other`. There is no grouping by client, actor or recording, and no filters (no site list of authorizations exists). Same site scope, `:operations` exposure and Admin root `:view` check as the other OAuth metrics. No migration.

## [0.11.1] - 2026-10-14

### Changed
- Allow `recording_studio_api` `>= 0.5.2, < 0.10` so hosts can run API 0.9.0.
  Development and dummy Gemfiles pin API tag `v0.9.0`.

## [0.11.0] - 2026-10-14

### Added
- `oauth_clients.self_registered_over_time` (timeseries, unit `count`): new self-registered (dynamic client registration) apps per period by `created_at`. Revoked apps still count in the period they signed up in. Takes `from` / `to` and `interval` (`day`, `week`, `month`, `year`).
- `group_by=confidential` (public vs confidential client, the Registered apps "Secret" column) and `group_by=api_key` (the named API label, the "API" column). Groups under `min_group_size` (5) fold into `other`. No grouping by name, client id or redirect URIs, and no filters (the Registered apps list has none).
- Same site scope, `:operations` exposure and Admin root `:view` check (`Api::Access.can_view?`) as the Registered apps list and the other OAuth metrics. The catalog carries `unit`, `title`, `description`, `group_by`, `min_group_size` and `date_range`.

### Changed
- Runtime dependency `recording_studio_metrics` `~> 0.3` (GitHub tag `v0.3.1`), up from `~> 0.2, >= 0.2.2`, for `group_by`.

### Upgrade notes
- Bump to `0.11.0`. No migration.
- Pin `recording_studio_metrics` to tag `v0.3.1` (`~> 0.3`).

## [0.10.5] - 2026-10-14

### Changed
- Runtime dependency `recording_studio_api` widened to `>= 0.5.2, < 0.9` so hosts can use API `0.8.0`. The development Gemfiles pin API tag `v0.8.0`.

### Notes
- Tags `v0.10.3` and `v0.10.4` were dependency-bump tags whose `VERSION` still read `0.10.2`; this change ships as `0.10.5`.

### Upgrade notes
- Bump to `0.10.5`. No migration and no configuration change.

## [0.10.2] - 2026-10-14

### Fixed
- Named-API Dynamic Client Registration. The authorization-server metadata for
  a named API (for example `/apis/operations`) advertised
  `registration_endpoint` `/recording_studio_oauth/apis/<key>/register`, but
  no route existed, so DCR clients such as ChatGPT got a 404. Oauth now routes
  `POST /apis/:api_key/register` to the existing registration controller and
  binds the new client to that `api_key`.
- `registration_endpoint` is still only advertised when
  `allow_self_registered_apps` is on. When it is off, the named-API endpoint
  returns `400 invalid_client_metadata` (same as `/register`), not a 404.
- An unknown `api_key` on the register route returns `404` with a JSON
  `invalid_request` error and creates no client.

### Upgrade notes
- Bump to `0.10.2`. No Oauth migration or host code change.

## [0.10.1] - 2026-10-13

Dependency-only release so Oauth can install with Recording Studio API `0.7`.

### Changed
- Runtime dependency `recording_studio_api` widens from `>= 0.5.2, < 0.7` to
  `>= 0.5.2, < 0.8` (GitHub tag `v0.7.0`).
- Runtime dependency `recording_studio_metrics` is now `~> 0.2, >= 0.2.2`
  (GitHub tag `v0.2.2`) so API `0.7` can resolve.

### Upgrade notes
- Bump to `0.10.1`. No Oauth migration or host code change.
- Pin Recording Studio API at tag `v0.7.0` (or any `>= 0.5.2, < 0.8`).
- Pin Metrics at tag `v0.2.2` or newer on the `0.2` line (`~> 0.2, >= 0.2.2`).

## [0.10.0] - 2026-10-13

Oauth Access grant voids and kept/trashed recording lookups go through
`RecordingStudioTrashable` query-only sibling APIs instead of raw `trashed_at`
column access.

### Changed
- `VoidOauthAuthorization` soft-voids the granted Access recording with
  `RecordingStudioTrashable.void_recording!` (same `update_columns(trashed_at:,
  updated_at:)` write as main; no cascade, capability, auth, or `trash_root`).
- Connect / authorization kept checks use `recording_studio_trashable_kept?` /
  `recording_studio_trashable_trashed?`.
- Access recording lookups add
  `where(RecordingStudio::Recording.recording_studio_trashable_kept_sql)` on the
  same base relation as main (`unscoped` for gem lookups; no `unscoped` for the
  dummy admin resolver). Not `recording_studio_trashable_active`, which
  `unscope`s `trashed_at` first and can diverge from main's additive
  `where(trashed_at: nil)`.
- Runtime dependency `recording_studio_trashable` `~> 0.10` (GitHub tag
  `v0.10.0`). Oauth loads `require "recording_studio_trashable/query"` only
  (Gemfile pins use `require: false`), so Trashable engine side effects
  (importmap/assets, `:trashable` capability, CopyHelper, trash metrics) do not
  load.

### Upgrade notes
- Bump to `0.10.0`. No Oauth migration.
- Add `recording_studio_trashable` at tag `v0.10.0` (`~> 0.10`). Prefer
  `require "recording_studio_trashable/query"` (and Gemfile `require: false`
  when Bundler would auto-require the gem) so hosts do not pull Trashable UI
  unless they mount it. Hosts that already have `trashed_at` from Recording
  Studio do not need Trashable UI migrations for these Oauth call sites.
- Nil Access recording on void still returns early (shared `void_recording!`
  would raise `ArgumentError`); behavior matches main.
- Kept lookups use additive `kept_sql`, not `recording_studio_trashable_active`.

## [0.9.0] - 2026-10-13

`/register` rate limiting uses the shared Recording Studio Cache limiter.

### Changed
- `RecordingStudioOauth::RegisterRateLimit` is a thin adapter over
  `RecordingStudioCache::RateLimiter` (`backend: :rails_cache`, `strategy: :ttl`).
  Storage keys stay `recording_studio_oauth/register/<IP>` (or `…/unknown`).
  The adapter keeps main's `limit.to_i <= 0` short-circuit (covers `nil`, blank,
  `0`, and negatives) before constructing the shared limiter, then passes
  `limit.to_i` and hardcoded `period: 1.minute` (not a config key on main).
  Store is still `RegisterRateLimit.cache` (`@cache || Rails.cache`) — there is
  no `Configuration#cache_store` — passed explicitly as `store:` (not
  `RecordingStudioCache.store`). Cache connection / IO errors still raise:
  `rescue_errors: [NeverRescued]` (v0.5.0 rejects `[]`; the private sentinel is
  never raised, so nothing is swallowed).
- Runtime dependency `recording_studio_cache` `~> 0.5` (GitHub tag `v0.5.0`).

### Notes
- Keys still expire in one minute. Main already passed `expires_in: 1.minute` on
  increment/write; the shared `:ttl` backend keeps that TTL (no new expiry).

### Upgrade notes
- Bump to `0.9.0`. No migration.
- Add `recording_studio_cache` at tag `v0.5.0`.
- No host config change. `self_registered_apps_per_minute` and `/register`
  responses stay the same for normal and disabled-limit paths.

## [0.8.0] - 2026-10-09

Site-wide OAuth metrics register with Recording Studio Metrics for the operations API.

### Added
- `RecordingStudioOauth::Metrics.register!` registers `:oauth_clients` and
  `:oauth_authorizations` (`blast_radius: :site`) with RecordingStudioMetrics.
  Clients: `oauth_clients.total` (active apps, same `OauthClient.active` count
  as the Admin Registered-apps card) and `oauth_clients.by_registration`
  (`self_registered`). Authorizations: `oauth_authorizations.over_time`
  (`created_at`) and `oauth_authorizations.by_role` on `OauthAuthorization.active`.
  Each metric is exposed on `:operations` only. `api_authorize` uses
  `RecordingStudioOauth::Api::Access.can_view?` (AdminRoot `:view`, the same
  Accessible check Admin screens use).
- Runtime dependency `recording_studio_metrics` `~> 0.2` (GitHub tag `v0.2.0`).

### Upgrade notes
- Bump to `0.8.0`. No migration.
- Add `recording_studio_metrics` at tag `v0.2.0`.
- This gem does not call `RecordingStudioMetrics::Api.register!`. The host
  registers Metrics endpoints once:

```ruby
RecordingStudioMetrics::Api.register!(api: :operations)
```

## [0.7.0] - 2026-10-08

People can translate Connect and connected-apps copy. The gem ships English only.

### Added
- Rails I18n under `recording_studio.oauth.*` for the consent screens, connected apps, and HTML error pages a person can land on. The gem ships `config/locales/en.yml` only.
- Dummy offers English and French via Recording Studio Internationalization (dummy Gemfile only). A language selector sits in the dummy top nav.

### Changed
- Dummy pins Admin `v2.0.7`, Flatpack `v0.1.209`, and Recording Studio `v4.3.0`.
- `version.rb` is `0.7.0`. Tagged `v0.6.4` and `v0.6.5` were dummy pin bumps that left `version.rb` at `0.6.3`.

### Upgrade Notes
- Install Oauth `0.7.0`. No migration.
- Copy `recording_studio.oauth.*` into host locale files for other languages.
- Arguments and config that pass copy still win over locale defaults.
- Client app names, descriptions, workspace titles, and other stored data stay untranslated.
- Role labels look up `recording_studio.oauth.roles.<name>` and fall back to humanize.
- Scope descriptions look up `recording_studio.oauth.scopes.<name>` and fall back to the existing text.
- Staff Registered-app admin, OAuth protocol error codes, and JSON `error` / `error_description` stay English.

## [0.6.5] - 2026-10-08

Tagged dummy pin bump. `version.rb` stayed `0.6.3`.

### Changed
- Dummy and development pins: Recording Studio `v4.3.0`.

## [0.6.4] - 2026-10-08

Tagged dummy pin bump. `version.rb` stayed `0.6.3`.

### Changed
- Dummy and development pins: Admin `v2.0.6`, Flatpack `v0.1.207`.

## [0.6.3] - 2026-10-07

ChatGPT ops MCP Connect can send `resource` of the named MCP URL.

### Added
- Named API registries (for example `operations`) register the MCP identifier `{mcp_mount}/apis/{api_key}` next to the existing API identifier. Public stays API + bare MCP mount + extras/origin.

### Notes
- Ops MCP clients must use `resource` of the MCP URL, such as `https://<host>/recording_studio_mcp/apis/operations`. Authorize is `/recording_studio_oauth/apis/operations/oauth/authorize`. That `resource` is no longer `invalid_target`.
- Origin path-inserted metadata at `/.well-known/oauth-protected-resource/recording_studio_mcp/apis/operations` advertises that identifier and the named authorization server.
- Public MCP still uses `https://<host>/recording_studio_mcp`. Named Connect does not accept the bare MCP mount.

## [0.6.2] - 2026-10-07

Staff can register an operations OauthClient and Connect it on staff Admin.

### Added
- `CreateOauthClient` takes `api_key` so a Registered App can bind to a named API such as `operations`. Public stays the default. `api_key` is the named API label, not a secret.
- Connect lists staff AdminRoot for operations apps. Public apps still skip it. Grant on AdminRoot is rejected for a public app.

### Notes
- Hosts that define `config.api :operations` can pick Operations on New app. Connect that app at `/recording_studio_oauth/apis/operations/oauth/authorize`.

## [0.6.0] - 2026-10-05

MCP Inspector and other standards MCP clients can discover this authorization server from the MCP URL and register themselves. Staff do not paste a client id. Connecting still needs a person.

### Added
- RFC 8414 path-inserted metadata at `/.well-known/oauth-authorization-server{mount}` via `ProtectedResourceRegistry.draw_origin_well_known`. `issuer` is the mount URL. Existing metadata URLs still work. OpenID Connect discovery stays 404.
- RFC 7591 Dynamic Client Registration at `{mount}/register`, advertised as `registration_endpoint` when enabled. Self-registered apps are public with PKCE S256 unless they ask for a secret. Redirect URIs must be https, or http on localhost, 127.0.0.1, or `[::1]`. Registration is rate-limited per IP. Staff see those apps in Registered apps and can revoke them.

### Changed
- Dummy turns self-registered apps on so the local MCP flow works.
- Re-consent for the same app keeps live access and refresh tokens. Refresh-token reuse voids the grant only when that token was rotated (`replaced_by_id`). A refresh token revoked any other way returns `invalid_grant` and leaves the grant standing.

### Notes
- Self-registered apps are off for hosts. Set `config.allow_self_registered_apps = true` to allow them. `config.allow_registration` is still the starting value for signup on a new app, not this switch.
- MCP 2025-11-25 prefers Client ID Metadata Documents. This release ships DCR, which Inspector v2.9.0 and the 2025-06-18 spec use. CIMD is not implemented.
- Registration grants no access. People still Connect.

## [0.5.6] - 2026-10-05

Hosts can use Recording Studio API 0.6. Connect and token exchange stay the same.

### Changed
- Recording Studio API is now `>= 0.5.2, < 0.7`. Dummy and development pin `v0.6.0`.

### Notes
- API 0.6 adds an optional `progress_reporter` on handler contexts. REST still leaves it `nil`. This gem does not use that field.

## [0.5.5] - 2026-10-05

Development and dummy pins climb Recording Studio addons to current layer 0–2 tags.

### Changed
- Gemspec Accessible constraint is `~> 0.11` so hosts match Accessible 0.11 string roles.
- Dummy and development pins: Accessible `v0.11.1`, Admin `v2.0.4`, Attachable `v0.7.1`, Site Settings `v0.1.3`. Dummy also pins Root Switchable `v0.5.3`.
- Dummy Accessible schema stores access roles as strings and adds access invitations. Attachable dummy schema adds presentation fields and `root_recording_id`.
- Dummy grants go through Accessible services. API 0.5.2 still gets a dummy-only `Access.roles` map so it can authorize.
- Recording Studio stays on `v4.2.2`. API stays on `v0.5.2`. Flatpack stays on `v0.1.144`.

## [0.5.3] - 2026-09-24

Channel hosts can prove a session JWT and map that install to a workspace without channel columns on users or workspaces.

### Added
- `RecordingStudioOauth.verify_session_token` checks HS256 with the Registered App signing secret and Who the token is for (`aud`). It also checks `exp` and `nbf`. It returns the raw claims. The host interprets channel claims.
- `recording_studio_oauth_external_installs` maps `provider` + `external_id` + Registered App to an optional root recording and `connected_by`. `RecordingStudioOauth.record_external_install` upserts that row.
- Registered App create and edit take a Token verification checkbox. Channel, Who the token is for, and Session token secret show only when it is on.

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

[0.10.1]: https://github.com/bowerbird-app/RecordingStudio_Oauth/compare/v0.10.0...v0.10.1
[0.10.0]: https://github.com/bowerbird-app/RecordingStudio_Oauth/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/bowerbird-app/RecordingStudio_Oauth/compare/v0.8.2...v0.9.0
[0.8.0]: https://github.com/bowerbird-app/RecordingStudio_Oauth/compare/v0.7.2...v0.8.0
[0.7.0]: https://github.com/bowerbird-app/RecordingStudio_Oauth/compare/v0.6.4...v0.7.0
[0.6.4]: https://github.com/bowerbird-app/RecordingStudio_Oauth/compare/v0.6.3...v0.6.4
[0.6.3]: https://github.com/bowerbird-app/RecordingStudio_Oauth/compare/v0.6.2...v0.6.3
[0.6.2]: https://github.com/bowerbird-app/RecordingStudio_Oauth/compare/v0.6.1...v0.6.2
[0.6.0]: https://github.com/bowerbird-app/RecordingStudio_Oauth/compare/v0.5.6...v0.6.0
[0.5.6]: https://github.com/bowerbird-app/RecordingStudio_Oauth/compare/v0.5.5...v0.5.6
[0.5.5]: https://github.com/bowerbird-app/RecordingStudio_Oauth/compare/v0.5.4...v0.5.5
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
