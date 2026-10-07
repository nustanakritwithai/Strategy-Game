# Server coverage

Player client against Server-Manager- `fea6f17` (new-player start, server PR #25).
Admin routes under `/v1/admin/*` and the `/health*` probes are not part of the player client.
`/health` is still called so the sign-in screen can show whether the process is up before a token exists. `/v1/time` is the clock after sign-in.

A field the server does not send is shown as `UNKNOWN`. The client does not compute combat, production, upkeep, or travel.

## Player routes

| Route | Screen | Status |
| --- | --- | --- |
| `GET /` | Sign-in and settings show the server `name` and `version` | USED |
| `GET /openapi.json` | Loaded on connect so missing command buttons stay disabled | USED |
| `GET /docs` | | NOT USED. HTML API docs. The client reads `/openapi.json` instead |
| `GET /docs/oauth2-redirect` | | NOT USED. FastAPI helper page. This API does not use the OAuth redirect |
| `GET /redoc` | | NOT USED. HTML API docs. The client reads `/openapi.json` instead |
| `POST /v1/auth/register` | Register form. The server grants the home city, army, and stock in the same call. A 409 `world_full` (no account created) is shown verbatim | USED |
| `POST /v1/auth/login` | Sign-in form. A username or an email is accepted, as the server allows | USED |
| `POST /v1/auth/refresh` | Automatic. One retry after 401. A failed refresh returns to sign-in | USED |
| `POST /v1/auth/logout` | Log out button | USED |
| `POST /v1/auth/logout-all` | Settings | USED |
| `POST /v1/auth/change-password` | Password gate, also opened when the server requires a change | USED |
| `GET /v1/auth/me` | Read after every sign-in. `start_granted`, `home_city`, and `army_id` drive the first view (map centered on the home city, its army selected) and the Start block in settings. Missing fields show `UNKNOWN`. Also the settings account panel: username, email, lock, password flag | USED |
| `POST /v1/auth/claim-start` | Called once per session when `GET /v1/auth/me` says `start_granted` is false. No body, no coordinates. A 409 `world_full` is shown verbatim and the account stays without a start | USED |
| `POST /v1/auth/dev-login` | Dev-mode box | USED in editor and debug builds only. The release web export hides it. Production returns 404 |
| `GET /v1/time` | Top-bar clock. Every countdown subtracts this offset from `depart_at`, `arrive_at`, and `due_at` | USED |
| `GET /v1/me` | Signed-in name and the research levels | USED |
| `GET /v1/me/cities` | City list, resources, rates, buildings | USED |
| `GET /v1/me/cities/{city_id}` | Selected city, refreshed with the world poll | USED |
| `GET /v1/map/cities` | Map. Own cities and other players' cities, without their stocks | USED |
| `GET /v1/me/armies` | Army list, status, units, position, live movement countdown | USED |
| `GET /v1/me/reports` | Report list | USED |
| `GET /v1/me/reports/{report_id}` | Report detail, including seed, casualties, loot, and the raw payload | USED |
| `POST /v1/commands/move` | Reinforce (`relocate` false) and relocate (`relocate` true) | USED |
| `POST /v1/commands/attack` | Attack, target picked from the map or the city list | USED |
| `POST /v1/commands/recall` | Recall | USED |
| `POST /v1/commands/build` | Build button on each building the city payload lists, plus the known catalog names | USED |
| `POST /v1/commands/research` | Research button on each tech | USED |
| `POST /v1/commands/train` | Train form: unit, count, optional army | USED |
| `POST /v1/commands/found-city` | Found-city form. Coordinates come from the form or a map tap | USED |
| `POST /v1/commands/garrison` | Garrison, target is one of your cities | USED |
| `POST /v1/commands/transfer` | Transfer form. Destination is chosen from your own cities | USED |

Every command POST sends `Idempotency-Key`. A new confirmation gets a new UUID. A retry of that same confirmation reuses it. The world poll runs about every 8 seconds and again after each accepted order. A countdown that reaches zero refreshes immediately.

## Display rules

- JSON numbers arrive in Godot as floats. A whole number is printed as an integer everywhere (`#1`, `61`, `round: 1`). An integer with 16 or more digits, such as a battle seed, is kept as the raw JSON text so it is not rounded.
- Battle rounds are a table of the server's `round`, `damage_to_attacker`, `damage_to_defender`, and `attacker_variance_bp` / `defender_variance_bp`. Nothing is recomputed.
- Player, city, and army ids are shown as names when a server payload carries the name (`player_name` on `/v1/map/cities`, `name` on cities and armies). Otherwise `#id`.
- Map markers that share a tile (a garrisoned army on its city) are drawn side by side, and labels are placed so they do not overlap. The world coordinates from the server are not changed.
- The resource bar shows `wood`, `food`, `iron`, `gold` of the selected city from `/v1/me/cities` or `/v1/me/cities/{id}`.

A `503`, or an error code `maintenance`, replaces the map banner with the server message. It is not retried as a transport failure.

## Admin routes

Intentionally absent from the player client: `/v1/admin/accounts`, temporary-password, lock, unlock, sessions, revoke-sessions, armies, audit, cities, clock advance, dashboard, events, event run, admin login and logout, monitoring, movements, players, reports, session revoke, snapshots, trace, transactions, worker tick, and world-map.

## Server follow-ups

These are not implemented on the player API at `fea6f17`. The client does not invent them.

1. Pending jobs. `build`, `research`, `train`, and `transfer` return `due_at` once. There is no player GET for events still in progress, so a reload cannot restore the queue. The client keeps the acceptance on screen until that `due_at` passes, then polls. A `GET /v1/me/events` (or the same rows on `GET /v1/me`) would let the queue survive a reload.
2. Upkeep. Hourly food upkeep is applied inside accrual and is not a field on the city. The client shows that the figure was not sent, and shows the food balance the server did send. A `food_upkeep` field on `GET /v1/me/cities` would let the panel show the rate without copying the unit catalog.
3. History. Movements, transactions, traces, and the event list exist only under `/v1/admin`. A player cannot open the trace id that a report already displays.
