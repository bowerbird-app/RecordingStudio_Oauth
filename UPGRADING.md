# Upgrading

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
