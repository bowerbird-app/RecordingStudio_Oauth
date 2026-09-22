# How to use the central Connect relay

Use this when one Recording Studio host should be the fixed OAuth redirect for many return addresses. Each Registered App opts in and lists the addresses it may return to.

The WordPress plugin still calls the old `/wordpress/` paths until its own update. This gem does not ship that plugin change.

## What staff set on the Registered App

Turn on **Use central relay**.

Set the app redirect URI to this host's fixed callback:

```ruby
RecordingStudioOauth.central_relay_callback_url(base_url: "https://app.example.com")
# => "https://app.example.com/recording_studio_oauth/callback"
```

Add at least one return rule.

- **Allowed return patterns.** One pattern per line. `*` matches any text. It is not a regular expression. The pattern has to match the whole `return_to`.
- **Exact return URLs.** One full URL per line.

A `return_to` is accepted when it matches any pattern or any exact URL. Anything else is rejected.

For a WordPress site, a working pattern is:

```text
https://*/wp-admin/admin-post.php?action=recording_studio_oauth_callback
```

That pattern also matches a subdirectory install, because `*` can include path text before `wp-admin`. A tighter pattern that stops at the host is not what `*` does. `*` matches any text.

Do not add each return address as a redirect URI. The redirect URI is the fixed callback. People do not paste a client id on the client site for this flow.

If you set `RecordingStudioOauth.configuration.public_origin`, start builds the callback from that origin. The Registered App redirect must match that string exactly.

Apps with Use central relay off keep their normal redirect URI list. They cannot start `/connect`, and a code sent to `/callback` is not forwarded.

## Paths on the Oauth mount

The engine default mount is `/recording_studio_oauth`.

| Step | Method | Path |
| --- | --- | --- |
| Start Connect | `GET` | `/recording_studio_oauth/connect` |
| Relay callback | `GET` | `/recording_studio_oauth/callback` |
| Authorize | `GET` / `POST` | `/recording_studio_oauth/oauth/authorize` |
| Token | `POST` | `/recording_studio_api/oauth/token` |

A named API token URL such as `/recording_studio_api/apis/wp_plugin_demo/oauth/token` still works for a public app. Authorize and the relay stay on the Oauth mount above.

`/recording_studio_oauth/wordpress/connect` and `/recording_studio_oauth/wordpress/callback` are not routed.

## Start query

The client sends the person here. It generates PKCE and its own CSRF `state`. The verifier never reaches this gem.

| Parameter | Required | Meaning |
| --- | --- | --- |
| `client_id` | yes | The Registered App. Unknown or revoked ids are rejected. |
| `return_to` | yes | Where to send the browser after Approve. Must match that app's rules. |
| `code_challenge` | yes | S256 challenge. |
| `code_challenge_method` | yes | `S256` |
| `state` | no | Client CSRF. The relay returns it unchanged. |
| `response_type` | no | Must be `code` when present. |
| `resource` | no | Passed through to authorize. |

Do not send `redirect_uri`. Start sets it to the fixed callback.

Example:

```text
https://app.example.com/recording_studio_oauth/connect?client_id=rsoauth_oc_…&return_to=https%3A%2F%2Fblog.example.com%2Fwp-admin%2Fadmin-post.php%3Faction%3Drecording_studio_oauth_callback&state=…&code_challenge=…&code_challenge_method=S256
```

## What `return_to` must be

The address has to be an absolute `http` or `https` URL with a host. Userinfo, fragments, and relative URLs are rejected even when a pattern would otherwise match.

A query `return_to` on `/callback` is ignored. The signed `state` from start is the only return address.

## Token exchange

The client posts the authorization code to the API token URL with:

- `grant_type=authorization_code`
- `client_id` of that app
- `code` from the relay
- `redirect_uri` equal to the fixed callback, not the client's return address
- `code_verifier` from the client session

The relay does not store the code. Reuse still voids the grant, as with any other Connect code.

## Dummy

`test/dummy` seeds a public `WordPress` app with Use central relay on. Its redirect is `http://localhost:3000/recording_studio_oauth/callback`, and its pattern is the WordPress admin-post example above. Integration tests use `http://www.example.com/recording_studio_oauth/callback` on the Rails test host.
