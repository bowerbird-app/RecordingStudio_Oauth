RecordingStudioOauth install complete.

Next steps:

1. Review config/initializers/recording_studio_oauth.rb and set any required options. `config.allow_registration` is the starting value for a new app. It starts off. `config.allow_self_registered_apps` lets MCP clients register themselves at `{mount}/register`. It starts off.
2. If you use environment-specific settings, create config/recording_studio_oauth.yml.
3. Install the engine migrations with `bin/rails generate recording_studio_oauth:migrations`.
4. Apply the migrations with `bin/rails db:migrate`.
5. Install Recording Studio Site Settings (and Attachable) so Connect can read a site name.
6. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
7. Mount routes are added at the configured mount path, including `ProtectedResourceRegistry.draw_origin_well_known` for origin path-inserted authorization-server and protected-resource metadata. Adjust auth, layout, and current actor integration to match your host app.
8. Keep strict recordable declarations enabled and add `recording_studio_recordable(...)` to every configured recordable before running `RecordingStudio.validate_recordable_declarations!`.
9. For the central Connect relay, register a public app, set its redirect URI to `/recording_studio_oauth/callback`, and turn on Use central relay. See `docs/central-connect-relay.md`.
10. For outbound connections, the same migrations add `recording_studio_oauth_outbound_connections` and `recording_studio_oauth_outbound_handshakes`. Configure Active Record encryption so access tokens, refresh tokens, and handshake verifiers encrypt at rest. Register a provider with `RecordingStudioOauth.register_outbound_provider`. Connect is `POST /outbound/:provider/connect`. Lookup is `RecordingStudioOauth.connection_for(provider:, root:, actor:)`. Connect vs reconnect UI is `RecordingStudioOauth.connection_status(provider:, root:, actor:)` (`:missing`, `:active`, `:needs_reconnect`). The live row id for disconnect is `RecordingStudioOauth.connection_id_for(provider:, root:, actor:)`.
