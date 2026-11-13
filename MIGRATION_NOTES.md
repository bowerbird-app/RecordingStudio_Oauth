# Migration notes

## Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio `~> 6.0` (dummy tag `v6.7.0`). `config.authorize_write` must be set. Dummy allows a write when an actor is present.
- Accessible `>= 0.18, < 1.0` (dummy tag `v0.32.0`). Access roles are strings (`view`, `edit`, `admin`). Dummy also has access invitations plus audience constraint/rule tables from Accessible `0.14.0`. View copy uses Rails I18n (`recording_studio.accessible.*`). Soft-trash query helpers need Trashable `>= 0.10, < 1.0`. `ControllerAuth` is optional for sibling engines (no migration).
- API `>= 0.5.2, < 1.0` (dummy tag `v0.23.1`).
- Metrics `>= 0.3, < 1.0` (dummy tag `v0.8.0`). The host calls `RecordingStudioMetrics::Api.register!(api: :operations)`. Registered-apps charts pass `{ x:, y: }` points from `chart_series` through unchanged.
- Trashable `>= 0.10, < 1.0` (dummy tag `v0.14.0`, `require: false`). Oauth loads `recording_studio_trashable/query` only for voids and kept/trashed lookups (`void_recording!`, predicates, additive `kept_sql` — not `recording_studio_trashable_active`). Dummy has `trashed_at` from Recording Studio and `purge_at` from Trashable `0.14.0`.
- Admin `>= 2.0, < 3.0` (dummy tag `v2.13.0`).
- Site Settings `>= 0.2, < 1.0` (dummy tag `v0.5.6`).
- Attachable is not an Oauth dependency. Site Settings needs it. Dummy tag `v0.23.0`. Dummy includes library and placement migrations. View copy uses Rails I18n (`recording_studio.attachable.*`).
- Root Switchable dummy tag `v0.15.0`. The mounted switch page requires an Accessible `:view` grant on the current root. Page copy uses Rails I18n under `recording_studio.root_switchable.*`.
- Flatpack `>= 0.1.341` (dummy tag `v0.1.357`)
- Cache `>= 0.5, < 1.0` (dummy tag `v0.6.3`)
- Logs, Moveable, and Icons are development pins only (dummy tags `v0.7.4`, `v4.1.1`, and `v0.2.1`). Do not add them to this gemspec.
- Internationalization is dummy-only (tag `v0.2.2`). Do not add it to this gemspec.

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
