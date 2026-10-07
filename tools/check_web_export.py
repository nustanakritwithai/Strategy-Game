#!/usr/bin/env python3
"""Fail if the web export needs COOP/COEP or enables threads."""

from pathlib import Path
import sys

html = Path(sys.argv[1] if len(sys.argv) > 1 else "build/web/index.html").read_text(encoding="utf-8")
errors = []
if "const GODOT_THREADS_ENABLED = false;" not in html:
    errors.append("GODOT_THREADS_ENABLED is not false")
if "Cross-Origin-Embedder-Policy" in html or "Cross-Origin-Opener-Policy" in html:
    errors.append("export HTML asks for COOP/COEP headers")
wasm = Path("build/web/index.wasm")
if not wasm.exists() or wasm.stat().st_size < 1000:
    errors.append("index.wasm is missing")
if errors:
    for item in errors:
        print(item, file=sys.stderr)
    sys.exit(1)
print("single-threaded web export, no COOP/COEP requirement")
