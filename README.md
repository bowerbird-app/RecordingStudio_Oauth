# Recording Studio OAuth

This gem is the **authorization server**. Third-party apps register once. People Connect. The app gets its own access, not yours.

[Recording Studio API](https://github.com/bowerbird-app/RecordingStudio_api) is the **resource server**. Token URL stays `/recording_studio_api/oauth/token`. Machine API keys stay there too. This gem does not fork a second token endpoint.

It is not Users. It is not Doorkeeper. It is not Dynamic Client Registration. It is not OIDC or SAML. It is not OAuth scopes. The app does not act as the person.

## What you get

**OauthClient** is a registry row: name, client id, redirect URIs, public or confidential, named API, revoked. It is not a recordable and not a child of Access.

**OauthAuthorization** is an Accessible actor. Connect grants Access on the parent of the Access the person clicked, `depends_on:` that Access. The app's Access is a sibling of theirs. Same app and same node reconnects. Asking for more than they have, or a missing Access, rejects. Nothing is silently clamped.

Public clients must use PKCE S256. Refresh tokens rotate. Reusing an authorization code or a rotated refresh token voids the grant. Disconnect and reconnect drop unused codes so they cannot void a later grant.

RFC 8414 discovery lives here. `authorization_endpoint` is this engine. `token_endpoint` and `revocation_endpoint` point at the API mount.

## Connect

Two screens, Flatpack, `data-theme="rounded"`. Connect uses a login-style frame: viewport-centered, `max-w-sm`. The access list has no back control. Permission and error keep PageNav back. Connected apps and staff admin stay on core default layout.

The list title is `{app} wants to connect to {site}`. The app name is the registered OauthClient. The site name comes from Recording Studio Site Settings (`name_for`). If there is no site name, the title stops at `{app} wants to connect`. Several workspaces that share one site name keep that sentence. Different site names put each `name_for` on the row instead.

1. A list in a card with default padding. Each row is a workspace or folder the person can already use. Trailing Flatpack buttons are Connect (default), Connected (success), or Reconnect (danger). Reconnect has a tooltip: "This connection is no longer live." Staff AdminRoot is not a row. The list is flat, not a tree.
2. `{picked parent} permissions`. Role picker when they have more than View, with no field label or help. Connect and Cancel are separate buttons. Cancel is `access_denied`.

People can see and remove connected apps. Staff can register an app from Admin, copy the client id (and secret once), and revoke it. Registered apps shows Secret and Status as badges. Hover or focus explains Public versus Has a secret. Active and Revoked need no extra line.

## Install

1. Add the gem and pin Recording Studio `~> 4.2`, Accessible `~> 0.9`, Admin `~> 2.0`, API `~> 0.5.2`, Site Settings `~> 0.1`, Flatpack `~> 0.1.144`.
2. Run `bin/rails generate recording_studio_oauth:install`.
3. Run `bin/rails generate recording_studio_oauth:migrations` and migrate.
4. Allow `RecordingStudioOauth::OauthAuthorization` in Accessible `access_actor_types`.
5. Enable `:accessible` on the recordables people Connect from, including Folder if folder grants should appear.
6. Host authentication stays on the host. Do not add Users as a dependency of this gem. Dummy mounts Recording Studio Users for email-first sign-in (preferred path → password) and Continue-with social on the way into Connect.
7. Install Recording Studio Site Settings (and Attachable, which that gem needs). Register `RecordingStudioSiteSettings::SiteSetting` and `RecordingStudioAttachable::Attachment`. Set `site_root_types` so Connect can read a site name.
8. If you mount staff admin, pin Turbo and Recording Studio Admin's screen controllers in the host importmap (see `test/dummy/config/importmap.rb`).

Boot registers `authorization_code` and `refresh_token` with `RecordingStudioApi.register_oauth_grant`. That hook is required. Boot also registers `RecordingStudioOauth::TokenAuthenticator` so `rsoauth_at_` tokens authenticate on the API resource server. Token exchange uses the API engine's existing `/oauth/token`. `client_credentials` stays built into API. Do not copy Connect into the API gem.

## Dummy

`test/dummy` on port 3000. Sign in with `admin@admin.com` / `Password`. Login is Users email-first: screen 1 is email plus Continue with Google (local fake OmniAuth client), screen 2 is password (`primary_login_type` `:email`). Unauthenticated Connect stores the authorize URL and returns after sign-in.

Seed Demo App is registered. Studio Workspace starts Connected (success), Docs Workspace starts as Reconnect (danger), Product Docs is Connect (default), Admin is staff-only. Switch to Admin, then Registered apps can add an app, show credentials once, and revoke. Both Studio Workspace and Docs Workspace seed site name `Studio` through Site Settings. Dummy Tailwind imports resolved engine paths from `gem_sources.css` before each build so Flatpack classes are not missed when gems sit under `/usr/local/lib/ruby/gems`.

## Version

0.1.1
