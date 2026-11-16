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

- **Allowed return patterns.** One pattern per line. The address is matched after it is parsed. Scheme, host, port, path, and query each have to match. A default port (`443` for https, `80` for http) matches an omitted port.
- **Exact return URLs.** One full URL per line. The string has to match exactly.

A star is allowed in two host shapes only.

- `https://*/wp-admin/admin-post.php?action=recording_studio_oauth_callback` matches any ordinary host. The admin form warns when a saved pattern uses this shape. IP addresses do not match.
- `https://*.example.com/callback` matches one label in front of a host that already has at least two labels. `blog.example.com` matches. `a.b.example.com` does not. `*.com` is rejected.

A star in the path or the query does not match. `https://shop.example.com/cb` does not match `http://shop.example.com/cb`. A host with a trailing dot, a `%` in the host, a username, or a fragment does not match.

A `return_to` is accepted when it matches any pattern or any exact URL. Anything else is rejected.

For a WordPress site on a host you do not know in advance, use:

```text
https://*/wp-admin/admin-post.php?action=recording_studio_oauth_callback
```

The path and query stay exact, so a subdirectory install such as `/blog/wp-admin/admin-post.php` needs its own pattern. For sites under one domain, prefer `https://*.example.com/wp-admin/admin-post.php?action=recording_studio_oauth_callback`.

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

The address has to be an absolute `http` or `https` URL with a host. Userinfo, fragments, a trailing dot on the host, a `%` in the host, and relative URLs are rejected even when a pattern would otherwise match. The consent screen shows that host. Connect is hidden when the return does not match the app's current rules.

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

`test/dummy` seeds a public `WordPress` app with Use central relay on. Its redirect is `http://localhost:3000/recording_studio_oauth/callback`, and its pattern is the any-host WordPress admin-post example above. The admin edit screen warns on that pattern. Screenshots of that warning and of the consent screen are in `docs/images/`. Integration tests use `https://www.example.com/recording_studio_oauth/callback` on the Rails test host.
