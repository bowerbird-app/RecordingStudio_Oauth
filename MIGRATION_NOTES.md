# Migration notes

## Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio `>= 7.1.0, < 8.0` (dummy tag `v7.3.0`). `config.authorize_write` must be set. Dummy allows a write when an actor is present. `root_recording_for` only finds a root. Create one with `create_root_recording!(recordable, actor:)`. Dummy copies `20261114090000_add_root_recording_id_to_recording_studio_events`. Core `after_service` and `around_service` receive secrets hidden for every Oauth service. The caller still receives the real result. An authorization on a hook is a copy. Its client copy has no session secret, and its token associations are empty.
- Accessible `>= 0.44.0, < 2.0` (dummy tag `v0.45.1`). Access roles are strings (`view`, `edit`, `admin`). Dummy also has access invitations plus audience constraint/rule tables from Accessible `0.14.0`. View copy uses Rails I18n (`recording_studio.accessible.*`). Soft-trash query helpers need Trashable `>= 0.17.0, < 2.0`. `ControllerAuth` is optional for sibling engines (no migration).
- API `>= 1.0.0, < 2.0` (dummy tag `v1.2.1`).
- Metrics `>= 0.9.0, < 2.0` (dummy tag `v0.9.0`). The host calls `RecordingStudioMetrics::Api.register!(api: :operations)`. Registered-apps charts pass `{ x:, y: }` points from `chart_series` through unchanged.
- Trashable `>= 0.17.0, < 2.0` (dummy tag `v1.0.1`, `require: false`). Oauth loads `recording_studio_trashable/query` only for voids and kept/trashed lookups (`void_recording!`, predicates, `Recording.kept`). Dummy has `trashed_at` from Recording Studio and `purge_at` from Trashable `0.14.0`.
- Admin `>= 2.16.0, < 3.0` (dummy tag `v2.18.0`). Staff admin uses `access_recording_resolver`. `site_admin_recording_resolver` is gone. Dummy sets Accessible `admin_root_resolver` to the same kept Admin root so site screens authorize.
- Site Settings `>= 0.6.0, < 2.0` (dummy tag `v0.6.0`).
- Attachable is not an Oauth dependency. Site Settings needs it. Dummy pins tag `v0.31.0`, which requires API `>= 1.1.0`, `< 2.0`. Dummy includes library and placement migrations. View copy uses Rails I18n (`recording_studio.attachable.*`).
- Root Switchable dummy tag `v0.16.0`. The mounted switch page requires an Accessible `:view` grant on the current root. Page copy uses Rails I18n under `recording_studio.root_switchable.*`.
- Flatpack `>= 0.1.376, < 2.0` (dummy tag `v0.1.377`)
- Cache `>= 0.6.0, < 2.0` (dummy tag `v0.7.0`)
- Logs, Moveable, and Icons are development pins only (dummy tags `v0.8.0`, `v6.0.0`, and `v0.4.0`). Do not add them to this gemspec.
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
