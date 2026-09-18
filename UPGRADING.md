# Upgrading

## 0.2.2

No host code change. A public app created in Registered Apps (`api_key` defaults to `public`) can exchange an authorization code, and refresh the issued tokens, on a named API token URL such as `/recording_studio_api/apis/wp_plugin_demo/oauth/token`. Confidential clients still have to match that API. Do not seed `api_key=wp_plugin_demo` to make Connect work.

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
