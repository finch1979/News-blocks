# News Blocks 程式方法整理

本文件整理 News Blocks 的程式結構、資料流、執行方式與維護重點，方便之後接手、修改或部署。

## 專案目的

News Blocks 是一個本機新聞/網站快捷看板。使用者可以把常用網站加入成色塊卡片，透過拖拉調整版面、右鍵管理卡片、分頁切換分類，並把設定儲存在本機 JSON 檔案。

服務預設只綁定本機位址：

```text
http://127.0.0.1:7789
```

## 技術架構

後端：

- `FastAPI`：提供 API 與靜態檔案服務。
- `httpx`：後端抓取網頁 `<title>`，避免前端直接跨來源請求。
- `Pydantic`：定義新增與更新 block 的資料模型。
- `JSON` 檔案：以 `data/blocks.json` 保存使用者資料。

前端：

- `static/index.html`：主要 HTML 結構。
- `static/js/app.js`：GridStack 初始化、API 呼叫、卡片操作、modal、右鍵選單、分頁與自動刷新。
- `static/css/style.css`：深色主題、卡片、modal、viewer、分頁控制等樣式。
- `GridStack`：提供 12 欄拖拉/縮放版面。
- `Font Awesome`：提供按鈕與狀態 icon。

啟停腳本：

- `start.ps1` / `start.bat`：建立 venv、安裝依賴、啟動背景服務。
- `stop.ps1` / `stop.bat`：停止服務。
- `open_app.ps1` / `open_app.bat`：開啟瀏覽器。
- `install_autostart.ps1` / `uninstall_autostart.ps1`：管理 Windows 自動啟動。

## 主要檔案

```text
app.py                         FastAPI 後端入口
requirements.txt               Python 依賴
data/blocks.example.json       初始範例資料
data/blocks.json               實際使用者資料，首次啟動時建立
static/index.html              前端頁面
static/js/app.js               前端互動邏輯
static/css/style.css           前端樣式
smoke_test.py                  API 冒煙測試
服務管理說明.md                  Windows 服務/啟停說明
```

## 後端資料流程

`app.py` 啟動時會先確認資料檔：

1. 如果 `data/blocks.json` 已存在，直接使用它。
2. 如果不存在但 `data/blocks.example.json` 存在，複製範例資料建立正式資料。
3. 如果兩者都不存在，使用程式內建的 `DEFAULT_BLOCKS`。

資料儲存格式為：

```json
{
  "blocks": [
    {
      "id": "news1",
      "title": "BBC News",
      "url": "https://www.bbc.com/news",
      "color": "#2ea043",
      "x": 8,
      "y": 0,
      "w": 4,
      "h": 3,
      "page": 1,
      "pinned": false,
      "refresh": 0
    }
  ]
}
```

欄位說明：

- `id`：block 唯一 ID。
- `title`：卡片標題。
- `url`：點擊後開啟的網址。
- `color`：卡片主色。
- `x`, `y`, `w`, `h`：GridStack 版面位置與大小。
- `page`：所在分頁，預設為 `1`。
- `pinned`：是否標記釘選。
- `refresh`：自動刷新秒數，`0` 表示關閉。

## API 方法

後端提供以下 API：

| Method | Path | 用途 |
| --- | --- | --- |
| `GET` | `/api/blocks` | 讀取所有 blocks |
| `POST` | `/api/blocks` | 新增 block |
| `PUT` | `/api/blocks/{block_id}` | 更新 block |
| `DELETE` | `/api/blocks/{block_id}` | 刪除 block |
| `POST` | `/api/blocks/reorder` | 儲存拖拉後的位置與大小 |
| `GET` | `/api/meta?url=...` | 後端抓取網站標題 |

靜態檔案由以下路由提供：

```text
/static/*
/
```

根路由 `/` 會回傳 `static/index.html`。

## 前端互動流程

啟動頁面後，`app.js` 會依序執行：

1. 建立顏色選擇器。
2. 初始化 GridStack。
3. 呼叫 `/api/blocks` 載入資料。
4. 根據目前分頁渲染卡片。
5. 綁定上方工具列、modal、右鍵選單、viewer、鍵盤與分頁按鈕。

卡片操作：

- 左鍵點擊：用新分頁開啟網站。
- 右鍵點擊：顯示 context menu。
- 拖拉或縮放：GridStack 觸發 `change` 事件，送出 `/api/blocks/reorder`。
- 新增/編輯：modal 送出後呼叫 `POST` 或 `PUT`。
- 刪除：呼叫 `DELETE` 後移除畫面上的 widget。
- 自動刷新：若 `refresh > 0`，在 viewer 開啟該 block 時定時重載 iframe。

## 執行方式

PowerShell：

```powershell
.\start.ps1 -OpenBrowser
```

停止服務：

```powershell
.\stop.ps1
```

手動開發啟動：

```powershell
.\.venv\Scripts\python.exe app.py
```

或直接使用 uvicorn：

```powershell
.\.venv\Scripts\uvicorn.exe app:app --host 127.0.0.1 --port 7789 --reload
```

## 測試方式

服務啟動後執行：

```powershell
.\.venv\Scripts\python.exe .\smoke_test.py
```

`smoke_test.py` 會測試首頁、blocks API、新增、更新、刪除、meta proxy、靜態 CSS/JS 與 reorder API。

## 維護注意事項

- `data/blocks.json` 是本機使用者資料，不應任意覆蓋。
- 修改前端文案時要確認檔案編碼為 UTF-8，避免中文變成亂碼。
- 新增 block 欄位時，後端 `Block` / `BlockUpdate`、前端 payload、資料範例三處都要同步。
- 若調整 GridStack 欄數或 cell 高度，要同步檢查 `x`, `y`, `w`, `h` 的既有資料是否仍合理。
- 外部網站可能禁止 iframe 內嵌，因此目前主要互動是新分頁開啟網站。
- `/api/meta` 只抓取前 4000 字元 HTML 與 `<title>`，不是完整爬蟲。

## 建議後續改善

- 修復既有中文亂碼與缺失引號問題，先統一所有檔案為 UTF-8。
- 將 `data/blocks.example.json` 改成完全有效的 JSON，讓首次啟動更穩定。
- 在 `smoke_test.py` 加入 JSON 格式檢查與前端主要檔案語法檢查。
- 將頁面數量從目前前端固定 `1..3` 改成由資料或設定檔控制。
- 若需要多人使用，可把 JSON 儲存改成 SQLite，並加上資料鎖或交易處理。
