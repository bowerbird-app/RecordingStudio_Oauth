# Recording Studio OAuth

This gem is the **authorization server**. Third-party apps register once. People Connect. The app gets its own access, not yours.

[Recording Studio API](https://github.com/bowerbird-app/RecordingStudio_api) is the **resource server**. Token URL stays `/recording_studio_api/oauth/token`. Machine API keys stay there too. This gem does not fork a second token endpoint.

It is not Users. It is not Doorkeeper. It is not Dynamic Client Registration. It is not OIDC or SAML. It is not OAuth scopes. The app does not act as the person.

## What you get

**OauthClient** is a registry row: name, client id, redirect URIs, public or confidential, named API, revoked. It is not a recordable and not a child of Access.

**OauthAuthorization** is an Accessible actor. Connect grants Access on the parent of the Access the person clicked, `depends_on:` that Access. The app's Access is a sibling of theirs. Same app and same node reconnects. Asking for more than they have, or a missing Access, rejects. Nothing is silently clamped.

Public clients must use PKCE S256. Refresh tokens rotate. Reusing an authorization code voids the grant.

RFC 8414 discovery lives here. `authorization_endpoint` is this engine. `token_endpoint` and `revocation_endpoint` point at the API mount.

## Connect

Two screens, Flatpack, default layout, `data-theme="rounded"`.

1. A list in a card. Each row is a workspace or folder the person can already use. Trailing copy is Connect, Connected, or Reconnect. Staff AdminRoot is not a row. The list is flat, not a tree.
2. Permission, capped at theirs. View is the default. If they only have View, the picker is hidden. Continue and Cancel are separate buttons. Cancel is `access_denied`.

People can see and remove connected apps. Staff can revoke a registered app.

## Install

1. Add the gem and pin Recording Studio `~> 4.2`, Accessible `~> 0.9`, Admin `~> 2.0`, API `~> 0.5.2`, Flatpack `~> 0.1.143`.
2. Run `bin/rails generate recording_studio_oauth:install`.
3. Run `bin/rails generate recording_studio_oauth:migrations` and migrate.
4. Allow `RecordingStudioOauth::OauthAuthorization` in Accessible `access_actor_types`.
5. Enable `:accessible` on the recordables people Connect from, including Folder if folder grants should appear.
6. Host authentication stays on the host. Dummy uses Devise. Do not add Users as a dependency of this gem.
7. If you mount staff admin, pin Turbo and Recording Studio Admin's screen controllers in the host importmap (see `test/dummy/config/importmap.rb`).

Boot registers `authorization_code` and `refresh_token` with `RecordingStudioApi.register_oauth_grant`. That hook is required. Token exchange uses the API engine's existing `/oauth/token`. `client_credentials` stays built into API. Do not copy Connect into the API gem.

## Dummy

`test/dummy` on port 3000. Sign in with `admin@admin.com` / `Password`. Seed Demo App is registered. Studio Workspace starts Connected, Docs Workspace starts as Reconnect, Product Docs is Connect, Admin is staff-only. Dummy Tailwind imports resolved engine paths from `gem_sources.css` before each build so Flatpack classes are not missed when gems sit under `/usr/local/lib/ruby/gems`.

## Version

0.1.0
