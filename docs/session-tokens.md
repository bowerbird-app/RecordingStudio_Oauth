# How to verify a session token and map an install

Use this when a channel host needs to prove a session JWT is genuine, then map that install to a Recording Studio workspace. A Shopify Admin iframe is one host. This gem does not interpret channel claims.

This gem does not run a channel plugin, and it does not finish merchant Connect. Installed is not Connected.

## Two client ids

Keep these distinct.

- **Who the token is for.** The channel's own app id. It is the JWT `aud`. Staff paste it on the Registered App as Who the token is for. A Shopify host uses the Partner app client id here.
- **Registered App id.** `rsoauth_oc_…`. Merchants use this for Connect login only. It is not the session token audience.

## What staff set on the Registered App

On create or edit, turn on **Token verification**. Leave it off if this app does not check session tokens. When it is on, staff set:

- **Channel.** A short label stored on the install row.
- **Who the token is for.** The channel app id (`aud`).
- **Session token secret.** The channel signing secret. This is not the Connect secret the form shows once. Leave the field blank on edit to keep the stored secret.

Turning Token verification off clears Channel, Who the token is for, and the stored session token secret. The checkbox itself is not a database column. Edit checks it when any of those three is already stored.

The Connect secret stays a digest. HMAC needs the real signing secret, so this gem stores the session token secret encrypted with `secret_key_base`.

## Verify

Oauth checks HS256, audience, `exp`, and `nbf`. It returns the raw claims hash. The host reads claims (for example `dest` and `iss` on a Shopify Admin iframe) and picks `external_id`.

```ruby
result = RecordingStudioOauth.verify_session_token(
  client_id: params[:client_id],
  token: params[:session_token]
)

if result.success?
  claims = result.value.fetch(:claims)
  client = result.value.fetch(:client)
else
  result.error
  result.errors
end
```

You may pass `client:` instead of `client_id:`. You may pass `secret:` to use a host ENV secret instead of the stored one.

Optional string equality, with no claim parsing. The host computes both sides:

```ruby
RecordingStudioOauth.verify_session_token(
  client: client,
  token: session_token,
  external_id: host_computed_id,
  expected_external_id: params[:shop]
)
```

The verifier is HS256 only. It does not fetch JWKS. It does not branch on Channel. It does not read `iss` or `dest`.

What Oauth checks:

- `alg` is `HS256`
- signature matches the session token secret
- `aud` matches Who the token is for
- `exp` is in the future (10 second leeway)
- `nbf` is in the past (10 second leeway)

Failure messages are `unknown client`, `client is revoked`, `session token verify is not configured`, `invalid token`, `bad signature`, `wrong audience`, `expired`, `not yet valid`, and `external id does not match`.

## Record the install

After a successful verify, the host upserts the mapping with the ids it computed. The row can exist before anyone Connects.

```ruby
RecordingStudioOauth.record_external_install(
  client: client,
  provider: "channel",
  external_id: host_computed_id
)
```

`provider` can fall back to the Registered App Channel field. Unique key is `(oauth_client_id, provider, external_id)`. The same external id on two Registered Apps is two rows.

## Installed is not Connected

An install row without `root_recording_id` is installed only. A first verified token can create it.

Connect still belongs to the host. When the merchant finishes Connect, bind the workspace:

```ruby
RecordingStudioOauth.record_external_install(
  client: client,
  provider: "channel",
  external_id: host_computed_id,
  root_recording: RecordingStudio.root_recording_for(workspace),
  connected_by: current_user
)
```

`connected_by` stays null until that bind. A later upsert that omits `root_recording` does not clear a bound workspace.

Do not put channel columns on users or workspaces. Do not reuse `recording_studio_user_identities`. That table is login identity only.

## Schema

`recording_studio_oauth_external_installs`:

- `oauth_client_id`
- `provider`
- `external_id`
- `root_recording_id` (optional)
- `connected_by_type` / `connected_by_id` (optional)

The workspace is `install.root_recording.recordable` when Connect has bound a root. Root Switchable can later point `root_recording_id` at a different root.

## Host follow-up

This gem does not change a channel plugin template. After you tag this version, a Shopify Admin iframe host still needs to:

1. Create a Registered App for merchant Connect (`rsoauth_oc_…`).
2. Turn on Token verification. Set Channel, Who the token is for, and Session token secret from the Partner app.
3. On iframe load, call `verify_session_token` with the App Bridge session token.
4. Read claims in the host. Check `iss` and `dest` there. Choose `external_id`.
5. Upsert `ExternalInstall` with `provider` and that id.
6. Send the merchant through this gem's Connect, then bind `root_recording` and `connected_by`.
