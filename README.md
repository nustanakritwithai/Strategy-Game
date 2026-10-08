# เกมกลยุทธ์

ไคลเอนต์ผู้เล่นของโลกจำลองแบบ Travian / Rise of Kingdoms เขียนด้วย Godot 4.7.2 (GDScript) เซิร์ฟเวอร์ที่ [Server-Manager-](https://github.com/nustanakritwithai/Server-Manager-) เป็นผู้ตัดสินทุกอย่าง ทั้งการรบ บัญชีทรัพยากร การเดินทาง การผลิต และเหตุการณ์ ไคลเอนต์วาดสถานะที่เซิร์ฟเวอร์ส่งมา และส่งคำสั่งเท่านั้น

เล่นบน GitHub Pages: <https://nustanakritwithai.github.io/Strategy-Game/>

เซิร์ฟเวอร์เริ่มต้น: `https://157-85-96-139.sslip.io`

## วิธีเล่น

1. เปิดหน้าที่อยู่ด้านบน หรือรันโปรเจกต์จาก Godot
2. ตรวจที่อยู่เซิร์ฟเวอร์ จุดสีเขียวก่อนเข้าสู่ระบบหมายถึง `GET /health` ตอบกลับ หลังเข้าสู่ระบบไคลเอนต์เรียก `GET /v1/time` ด้วย access token นาฬิกานับถอยหลังใช้เวลาเซิร์ฟเวอร์เท่านั้น
3. สมัครหรือเข้าสู่ระบบด้วยชื่อผู้ใช้และรหัสผ่าน (`POST /v1/auth/register`, `/login`) การสมัครได้เมืองบ้าน ทัพ และทรัพยากรเริ่มต้นจากเซิร์ฟเวอร์ทันที หลังเข้าสู่ระบบไคลเอนต์อ่าน `GET /v1/auth/me` ถ้า `start_granted` เป็นเท็จจะเรียก `POST /v1/auth/claim-start` หนึ่งครั้ง (ไม่ส่งพิกัด) แล้วเลื่อนแผนที่ไปที่เมืองบ้านและเลือกทัพเริ่มต้น ถ้าเซิร์ฟเวอร์ตอบ `world_full` จะแสดงข้อความนั้นตามที่ส่งมา access token อยู่ได้ 15 นาที และอยู่ในหน่วยความจำ refresh token ถูกหมุนทุกครั้งที่ใช้ (อายุ 30 วัน) ถ้าคำขอได้ 401 ไคลเอนต์รีเฟรชครั้งเดียวแล้วส่งใหม่ ถ้ารีเฟรชไม่ผ่านจะกลับไปหน้าเข้าสู่ระบบ
4. **จดจำฉันบนอุปกรณ์นี้** ปิดอยู่เป็นค่าเริ่มต้น โทเคนจึงหายเมื่อปิดแท็บ ถ้าติ๊ก เครื่องนี้จะเก็บเฉพาะ refresh token เพื่อเข้าต่อได้ คนที่เปิดเบราว์เซอร์เครื่องนี้จะใช้เซสชันนั้นได้ รหัสผ่านและ access token ไม่ถูกบันทึกและไม่ถูกพิมพ์ในล็อก
5. เปลี่ยนรหัสผ่าน ออกจากระบบ และออกจากทุกอุปกรณ์ เรียก `POST /v1/auth/change-password`, `/logout`, `/logout-all` ถ้าเซิร์ฟเวอร์ตอบ `password_change_required` แผนที่จะไม่เปิดจนกว่าจะเปลี่ยนรหัส
6. **โหมดนักพัฒนา** (`POST /v1/auth/dev-login`) มีเฉพาะตอนรันจากตัวแก้ไขหรือบิลด์ดีบัก ไม่มีในเว็บที่ส่งออกแบบ release บนโปรดักชันเส้นนี้ตอบ 404
7. ลากแผนที่เพื่อเลื่อน ใช้ลูกกลิ้งหรือบีบนิ้วเพื่อซูม แตะเมืองหรือทัพ เมืองของเราเป็นปราสาทสีทอง เมืองคนอื่นเป็นบ้านหลังคาส้ม ทัพเป็นโล่สีฟ้า แถบด้านบนแสดงไม้ อาหาร เหล็ก ทองของเมืองที่เลือกตามค่าจากเซิร์ฟเวอร์ ตำแหน่งทัพระหว่างเดินทางคำนวณจาก `depart_at` / `arrive_at` ที่เซิร์ฟเวอร์ให้มา เพื่อแสดงผลเท่านั้น ฟิลด์ที่เซิร์ฟเวอร์ไม่ส่งจะขึ้น `UNKNOWN` ตัวเลขจำนวนเต็มที่ยาวกว่าที่ JSON เก็บได้แบบทศนิยม (เช่นซีดการรบ) แสดงจากข้อความดิบ เพื่อไม่ปัดเศษ
8. เมือง: ทรัพยากร อาคาร งานวิจัย กองประจำการ ตามค่าล่าสุดจากเซิร์ฟเวอร์ สั่งก่อสร้าง วิจัย ฝึกหน่วย สร้างเมือง โอนทรัพยากรได้ ข้อความที่เซิร์ฟเวอร์ปฏิเสธแสดงตามที่ส่งมา
9. ทัพ: เสริมกำลัง ย้ายถิ่นฐาน โจมตี เรียกกลับ ประจำการ เลือกเป้าหมายบนแผนที่ หรือจากรายชื่อเมืองด้านข้างเมื่อจุดทับกัน แล้วยืนยัน ทุกคำสั่งแนบ `Idempotency-Key` ค่าใหม่ และการส่งซ้ำคำสั่งเดิมใช้คีย์เดิม
10. รายงานการรบมาจาก `GET /v1/me/reports` และ `GET /v1/me/reports/{id}`
11. เส้นทางที่ไคลเอนต์ใช้ และช่องที่เซิร์ฟเวอร์ยังไม่มี อยู่ใน `docs/SERVER_COVERAGE.md`
12. สลับภาษาไทย/อังกฤษได้จากหน้าเข้าสู่ระบบหรือแถบบน ภาษาเริ่มต้นคือไทย ฟอนต์ Noto Sans Thai (SIL Open Font License, ดู `fonts/OFL.txt`)

ไม่มีตัวติดตามหรือ analytics

## สร้างบนเครื่อง

ใช้ Godot **4.7.2 stable** ตัวแก้ไขมาตรฐาน ไม่ใช่รุ่น .NET

```bash
bash tools/install_godot.sh
.godot-sdk/bin/godot --headless --editor --quit --path .
.godot-sdk/bin/godot --headless --path . --script res://tests/run_tests.gd
.godot-sdk/bin/godot --path .
```

ส่งออกเว็บแบบเธรดเดียว เพื่อให้รันบน GitHub Pages ได้โดยไม่ต้องมีหัว `Cross-Origin-Opener-Policy` / `Cross-Origin-Embedder-Policy` (Pages ตั้งหัวเหล่านี้ไม่ได้ และเบราว์เซอร์จะไม่ให้ `SharedArrayBuffer` ถ้าไม่มีหัวนั้น)

ใน `export_presets.cfg` ค่า `variant/thread_support` เป็น `false` เทมเพลตที่ใช้คือ `web_nothreads_release.zip`

```bash
mkdir -p build/web
.godot-sdk/bin/godot --headless --path . --export-release "Web" build/web/index.html
python3 tools/check_web_export.py build/web/index.html
python3 -m http.server 8080 --directory build/web
```

เปิด `http://127.0.0.1:8080` ใช้ได้ทั้งเดสก์ท็อปและเบราว์เซอร์มือถือ ทั้งแนวตั้งและแนวนอน หน่วยของ UI เท่ากับหนึ่งพิกเซล CSS (หารด้วย devicePixelRatio) จอกว้างประมาณ 390px จึงได้เลย์เอาต์มือถือ ไม่ใช่หน้าจอเดสก์ท็อปที่ถูกย่อ

## การเผยแพร่

เวิร์กโฟลว์ `.github/workflows/web.yml` ปัก Godot 4.7.2

- พูลรีเควสต์: รันเทส แล้วส่งออกเว็บและอัปโหลดเป็น artifact ชื่อ `web-export` ไม่ขึ้น Pages
- push ที่ `main`: ทำเหมือนกัน แล้ว deploy ด้วย official GitHub Pages actions

ที่อยู่ที่คาดไว้หลัง merge: <https://nustanakritwithai.github.io/Strategy-Game/>

## สิ่งที่ต่อกับเซิร์ฟเวอร์

บัญชีผู้เล่นและคำสั่งเหล่านี้มาจาก Server-Manager- `fea6f17`: `POST /v1/auth/register`, `/login`, `/claim-start`, `/refresh`, `/logout`, `/logout-all`, `/change-password`, `GET /v1/auth/me`, `GET /v1/time` (ต้องมี access token), `/v1/me`, `/v1/me/cities`, `/v1/me/cities/{id}`, `/v1/map/cities`, `/v1/me/armies`, `/v1/me/reports`, `/v1/me/reports/{id}`, `POST /v1/commands/move`, `/attack`, `/recall`, `/build`, `/research`, `/train`, `/found-city`, `/garrison`, `/transfer`

ทุก `POST /v1/commands/*` ส่ง `Idempotency-Key` เป็น UUID ใหม่ต่อหนึ่งการกดยืนยัน และใช้คีย์เดิมเมื่อส่งคำสั่งนั้นซ้ำ ถ้า OpenAPI ของเซิร์ฟเวอร์ที่ต่ออยู่ไม่มีเส้นทางใด ปุ่มนั้นจะถูกปิดและบอก endpoint ที่หายไป ค่าที่ไม่มีในเพย์โหลดแสดงเป็น `UNKNOWN`

`POST /v1/auth/dev-login` ใช้ได้เฉพาะบิลด์ดีบัก และเฉพาะเมื่อเซิร์ฟเวอร์เปิดโหมดนั้น บนโปรดักชันตอบ 404

## CORS

พรีไฟลต์จาก `Origin: https://nustanakritwithai.github.io` ไปที่ `https://157-85-96-139.sslip.io` ได้ `access-control-allow-origin` เป็นออริจินนั้น และ `Access-Control-Allow-Headers` รวม `Idempotency-Key` แล้ว ไม่ต้องเปลี่ยน `SIMCORE_CORS_ORIGINS`

---

# Strategy Game

Godot 4.7.2 (GDScript) player client. The simulation server in [Server-Manager-](https://github.com/nustanakritwithai/Server-Manager-) is the only authority for combat, the ledger, travel, production, events, and world state. This client draws that state and sends intent.

Play it on GitHub Pages: <https://nustanakritwithai.github.io/Strategy-Game/>

Default server: `https://157-85-96-139.sslip.io`

## How to play

1. Open the Pages URL, or run the Godot project.
2. Check the server URL. Before sign-in, a green dot means `GET /health` answered. After sign-in the client calls `GET /v1/time` with the access token. Countdowns use that server clock.
3. Register or log in with a username and password (`POST /v1/auth/register`, `/login`). Registering grants a home city, an army, and starting stock on the server. After sign-in the client reads `GET /v1/auth/me`; if `start_granted` is false it calls `POST /v1/auth/claim-start` once (no coordinates), then centers the map on the home city and selects the starting army. A `world_full` reply is shown verbatim. The access token lasts 15 minutes and stays in memory. The refresh token rotates on every use and lasts 30 days. A 401 refreshes once and retries. If refresh fails, the client returns to the sign-in screen.
4. **Remember me on this device** is off by default, so tokens disappear when the tab closes. Ticking it stores only the refresh token on this device. Anyone who can open this browser can continue that session. Passwords and access tokens are not written to disk and are not logged.
5. Change password, log out, and log out everywhere call `POST /v1/auth/change-password`, `/logout`, and `/logout-all`. A `password_change_required` response keeps the map closed until the password changes.
6. **Dev mode** (`POST /v1/auth/dev-login`) exists only in the editor and debug builds. The release web export does not show it. Production returns 404 for that route.
7. Drag the map to pan. Scroll or pinch to zoom. Tap a city or an army. Your cities are gold castles, other cities are orange-roofed houses, armies are blue shields. The bar under the top row shows wood, food, iron, and gold of the selected city from the server. A marching army is drawn from the server `depart_at` and `arrive_at` for display only. A field the server did not send is shown as `UNKNOWN`. An integer wider than a JSON float, such as a battle seed, is shown from the raw text so it is not rounded.
8. The city panel shows resources, buildings, research, and the garrison from the latest server payload. Build, research, train, found city, and transfer send the server's own errors back verbatim.
9. Army orders are reinforce, relocate, attack, recall, and garrison. Pick the target on the map, or from the city list shown beside the map when markers overlap, then confirm. Every command POST sends a new `Idempotency-Key`. A retry of that same order reuses the key.
10. Battle reports come from `GET /v1/me/reports` and `GET /v1/me/reports/{id}`.
11. Which player routes the client calls, and which server gaps remain, is listed in `docs/SERVER_COVERAGE.md`.
12. Switch Thai and English from the sign-in screen or the top bar. Thai is the default. The font is Noto Sans Thai (SIL Open Font License, see `fonts/OFL.txt`).

No analytics and no trackers.

## Build locally

Godot **4.7.2 stable**, the standard build, not the .NET build.

```bash
bash tools/install_godot.sh
.godot-sdk/bin/godot --headless --editor --quit --path .
.godot-sdk/bin/godot --headless --path . --script res://tests/run_tests.gd
.godot-sdk/bin/godot --path .
```

The web export is single-threaded so GitHub Pages can host it. Pages cannot set `Cross-Origin-Opener-Policy` or `Cross-Origin-Embedder-Policy`, and browsers withhold `SharedArrayBuffer` without those headers.

`export_presets.cfg` sets `variant/thread_support` to `false`, which selects `web_nothreads_release.zip`.

```bash
mkdir -p build/web
.godot-sdk/bin/godot --headless --path . --export-release "Web" build/web/index.html
python3 tools/check_web_export.py build/web/index.html
python3 -m http.server 8080 --directory build/web
```

Open `http://127.0.0.1:8080`. The layout is for desktop browsers and for mobile browsers in portrait and landscape. One UI unit is one CSS pixel (the window divided by devicePixelRatio), so a ~390px-wide phone gets the phone layout instead of a shrunken desktop canvas.

## Deployment

`.github/workflows/web.yml` pins Godot 4.7.2.

- Pull requests run the tests, export the web build, and upload it as the `web-export` artifact. They do not deploy.
- A push to `main` does the same, then deploys with the official GitHub Pages actions.

Expected URL after merge: <https://nustanakritwithai.github.io/Strategy-Game/>

## Wired to the server

Player accounts and these commands match Server-Manager- `fea6f17`: `POST /v1/auth/register`, `/login`, `/claim-start`, `/refresh`, `/logout`, `/logout-all`, `/change-password`, `GET /v1/auth/me`, `GET /v1/time` (access token required), `/v1/me`, `/v1/me/cities`, `/v1/me/cities/{id}`, `/v1/map/cities`, `/v1/me/armies`, `/v1/me/reports`, `/v1/me/reports/{id}`, `POST /v1/commands/move`, `/attack`, `/recall`, `/build`, `/research`, `/train`, `/found-city`, `/garrison`, `/transfer`.

Every `POST /v1/commands/*` sends a new `Idempotency-Key` UUID for that confirmation, and a retry of the same order reuses it. If the connected server's OpenAPI is missing a route, that button stays disabled and names the missing path. A value absent from the payload is shown as `UNKNOWN`.

`POST /v1/auth/dev-login` is only offered in a debug build, and only when the server has that route enabled. Production returns 404.

## CORS

A preflight from `Origin: https://nustanakritwithai.github.io` to `https://157-85-96-139.sslip.io` returns that origin and includes `Idempotency-Key` in `Access-Control-Allow-Headers`. `SIMCORE_CORS_ORIGINS` does not need to change.
