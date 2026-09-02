# Dummy app

This Rails host proves `recording_studio_oauth` as an authorization server.

## What it covers

- Devise sign-in (`admin@admin.com` / `Password`)
- Accessible grants on Workspace, Folder, and AdminRoot
- Seed Demo App plus Studio Workspace, Docs Workspace, and Product Docs
- Site Settings name `Studio` on both workspace roots
- Mounted OAuth, API, Admin, Accessible, Site Settings, and Attachable engines
- RFC 8414 on the host `/.well-known` paths
- Rounded Flatpack theme. Connect uses a centered login-style frame. The access list has no back control. Permission and error keep PageNav. Connected apps and staff admin stay on Recording Studio default layout.
- Turbo plus Admin screen controllers, so staff registered-apps table rows load

API is mounted so the dummy looks like a real host. Token URL stays on the API engine. Machine keys stay there. Boot registers `authorization_code` and `refresh_token` on that same URL. Dummy `access_actor_types` include `RecordingStudioApi::ApiClient` so `client_credentials` still works.

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
- `/recording_studio_oauth/oauth/authorize` Connect
- `/recording_studio_oauth/connected_apps` connected apps
- `/admin` staff admin (switch the dummy to the Admin root first)
- `/recording_studio_api/oauth/token` API token URL
- `/users/sign_in` Devise
