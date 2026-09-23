# Connect options

A public client can ask whether one Registered App may offer signup, and where that signup page is.

The request uses the same client id the app already stores. For WordPress that value is `RECORDING_STUDIO_CLIENT_ID`. No login is required.

```text
GET /recording_studio_oauth/connect/options?client_id=<client id>
```

The mount in that path is `RecordingStudioOauth.configuration.engine_mount_path`. The dummy mount is `/recording_studio_oauth`.

## Response

When that app allows registration:

```json
{ "registration": true, "registration_url": "https://app.example.com/users/sign_up" }
```

When that app does not, or the client id is missing or unknown:

```json
{ "registration": false }
```

`registration_url` is absent when `registration` is false. The status is 200 in both cases.

`registration_url` is absolute. It uses `config.public_origin` when that value is set. Otherwise it uses the request origin. The path is `config.registration_path`, which defaults to `/users/sign_up`.

## What the booleans mean

The site choice lives on Registration in Admin, under Registered apps. It is the starting value for a new Registered App. It starts off.

Allow registration on the app form is the value Connect options returns. An app that is on stays on after staff turn the site choice off. An app that is off stays off after staff turn the site choice on.

Apps created before this version are off until staff check Allow registration on that app.

## Helpers

```ruby
RecordingStudioOauth.registration_allowed?(client_id: "the-client-id")
RecordingStudioOauth.registration_url(base_url: "https://app.example.com")
```

`registration_allowed?` is false when the client id is unknown.

## Out of scope

The WordPress plugin does not call this path yet. Signup opens the host Users page. This gem does not return the person to Connect after they register.
