# Migration notes

## Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio `~> 4.2` (dummy tag `v4.2.0`)
- Accessible `~> 0.9` (dummy tag `v0.9.0`)
- API `~> 0.5` (dummy tag `v0.5.1`)
- Admin `~> 2.0` (dummy tag `2.0.1`)
- Flatpack `~> 0.1.143` (dummy tag `v0.1.143`)

Do not pin Flatpack 0.1.144. Do not depend on Users.

Dummy copies engine and API migrations into `test/dummy/db/migrate`. The engine skips appending migrations when the host path contains the gem root, which is true for this nested dummy.

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
