# Migration notes

## Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio `~> 4.2` (dummy tag `v4.2.0`)
- Accessible `~> 0.9` (dummy tag `v0.9.1`)
- API `~> 0.5.2` (dummy tag `v0.5.2`)
- Admin `~> 2.0` (dummy tag `v2.0.2`)
- Site Settings `~> 0.1` (dummy tag `v0.1.0`)
- Attachable `~> 0.5` (dummy tag `v0.5.1`, required by Site Settings)
- Flatpack `~> 0.1.144` (dummy tag `v0.1.144`)

Do not depend on Users in the gemspec. The dummy host mounts Users `v0.10.0` only as the reference sign-in for the Connect journey.

Dummy copies engine and API migrations into `test/dummy/db/migrate`. The engine skips appending migrations when the host path contains the gem root, which is true for this nested dummy. Dummy also copies Site Settings, Attachable, and Users migrations, plus Active Storage tables Attachable needs.

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
