"""冒煙測試 — 方塊磚新聞 API"""
import httpx, sys, time

BASE = "http://127.0.0.1:7789"
PASS = FAIL = 0

def check(name, cond, detail=""):
    global PASS, FAIL
    if cond:
        PASS += 1
        print(f"[PASS] {name}" + (f" | {detail}" if detail else ""))
    else:
        FAIL += 1
        print(f"[FAIL] {name}" + (f" | {detail}" if detail else ""))

c = httpx.Client(base_url=BASE, timeout=10)

# T1 — 首頁
r = c.get("/")
check("T1 GET /", r.status_code == 200 and "<title>" in r.text,
      f"HTTP {r.status_code}")

# T2 — 取得方塊
r = c.get("/api/blocks")
blocks = r.json()
check("T2 GET /api/blocks", r.status_code == 200 and len(blocks) >= 7,
      f"HTTP {r.status_code}, 方塊數={len(blocks)}")

# T3 — 新增方塊
r = c.post("/api/blocks", json={
    "title": "冒煙測試方塊", "url": "https://example.com",
    "color": "#ff0000", "x": 0, "y": 0, "w": 3, "h": 2,
    "pinned": False, "refresh": 0
})
nb = r.json()
new_id = nb.get("id", "")
check("T3 POST /api/blocks", r.status_code == 200 and bool(new_id),
      f"HTTP {r.status_code}, id={new_id!r}")

# T4 — 更新方塊
if new_id:
    r = c.put(f"/api/blocks/{new_id}", json={"title": "已更新標題", "pinned": True})
    updated = r.json()
    check("T4 PUT /api/blocks/{id}",
          r.status_code == 200 and updated.get("title") == "已更新標題",
          f"HTTP {r.status_code}, title={updated.get('title')!r}")
else:
    check("T4 PUT /api/blocks/{id}", False, "SKIP — T3 無 id")

# T5 — 刪除方塊
if new_id:
    r = c.delete(f"/api/blocks/{new_id}")
    check("T5 DELETE /api/blocks/{id}",
          r.status_code == 200 and r.json().get("ok") is True,
          f"HTTP {r.status_code}")
else:
    check("T5 DELETE /api/blocks/{id}", False, "SKIP — T3 無 id")

# T6 — Meta proxy
r = c.get("/api/meta", params={"url": "https://www.bbc.com/"})
meta = r.json()
check("T6 GET /api/meta",
      r.status_code == 200 and "title" in meta,
      f"HTTP {r.status_code}, title={meta.get('title','')[:30]!r}")

# T7 — 靜態 CSS
r = c.get("/static/css/style.css")
check("T7 GET /static/css/style.css", r.status_code == 200,
      f"HTTP {r.status_code}")

# T8 — 靜態 JS
r = c.get("/static/js/app.js")
check("T8 GET /static/js/app.js", r.status_code == 200,
      f"HTTP {r.status_code}")

# T9 — Reorder
first_id = blocks[0]["id"] if blocks else ""
if first_id:
    r = c.post("/api/blocks/reorder",
               json=[{"id": first_id, "x": 2, "y": 1, "w": 5, "h": 3}])
    check("T9 POST /api/blocks/reorder",
          r.status_code == 200 and r.json().get("ok") is True,
          f"HTTP {r.status_code}")
else:
    check("T9 POST /api/blocks/reorder", False, "SKIP — 無方塊")

# T10 — 刪除不存在的方塊 → 404
r = c.delete("/api/blocks/nonexistent_id_xyz")
check("T10 DELETE nonexistent → 404",
      r.status_code == 404,
      f"HTTP {r.status_code} (期望 404)")

print()
print("=" * 40)
print(f"  結果: PASS={PASS}  FAIL={FAIL}  (共10項)")
print("=" * 40)
sys.exit(0 if FAIL == 0 else 1)
