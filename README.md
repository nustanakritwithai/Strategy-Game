# เกมกลยุทธ์

ไคลเอนต์ผู้เล่นของโลกจำลองแบบ Travian / Rise of Kingdoms เขียนด้วย Godot 4.7.2 (GDScript) เซิร์ฟเวอร์ที่ [Server-Manager-](https://github.com/nustanakritwithai/Server-Manager-) เป็นผู้ตัดสินทุกอย่าง ทั้งการรบ บัญชีทรัพยากร การเดินทาง การผลิต และเหตุการณ์ ไคลเอนต์วาดสถานะที่เซิร์ฟเวอร์ส่งมา และส่งคำสั่งเท่านั้น

เล่นบน GitHub Pages: <https://nustanakritwithai.github.io/Strategy-Game/>

เซิร์ฟเวอร์เริ่มต้น: `https://157-85-96-139.sslip.io`

## วิธีเล่น

1. เปิดหน้าที่อยู่ด้านบน หรือรันโปรเจกต์จาก Godot
2. ตรวจที่อยู่เซิร์ฟเวอร์ จุดสีเขียวหมายถึง `GET /health` และ `GET /v1/time` ตอบกลับ นาฬิกานับถอยหลังใช้เวลาเซิร์ฟเวอร์
3. สมัครหรือเข้าสู่ระบบเมื่อเซิร์ฟเวอร์เปิด Phase 7 (`POST /v1/auth/register`, `/login`, `/refresh`, `/logout`) ถ้าจุดเหล่านี้ยังไม่มี หน้าจอจะบอกตรงๆ ว่าบัญชียังใช้ไม่ได้
4. ติ๊ก **จดจำการเข้าสู่ระบบบนอุปกรณ์นี้** เพื่อเก็บเฉพาะ refresh token รหัสผ่านและ access token ไม่ถูกเขียนลงดิสก์ และไม่ถูกพิมพ์ในล็อก
5. **โหมดนักพัฒนา** ปิดอยู่เป็นค่าเริ่มต้น เมื่อเปิด จะเรียก `POST /v1/auth/dev-login` ซึ่งเป็นตัวแทนชั่วคราว ไม่ใช่บัญชีจริง ป้ายบนหน้าจอเกมจะบอกว่าเป็นโหมดนี้อยู่
6. ลากแผนที่เพื่อเลื่อน ใช้ลูกกลิ้งหรือบีบนิ้วเพื่อซูม แตะเมืองหรือทัพ เมืองของเราเป็นสีทอง เมืองคนอื่นเป็นสีส้ม ทัพเป็นสามเหลี่ยมสีฟ้า ตำแหน่งทัพระหว่างเดินทางคำนวณจาก `depart_at` / `arrive_at` ที่เซิร์ฟเวอร์ให้มา เพื่อแสดงผลเท่านั้น
7. เมือง: ทรัพยากร อาคาร งานวิจัย กองประจำการ ตามค่าล่าสุดจากเซิร์ฟเวอร์ สั่งก่อสร้างและวิจัยได้ทันที
8. ทัพ: เสริมกำลัง ย้ายถิ่นฐาน โจมตี เรียกกลับ เลือกเป้าหมายบนแผนที่ แล้วยืนยัน ข้อความที่เซิร์ฟเวอร์ปฏิเสธจะแสดงตามที่ส่งมา
9. ฝึกหน่วย สร้างเมือง ประจำการ และโอนทรัพยากรจะกดได้เมื่อ OpenAPI ของเซิร์ฟเวอร์มี `POST /v1/commands/train`, `/found-city`, `/garrison`, `/transfer` ถ้ายังไม่มี ปุ่มจะถูกปิดพร้อมบอก endpoint ที่รออยู่
10. รายงานการรบมาจาก `GET /v1/me/reports` และ `GET /v1/me/reports/{id}` ทั้งรายการและรายละเอียด
11. สลับภาษาไทย/อังกฤษได้จากหน้าเข้าสู่ระบบหรือแถบบน ภาษาเริ่มต้นคือไทย ฟอนต์ Noto Sans Thai (SIL Open Font License, ดู `fonts/OFL.txt`)

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

เปิด `http://127.0.0.1:8080` ใช้ได้ทั้งเดสก์ท็อปและเบราว์เซอร์มือถือ ทั้งแนวตั้งและแนวนอน

## การเผยแพร่

เวิร์กโฟลว์ `.github/workflows/web.yml` ปัก Godot 4.7.2

- พูลรีเควสต์: รันเทส แล้วส่งออกเว็บและอัปโหลดเป็น artifact ชื่อ `web-export` ไม่ขึ้น Pages
- push ที่ `main`: ทำเหมือนกัน แล้ว deploy ด้วย official GitHub Pages actions

ที่อยู่ที่คาดไว้หลัง merge: <https://nustanakritwithai.github.io/Strategy-Game/>

## สิ่งที่ต่อกับเซิร์ฟเวอร์แล้ว และสิ่งที่ยังรอ

ใช้ได้บนเซิร์ฟเวอร์สาธารณะตอนนี้: `POST /v1/auth/dev-login`, `GET /v1/time`, `/v1/me`, `/v1/me/cities`, `/v1/me/cities/{id}`, `/v1/map/cities`, `/v1/me/armies`, `/v1/me/reports`, `/v1/me/reports/{id}`, `POST /v1/commands/move`, `/attack`, `/recall`, `/build`, `/research`

ยังเป็น 404 จึงถูกปิดในไคลเอนต์: `POST /v1/auth/register`, `/login`, `/refresh`, `/logout` และ `POST /v1/commands/train`, `/found-city`, `/garrison`, `/transfer` (ร่าง PR #18 ของ Server-Manager-)

หัว `Idempotency-Key` จะถูกส่งเมื่อ OpenAPI ระบุชื่อนี้ หรือเมื่อการตรวจ CORS จากไคลเอนต์เดสก์ท็อปเห็นชื่อนี้ใน `Access-Control-Allow-Headers` เซิร์ฟเวอร์สาธารณะตอนนี้ยังไม่รับหัวนี้

## CORS

ตรวจพรีไฟลต์จริงที่ `https://157-85-96-139.sslip.io` ด้วย `Origin: https://nustanakritwithai.github.io` เซิร์ฟเวอร์ตอบ `access-control-allow-origin: https://nustanakritwithai.github.io` อยู่แล้ว ไม่ต้องเปลี่ยน `SIMCORE_CORS_ORIGINS` เพื่อให้เพจนี้เรียก API ได้

`Access-Control-Allow-Headers` ที่มีอยู่คือ `Accept`, `Accept-Language`, `Authorization`, `Content-Language`, `Content-Type`, `X-Admin-Token` ไม่มี `Idempotency-Key` และไม่มีตัวแปรสภาพแวดล้อมสำหรับเพิ่มหัวนี้ รายการถูกเขียนไว้ใน `src/simcore/main.py` ของ Server-Manager- ที่ `CORSMiddleware(allow_headers=...)` ก่อนที่เบราว์เซอร์จะส่งหัวนี้ได้ ต้องเพิ่ม `"Idempotency-Key"` ในรายการนั้นแล้วจึงระบุหัวนี้ใน OpenAPI ถ้า OpenAPI ประกาศหัวนี้ก่อนที่ CORS จะอนุญาต คำสั่งจาก Pages จะถูกเบราว์เซอร์ปฏิเสธทั้งก้อน

---

# Strategy Game

Godot 4.7.2 (GDScript) player client. The simulation server in [Server-Manager-](https://github.com/nustanakritwithai/Server-Manager-) is the only authority for combat, the ledger, travel, production, events, and world state. This client draws that state and sends intent.

Play it on GitHub Pages: <https://nustanakritwithai.github.io/Strategy-Game/>

Default server: `https://157-85-96-139.sslip.io`

## How to play

1. Open the Pages URL, or run the Godot project.
2. Check the server URL. A green dot means `GET /health` and `GET /v1/time` answered. Countdowns use the server clock.
3. Register or log in once the server exposes Phase 7 (`POST /v1/auth/register`, `/login`, `/refresh`, `/logout`). Until those routes exist, the screen says that player accounts are not available.
4. **Stay signed in on this device** stores only a refresh token. Passwords and access tokens are not written to disk and are not logged.
5. **Dev mode** is off by default. Turning it on calls `POST /v1/auth/dev-login`, a placeholder rather than an account. The game bar keeps that label visible.
6. Drag the map to pan. Scroll or pinch to zoom. Tap a city or an army. Your cities are gold, other cities are orange, armies are blue triangles. A marching army is drawn from the server `depart_at` and `arrive_at` for display only.
7. The city panel shows resources, buildings, research, and the garrison from the latest server payload. Build and research can be sent now.
8. Army orders are reinforce, relocate, attack, and recall. Pick the target on the map, then confirm. If the server rejects the order, its message is shown as sent.
9. Train, found city, garrison, and transfer stay disabled until the server OpenAPI lists `POST /v1/commands/train`, `/found-city`, `/garrison`, and `/transfer`. The disabled row names the missing route.
10. Battle reports come from `GET /v1/me/reports` and `GET /v1/me/reports/{id}`.
11. Switch Thai and English from the sign-in screen or the top bar. Thai is the default. The font is Noto Sans Thai (SIL Open Font License, see `fonts/OFL.txt`).

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

Open `http://127.0.0.1:8080`. The layout is for desktop browsers and for mobile browsers in portrait and landscape.

## Deployment

`.github/workflows/web.yml` pins Godot 4.7.2.

- Pull requests run the tests, export the web build, and upload it as the `web-export` artifact. They do not deploy.
- A push to `main` does the same, then deploys with the official GitHub Pages actions.

Expected URL after merge: <https://nustanakritwithai.github.io/Strategy-Game/>

## Wired now, and waiting on the server

Live on the public API: `POST /v1/auth/dev-login`, `GET /v1/time`, `/v1/me`, `/v1/me/cities`, `/v1/me/cities/{id}`, `/v1/map/cities`, `/v1/me/armies`, `/v1/me/reports`, `/v1/me/reports/{id}`, `POST /v1/commands/move`, `/attack`, `/recall`, `/build`, `/research`.

Still HTTP 404, so the client keeps them unavailable: `POST /v1/auth/register`, `/login`, `/refresh`, `/logout`, and `POST /v1/commands/train`, `/found-city`, `/garrison`, `/transfer` (draft Server-Manager- PR #18).

`Idempotency-Key` is sent when OpenAPI names that header, or when a desktop CORS probe sees it in `Access-Control-Allow-Headers`. The public server does not accept it yet.

## CORS

A live preflight to `https://157-85-96-139.sslip.io` with `Origin: https://nustanakritwithai.github.io` already returns `access-control-allow-origin: https://nustanakritwithai.github.io`. `SIMCORE_CORS_ORIGINS` does not need to change for this Pages site to call the API.

`Access-Control-Allow-Headers` is `Accept`, `Accept-Language`, `Authorization`, `Content-Language`, `Content-Type`, and `X-Admin-Token`. `Idempotency-Key` is absent, and no environment variable adds headers. The list is fixed in Server-Manager- `src/simcore/main.py` on `CORSMiddleware(allow_headers=...)`. Add `"Idempotency-Key"` there before advertising the header in OpenAPI. If OpenAPI names the header first, the browser will reject every order from Pages.
