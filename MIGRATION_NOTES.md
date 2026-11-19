# Migration notes

## Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio `>= 7.1.0, < 8.0` (dummy `~> 7.8`, tag `v7.8.0`). `config.authorize_write` must be set. Dummy allows a write when an actor is present. `root_recording_for` only finds a root. Create one with `create_root_recording!(recordable, actor:)`. Dummy copies `20261114090000_add_root_recording_id_to_recording_studio_events`. Hosts MUST run the Recording Studio 7.4, 7.5 and 7.7 migrations if they have not. Core `after_service` and `around_service` receive secrets hidden for every Oauth service. The caller still receives the real result. An authorization on a hook is a copy. Its client copy has no session secret, and its token associations are empty.
- Accessible `>= 0.44.0, < 2.0` (dummy `~> 0.58`, tag `v0.58.0`). Access roles are strings (`view`, `edit`, `admin`). Dummy also has access invitations plus audience constraint/rule tables from Accessible `0.14.0`. View copy uses Rails I18n (`recording_studio.accessible.*`). Soft-trash query helpers need Trashable `>= 0.17.0, < 2.0`. `ControllerAuth` is optional for sibling engines (no migration).
- API `>= 1.0.0, < 2.0` (dummy `~> 1.21`, tag `v1.21.2`). Dummy has `config/recording_studio_api.yml` with `timeout: 5`.
- Metrics `>= 0.9.0, < 2.0` (dummy `~> 0.10`, tag `v0.10.0`). The host calls `RecordingStudioMetrics::Api.register!(api: :operations)`. Registered-apps charts pass `{ x:, y: }` points from `chart_series` through unchanged.
- Trashable `>= 0.17.0, < 2.0` (dummy `~> 1.3`, tag `v1.3.0`, `require: false`). Oauth loads `recording_studio_trashable/query` only for voids and kept/trashed lookups (`void_recording!`, predicates, `Recording.kept`). Dummy has `trashed_at` from Recording Studio and `purge_at` from Trashable `0.14.0`.
- Admin `>= 2.16.0, < 3.0` (dummy `~> 2.20`, tag `v2.20.0`). Staff admin uses `access_recording_resolver`. `site_admin_recording_resolver` is gone. Dummy sets Accessible `admin_root_resolver` to the same kept Admin root so site screens authorize.
- Site Settings `>= 0.6.0, < 2.0` (dummy `~> 0.7`, tag `v0.7.0`).
- Attachable is not an Oauth dependency. Site Settings needs it. Dummy pins `~> 0.34` (tag `v0.34.0`), which requires API `>= 1.1.0`, `< 2.0`. Dummy includes library and placement migrations. View copy uses Rails I18n (`recording_studio.attachable.*`).
- Root Switchable dummy `~> 0.17` (tag `v0.17.0`). The mounted switch page requires an Accessible `:view` grant on the current root. Page copy uses Rails I18n under `recording_studio.root_switchable.*`.
- Flatpack `>= 0.1.376, < 2.0` (dummy `~> 0.2`, tag `v0.2.0`). Icons render on the server. Dummy does not pin `flat_pack/heroicons` and does not register `flat-pack--icon`.
- Cache `>= 0.6.0, < 2.0` (dummy `~> 0.8`, tag `v0.8.0`)
- Logs, Moveable, and Icons are development pins only (dummy `~> 0.9` / `v0.9.0`, `~> 6.1` / `v6.1.0`, and `~> 0.5` / `v0.5.0`). Do not add them to this gemspec.
- Internationalization is dummy-only (tag `v0.3.0`). Do not add it to this gemspec.

Do not depend on Users.

Dummy copies engine and API migrations into `test/dummy/db/migrate`. The engine skips appending migrations when the host path contains the gem root, which is true for this nested dummy. Dummy also copies Site Settings and Attachable migrations, plus Active Storage tables Attachable needs.

## Verification

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```

Dummy:

```bash
cd test/dummy
bin/dev
```
