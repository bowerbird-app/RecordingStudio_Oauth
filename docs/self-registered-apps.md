# Self-registered apps

MCP Inspector and other MCP clients can create an OauthClient without staff pasting a client id. That is RFC 7591 Dynamic Client Registration at:

```text
POST /recording_studio_oauth/register
```

The mount is `config.engine_mount_path`. Dummy uses `/recording_studio_oauth`.

## Host switch

Off by default. Dummy turns it on.

```ruby
RecordingStudioOauth.configure do |config|
  config.allow_self_registered_apps = true
end
```

`config.allow_registration` is a different switch. It is the starting signup flag on a new Registered App. It does not turn `/register` on.

When self-registered apps are on, RFC 8414 metadata includes `registration_endpoint`. When they are off, that field is omitted and `POST /register` returns `invalid_client_metadata`.

## What a client gets

A successful body has `client_id`, `client_id_issued_at`, and the registered metadata. Public is the default (`token_endpoint_auth_method` `none`). `client_secret_basic` and `client_secret_post` return a secret once, with `client_secret_expires_at` `0`.

Redirect URIs must be https, or http on localhost, 127.0.0.1, or `[::1]`. Fragments and wildcard hosts are rejected. Errors use RFC 7591 shapes: `invalid_redirect_uri` and `invalid_client_metadata`.

`/register` is limited per IP by `config.self_registered_apps_per_minute` (default 10). `0` turns the limit off.

## Access

Registration does not Connect. People still see the usual Connect screens. Staff see the app in Registered apps as Self-registered and can revoke it.

## Discovery

Serve RFC 8414 path insertion from the host helper you already draw:

```ruby
RecordingStudioOauth::ProtectedResourceRegistry.draw_origin_well_known(self)
```

That includes `/.well-known/oauth-authorization-server/recording_studio_oauth`. `issuer` is the mount URL. OpenID Connect discovery stays 404.

MCP 2025-11-25 prefers Client ID Metadata Documents. This gem ships DCR because Inspector v2.9.0 and MCP 2025-06-18 use it. CIMD is not implemented.
