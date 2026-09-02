# Dummy app

This Rails host proves `recording_studio_oauth` as an authorization server.

## What it covers

- Devise sign-in (`admin@admin.com` / `Password`)
- Accessible grants on Workspace, Folder, and AdminRoot
- Seed Demo App plus Studio Workspace, Docs Workspace, and Product Docs
- Mounted OAuth, API, Admin, and Accessible engines
- RFC 8414 on the host `/.well-known` paths
- Rounded Flatpack theme and Recording Studio default layout

API is mounted so the dummy looks like a real host. Token URL stays on the API engine. Machine keys stay there.

## Quick start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Open port 3000.

## Routes

- `/` dummy home
- `/recording_studio_oauth/oauth/authorize` Connect
- `/recording_studio_oauth/connected_apps` connected apps
- `/admin` staff admin
- `/recording_studio_api/oauth/token` API token URL
- `/users/sign_in` Devise
