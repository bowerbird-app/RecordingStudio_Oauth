# Dummy app

This Rails host proves `recording_studio_oauth` as an authorization server.

## What it covers

- Recording Studio Users sign-in (`admin@admin.com` / `Password`): email-first preferred path, then password; Continue with Google on screen 1 in local env
- Accessible grants on Workspace, Folder, and AdminRoot
- Seed Demo App plus Studio Workspace, Docs Workspace, and Product Docs
- Site Settings name `Studio` on both workspace roots
- Mounted OAuth, API, Admin, Accessible, Site Settings, Attachable, and Users engines
- Staff Admin Registered apps can add an app (New app), show credentials once, and revoke. Secret is a Public or Has a secret badge with a short tooltip. Status is an Active or Revoked badge. Revoked is danger.
- RFC 8414 on the host `/.well-known` paths
- Rounded Flatpack theme. Connect uses a centered login-style frame. The access list has no back control and sits in a Card with default padding. Reconnect shows a Flatpack tooltip. Permission and error keep PageNav. Connected apps and staff admin stay on Recording Studio default layout.
- Turbo plus Admin screen controllers, so staff registered-apps table rows load

API is mounted so the dummy looks like a real host. Token URL stays on the API engine. Machine keys stay there. Boot registers `authorization_code` and `refresh_token` on that same URL, and `rsoauth_at_` bearer tokens authenticate through `TokenAuthenticator`. Dummy `access_actor_types` include `RecordingStudioApi::ApiClient` so `client_credentials` still works.

Unauthenticated `/recording_studio_oauth/oauth/authorize` redirects to Users sign-in, then returns to Connect.

## Quick start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Open port 3000. Sign in with `admin@admin.com` / `Password`. Switch to the Admin root before opening staff admin.

Dummy writes resolved engine paths to `app/assets/tailwind/gem_sources.css` before each `tailwindcss:build` or `tailwindcss:watch`. Import that file from `application.css`. Hardcoded `@source` globs miss gems installed under `/usr/local/lib/ruby/gems`, and without those classes PageNav back collapses. The generated file is gitignored.

Page-only review shots live in `doc/review/`.

## Routes

- `/` dummy home
- `/users/sign_in` Users email-first login (then `/users/sign_in/password`)
- `/recording_studio_oauth/oauth/authorize` Connect
- `/recording_studio_oauth/connected_apps` connected apps
- `/admin` staff admin (switch the dummy to the Admin root first)
- `/recording_studio_api/oauth/token` API token URL
