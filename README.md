# Recording Studio OAuth

This gem is the **authorization server**. Third-party apps register once. People Connect. The app gets its own access, not yours.

[Recording Studio API](https://github.com/bowerbird-app/RecordingStudio_api) is the **resource server**. Token URL stays `/recording_studio_api/oauth/token`. Machine API keys stay there too. This gem does not fork a second token endpoint.

It is not Users. It is not Doorkeeper. It is not Dynamic Client Registration. It is not OIDC or SAML. It is not OAuth scopes. The app does not act as the person.

## What you get

**OauthClient** is a registry row: name, client id, redirect URIs, public or confidential, named API, revoked. It is not a recordable and not a child of Access.

**OauthAuthorization** is an Accessible actor. Connect grants Access on the parent of the Access the person clicked, `depends_on:` that Access. The app's Access is a sibling of theirs. Same app and same node reconnects. Asking for more than they have, or a missing Access, rejects. Nothing is silently clamped.

Public clients must use PKCE S256. Refresh tokens rotate. Reusing an authorization code or a rotated refresh token voids the grant. Disconnect and reconnect drop unused codes so they cannot void a later grant.

RFC 8414 discovery lives here. `authorization_endpoint` is this engine. `token_endpoint` and `revocation_endpoint` point at the API mount.

## Protected resources

This gem is one authorization server. It advertises more than one protected-resource identity. Tokens stay opaque `rsoauth_at_` bearers with no audience.

| Kind | Identifier | Origin well-known |
| --- | --- | --- |
| API | `https://app.example.com/recording_studio_api/api` | `/.well-known/oauth-protected-resource/recording_studio_api/api` |
| MCP | `https://app.example.com/recording_studio_mcp` | `/.well-known/oauth-protected-resource/recording_studio_mcp` |

The engine URL `/recording_studio_oauth/.well-known/oauth-protected-resource` still serves the API identifier. Origin unsuffixed `/.well-known/oauth-protected-resource` is 404 unless you set `register_origin_as_protected_resource = true`.

Draw origin path-inserted well-known in the host:

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

A present `resource` on authorize or token must match a registry entry. Unknown values return `invalid_target`. Omit the parameter as before. The value is not stored.

## Connect

Two screens, Flatpack, `data-theme="rounded"`. Connect uses a login-style frame: viewport-centered, `max-w-sm`. The access list has no back control. Permission and error keep PageNav back. Connected apps and staff admin stay on core default layout.

The list title is `{app} wants to connect to {site}`. The app name is the registered OauthClient. The site name comes from Recording Studio Site Settings (`name_for`). If there is no site name, the title stops at `{app} wants to connect`. Several workspaces that share one site name keep that sentence. Different site names put each `name_for` on the row instead.

1. A list in a card with default padding. Each row is a workspace or folder the person can already use. Trailing Flatpack buttons are Connect (default), Connected (success), or Reconnect (danger). Reconnect has a tooltip: "This connection is no longer live." Staff AdminRoot is not a row. The list is flat, not a tree.
2. `{picked parent} permissions`. Role picker when they have more than View, with no field label or help. Connect and Cancel are separate buttons. Cancel is `access_denied`. Those two submit with `data-turbo="false"` so an off-host `redirect_uri` is a full page navigation. Workspace list GET links stay on Turbo.

People can see and remove connected apps. Staff can register an app from Admin, copy the client id (and secret once), and revoke it. Registered apps shows Secret and Status as badges. Hover or focus explains Public versus Has a secret. Active and Revoked need no extra line.

## Install

1. Add the gem and pin Recording Studio `~> 4.2`, Accessible `~> 0.9`, Admin `~> 2.0`, API `~> 0.5.2`, Site Settings `~> 0.1`, Flatpack `~> 0.1.144`.
2. Run `bin/rails generate recording_studio_oauth:install`.
3. Run `bin/rails generate recording_studio_oauth:migrations` and migrate.
4. Allow `RecordingStudioOauth::OauthAuthorization` in Accessible `access_actor_types`.
5. Enable `:accessible` on the recordables people Connect from, including Folder if folder grants should appear.
6. Host authentication stays on the host. Dummy uses Devise. Do not add Users as a dependency of this gem.
7. Install Recording Studio Site Settings (and Attachable, which that gem needs). Register `RecordingStudioSiteSettings::SiteSetting` and `RecordingStudioAttachable::Attachment`. Set `site_root_types` so Connect can read a site name.
8. If you mount staff admin, pin Turbo and Recording Studio Admin's screen controllers in the host importmap (see `test/dummy/config/importmap.rb`).

Boot registers `authorization_code` and `refresh_token` with `RecordingStudioApi.register_oauth_grant`. That hook is required. Boot also registers `RecordingStudioOauth::TokenAuthenticator` so `rsoauth_at_` tokens authenticate on the API resource server. Token exchange uses the API engine's existing `/oauth/token`, including a named path such as `/apis/wp_plugin_demo/oauth/token`. A public Registered App (`api_key=public`) can complete `authorization_code` and `refresh_token` on that named path. The minted bearer still authenticates on the public API. Recording Studio API still requires `api_client.api_key` to match a named resource path. Confidential clients still have to match the request API. `client_credentials` stays built into API. Do not copy Connect into the API gem.

## Dummy

`test/dummy` on port 3000. Sign in with `admin@admin.com` / `Password`. Seed Demo App is registered. Studio Workspace starts Connected (success), Docs Workspace starts as Reconnect (danger), Product Docs is Connect (default), Admin is staff-only. Switch to Admin, then Registered apps can add an app, show credentials once, and revoke. Both Studio Workspace and Docs Workspace seed site name `Studio` through Site Settings. Dummy Tailwind imports resolved engine paths from `gem_sources.css` before each build so Flatpack classes are not missed when gems sit under `/usr/local/lib/ruby/gems`.

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

## Version

0.5.2
