# Migration notes

## Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio `~> 4.2` (dummy tag `v4.5.0`)
- Accessible `~> 0.11` (dummy tag `v0.15.0`). Access roles are strings (`view`, `edit`, `admin`). Dummy also has access invitations plus audience constraint/rule tables from Accessible `0.14.0`. View copy uses Rails I18n (`recording_studio.accessible.*`); `0.15.0` is translation-only (English unchanged).
- API `>= 0.5.2, < 0.7` (dummy tag `v0.6.0`). Dummy shims `RecordingStudio::Access.roles` for this pin.
- Metrics `~> 0.2` (dummy tag `v0.2.0`). The host calls `RecordingStudioMetrics::Api.register!(api: :operations)`.
- Trashable `~> 0.9` (dummy tag `v0.9.0`). Oauth voids and kept/trashed lookups use sibling APIs; dummy already has `trashed_at` from Recording Studio.
- Admin `~> 2.0` (dummy tag `v2.2.0`). `2.2.0` is translation-only (English unchanged).
- Site Settings `~> 0.1` (dummy tag `v0.1.3`)
- Attachable `~> 0.5` (dummy tag `v0.15.0`, required by Site Settings). Dummy includes library and placement migrations from Attachable `0.12.0`. View copy uses Rails I18n (`recording_studio.attachable.*`); `0.15.0` is translation-only (English unchanged).
- Root Switchable dummy tag `v0.8.0` (view and mounted-page `page_copy` use Rails I18n under `recording_studio.root_switchable.*`; English unchanged)
- Flatpack `~> 0.1.198` (dummy tag `v0.1.213`; Attachable `0.11+` needs `>= 0.1.213`)

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
