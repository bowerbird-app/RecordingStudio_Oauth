# Dummy app

This Rails host proves `recording_studio_oauth` as an authorization server.

## What it covers

- Devise sign-in (`admin@admin.com` / `Password`)
- Accessible grants on Workspace, Folder, and AdminRoot
- Seed Demo App plus Studio Workspace, Docs Workspace, and Product Docs
- Mounted OAuth, API, Admin, and Accessible engines
- RFC 8414 on the host `/.well-known` paths
- Rounded Flatpack theme and Recording Studio default layout
- Turbo plus Admin screen controllers, so staff registered-apps table rows load

API is mounted so the dummy looks like a real host. Token URL stays on the API engine. Machine keys stay there.

## Quick start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Open port 3000. Sign in with `admin@admin.com` / `Password`. Switch to the Admin root before opening staff admin.

Page-only review shots live in `doc/review/`.

## Routes

- `/` dummy home
- `/recording_studio_oauth/oauth/authorize` Connect
- `/recording_studio_oauth/connected_apps` connected apps
- `/admin` staff admin (switch the dummy to the Admin root first)
- `/recording_studio_api/oauth/token` API token URL
- `/users/sign_in` Devise
