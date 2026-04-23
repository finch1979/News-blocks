from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel
from typing import Optional
import json, os, uuid, re, httpx
from pathlib import Path

app = FastAPI(title="方塊磚新聞")

BASE_DIR = Path(__file__).parent
DATA_FILE = BASE_DIR / "data" / "blocks.json"
EXAMPLE_DATA_FILE = BASE_DIR / "data" / "blocks.example.json"
STATIC_DIR = BASE_DIR / "static"

# ── Data helpers ──────────────────────────────────────────────
def load_json(path: Path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)

def load_data():
    if DATA_FILE.exists():
        return load_json(DATA_FILE)
    if EXAMPLE_DATA_FILE.exists():
        return load_json(EXAMPLE_DATA_FILE)
    return {"blocks": DEFAULT_BLOCKS}

def save_data(data):
    with open(DATA_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

# ── Default blocks (first run) ────────────────────────────────
DEFAULT_BLOCKS = [
    {"id": "b1", "title": "Yahoo 奇摩新聞", "url": "https://tw.news.yahoo.com/",
     "color": "#4285f4", "x": 0, "y": 0, "w": 4, "h": 3, "pinned": False, "refresh": 0},
    {"id": "b2", "title": "ESPN 運動", "url": "https://www.espn.com/",
     "color": "#ea4335", "x": 4, "y": 0, "w": 4, "h": 3, "pinned": False, "refresh": 0},
    {"id": "b3", "title": "BBC 中文", "url": "https://www.bbc.com/zhongwen/trad",
     "color": "#34a853", "x": 8, "y": 0, "w": 4, "h": 3, "pinned": False, "refresh": 0},
    {"id": "b4", "title": "中央社即時", "url": "https://www.cna.com.tw/list/aall.aspx",
     "color": "#9c27b0", "x": 0, "y": 3, "w": 3, "h": 2, "pinned": True, "refresh": 300},
    {"id": "b5", "title": "聯合新聞網", "url": "https://udn.com/news/breaknews/1",
     "color": "#fa7c27", "x": 3, "y": 3, "w": 3, "h": 2, "pinned": False, "refresh": 0},
    {"id": "b6", "title": "ETtoday 體育", "url": "https://www.ettoday.net/news/news-list.htm?ndid=15",
     "color": "#00bcd4", "x": 6, "y": 3, "w": 3, "h": 2, "pinned": False, "refresh": 0},
    {"id": "b7", "title": "鏡週刊", "url": "https://www.mirrormedia.mg/",
     "color": "#e91e63", "x": 9, "y": 3, "w": 3, "h": 2, "pinned": False, "refresh": 0},
]

def ensure_data_file():
    if DATA_FILE.exists():
        return
    if EXAMPLE_DATA_FILE.exists():
        save_data(load_json(EXAMPLE_DATA_FILE))
    else:
        save_data({"blocks": DEFAULT_BLOCKS})

ensure_data_file()

# ── Models ─────────────────────────────────────────────────────
class Block(BaseModel):
    id: Optional[str] = None
    title: str
    url: str
    color: str = "#4285f4"
    x: int = 0
    y: int = 0
    w: int = 4
    h: int = 3
    page: int = 1
    pinned: bool = False
    refresh: int = 0   # seconds, 0=off

class BlockUpdate(BaseModel):
    title: Optional[str] = None
    url: Optional[str] = None
    color: Optional[str] = None
    x: Optional[int] = None
    y: Optional[int] = None
    w: Optional[int] = None
    h: Optional[int] = None
    page: Optional[int] = None
    pinned: Optional[bool] = None
    refresh: Optional[int] = None

# ── API Routes ─────────────────────────────────────────────────
@app.get("/api/blocks")
def get_blocks():
    return load_data()["blocks"]

@app.post("/api/blocks")
def create_block(block: Block):
    data = load_data()
    block_dict = block.model_dump()
    block_dict["id"] = str(uuid.uuid4())[:8]
    data["blocks"].append(block_dict)
    save_data(data)
    return block_dict

@app.put("/api/blocks/{block_id}")
def update_block(block_id: str, update: BlockUpdate):
    data = load_data()
    for b in data["blocks"]:
        if b["id"] == block_id:
            for k, v in update.model_dump(exclude_none=True).items():
                b[k] = v
            save_data(data)
            return b
    raise HTTPException(status_code=404, detail="Block not found")

@app.delete("/api/blocks/{block_id}")
def delete_block(block_id: str):
    data = load_data()
    # 檢查方塊是否存在
    block_exists = any(b["id"] == block_id for b in data["blocks"])
    if not block_exists:
        raise HTTPException(status_code=404, detail="Block not found")
    # 刪除方塊
    data["blocks"] = [b for b in data["blocks"] if b["id"] != block_id]
    save_data(data)
    return {"ok": True}

@app.post("/api/blocks/reorder")
def reorder_blocks(blocks: list[dict]):
    data = load_data()
    existing = {b["id"]: b for b in data["blocks"]}
    for item in blocks:
        bid = item.get("id")
        if bid in existing:
            for k in ("x", "y", "w", "h"):
                if k in item:
                    existing[bid][k] = item[k]
    data["blocks"] = list(existing.values())
    save_data(data)
    return {"ok": True}

# Proxy endpoint – fetch page title and favicon (avoids CORS)
@app.get("/api/meta")
async def get_meta(url: str):
    try:
        async with httpx.AsyncClient(timeout=5, follow_redirects=True) as client:
            r = await client.get(url, headers={"User-Agent": "Mozilla/5.0"})
            html = r.text[:4000]
        title_m = re.search(r"<title[^>]*>([^<]{1,120})</title>", html, re.I)
        title = title_m.group(1).strip() if title_m else url
        return {"title": title}
    except Exception:
        return {"title": url}

# ── Static files & SPA fallback ────────────────────────────────
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

@app.get("/", response_class=HTMLResponse)
def root():
    return (STATIC_DIR / "index.html").read_text(encoding="utf-8")

if __name__ == "__main__":
    import uvicorn
    import sys
    # 檢測是否以 pythonw.exe 運行（背景模式）
    is_background = "pythonw.exe" in sys.executable.lower()
    uvicorn.run("app:app", host="127.0.0.1", port=7789, reload=not is_background)
