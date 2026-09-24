# How to verify a session token and map an install

Use this when a channel host (Shopify Admin iframe first) needs to prove that an external install is real, then point it at a Recording Studio workspace.

This gem does not run the Shopify plugin, and it does not finish merchant Connect. Installed is not Connected.

## Two client ids

Keep these distinct.

- **Who the token is for.** The channel's own app id. For Shopify this is the Partner app client id. It is the JWT `aud`. Staff paste it on the Registered App as Who the token is for.
- **Registered App id.** `rsoauth_oc_…`. Merchants use this for Connect login only. It is not the session token audience.

## What staff set on the Registered App

On create or edit:

- **Channel.** `shopify` for Shopify Admin. Leave blank if this app does not check session tokens.
- **Who the token is for.** The channel app id (`aud`).
- **Session token secret.** The channel signing secret (Shopify API secret). This is not the Connect secret the form shows once. Leave the field blank on edit to keep the stored secret.

The Connect secret stays a digest. HMAC needs the real signing secret, so this gem stores the session token secret encrypted with `secret_key_base`.

## Verify

```ruby
result = RecordingStudioOauth.verify_session_token(
  client_id: params[:client_id],
  token: params[:session_token],
  expected_external_id: params[:shop]
)

if result.success?
  result.value.fetch(:external_id)
  result.value.fetch(:claims)
  result.value.fetch(:client)
else
  result.error
  result.errors
end
```

You may pass `client:` instead of `client_id:`. You may pass `secret:` to use a host ENV secret instead of the stored one.

The verifier is HS256 only. It does not fetch JWKS.

For Channel `shopify` it follows Shopify's ID token (session token) checks:

- `alg` is `HS256`
- signature matches the session token secret
- `aud` matches Who the token is for
- `exp` is in the future (10 second leeway)
- `nbf` is in the past (10 second leeway)
- `iss` and `dest` hostnames match
- `external_id` is the `dest` host

Failure messages are `unknown client`, `client is revoked`, `session token verify is not configured`, `invalid token`, `bad signature`, `wrong audience`, `expired`, `not yet valid`, `issuer and destination do not match`, and `shop does not match`.

## Record the install

After a successful verify, upsert the mapping. The row can exist before anyone Connects.

```ruby
RecordingStudioOauth.record_external_install(
  client: result.value.fetch(:client),
  external_id: result.value.fetch(:external_id)
)
```

Unique key is `(oauth_client_id, provider, external_id)`. The same shop on two Registered Apps is two rows.

## Installed is not Connected

An install row without `root_recording_id` is installed only. Partner install or the first verified token can create it.

Connect still belongs to the host. When the merchant finishes Connect, bind the workspace:

```ruby
RecordingStudioOauth.record_external_install(
  client: client,
  external_id: "exampleshop.myshopify.com",
  root_recording: RecordingStudio.root_recording_for(workspace),
  connected_by: current_user
)
```

`connected_by` stays null until that bind. A later upsert that omits `root_recording` does not clear a bound workspace.

Do not put `shopify_*` columns on users or workspaces. Do not reuse `recording_studio_user_identities`. That table is login identity only.

## Schema

`recording_studio_oauth_external_installs`:

- `oauth_client_id`
- `provider`
- `external_id`
- `root_recording_id` (optional)
- `connected_by_type` / `connected_by_id` (optional)

The workspace is `install.root_recording.recordable` when Connect has bound a root. Root Switchable can later point `root_recording_id` at a different root.

## Host follow-up (Shopify)

This gem does not change the Shopify plugin template. After you tag this version, the host still needs to:

1. Create a confidential or public Registered App for merchant Connect (`rsoauth_oc_…`).
2. Set Channel, Who the token is for, and Session token secret from the Partner app.
3. On iframe load, call `verify_session_token` with the App Bridge session token.
4. Upsert `ExternalInstall`.
5. Send the merchant through this gem's Connect with the Registered App id, then bind `root_recording` and `connected_by`.
6. Stop using a host-only `shopify_plugin_demo_connections` table once that bind works.
