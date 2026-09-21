# How to mount the WordPress Connect relay

Use this when a Recording Studio host should be the one Registered App for many WordPress sites.

Self-hosted WordPress-to-WordPress OAuth is out of scope. The WordPress Settings UI and ZIP client id live in RecordingStudio_wordpress_plugin_template.

## What the host registers

Register one public app. One name is enough. Dummy uses `WordPress`.

Set exactly one redirect URI, the relay on this host:

```ruby
RecordingStudioOauth.wordpress_relay_callback_url(base_url: "https://app.example.com")
# => "https://app.example.com/recording_studio_oauth/wordpress/callback"
```

Do not add each WordPress origin as a redirect URI. People do not paste a client id or a redirect on the WordPress site.

If you set `RecordingStudioOauth.configuration.public_origin`, start uses that origin to build the relay URI. The Registered App redirect must match that string exactly.

## Paths on the Oauth mount

The engine default mount is `/recording_studio_oauth`. These paths sit under that mount.

| Step | Method | Path |
| --- | --- | --- |
| Start Connect | `GET` | `/recording_studio_oauth/wordpress/connect` |
| Relay callback | `GET` | `/recording_studio_oauth/wordpress/callback` |
| Authorize | `GET` / `POST` | `/recording_studio_oauth/oauth/authorize` |
| Token | `POST` | `/recording_studio_api/oauth/token` |

A named API token URL such as `/recording_studio_api/apis/wp_plugin_demo/oauth/token` still works for a public app. Authorize and the relay stay on the Oauth mount above.

## Start query

WordPress sends the person here. The plugin generates PKCE and a CSRF `state` on that site. The verifier never leaves WordPress.

| Parameter | Required | Meaning |
| --- | --- | --- |
| `client_id` | yes | The one WordPress Registered App. Unknown or revoked ids are rejected. |
| `return_to` | yes | That site's admin-post callback. See the allowlist below. |
| `code_challenge` | yes | S256 challenge from the WordPress site. |
| `code_challenge_method` | yes | `S256` |
| `state` | no | WordPress CSRF. The relay returns it unchanged. |
| `response_type` | no | Must be `code` when present. |
| `resource` | no | Passed through to authorize. |

Do not send `redirect_uri`. Start sets it to the relay callback.

Example:

```text
https://app.example.com/recording_studio_oauth/wordpress/connect?client_id=rsoauth_id_…&return_to=https%3A%2F%2Fblog.example.com%2Fwp-admin%2Fadmin-post.php%3Faction%3Drecording_studio_oauth_callback&state=…&code_challenge=…&code_challenge_method=S256
```

## Allowed `return_to`

The relay accepts only this shape:

```text
https://<host>[:port]/[subdirectory/]wp-admin/admin-post.php?action=recording_studio_oauth_callback
```

`http` is allowed for local WordPress, such as `http://localhost:8888/…`.

Rejected:

- any other host path or action
- extra query keys
- userinfo, fragments, relative URLs
- a `return_to` query on the relay callback itself

## Token exchange

WordPress posts the authorization code to the API token URL with:

- `grant_type=authorization_code`
- `client_id` of the shared app
- `code` from the relay
- `redirect_uri` equal to the relay callback, not the WordPress admin-post URL
- `code_verifier` from the WordPress session

The relay does not store the code. Reuse still voids the grant, as with any other Connect code.

## Dummy

`test/dummy` seeds a public `WordPress` app whose redirect is `http://localhost:3000/recording_studio_oauth/wordpress/callback`. Integration tests use `http://www.example.com/recording_studio_oauth/wordpress/callback` on the Rails test host.
