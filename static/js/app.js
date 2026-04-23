/* ============================================================
   方塊磚新聞 — app.js
   Handles: GridStack grid, tile rendering, viewer, context menu,
            edit/add modal, auto-refresh, backend API
============================================================ */

const PALETTE = [
  "#4285f4","#ea4335","#34a853","#9c27b0",
  "#fa7c27","#00bcd4","#e91e63","#ffc107",
  "#3f51b5","#009688","#ff5722","#8bc34a",
  "#607d8b","#795548","#673ab7","#03a9f4"
];

// ── State ────────────────────────────────────────────────────
let grid = null;
let blocks = [];          // master list from backend
let currentPage = 1;      // current page number
let editingId = null;     // block id being edited (null = new)
let ctxTargetId = null;   // right-clicked block id
let refreshTimers = {};   // { blockId: timerId }
let editMode = true;      // drag/resize enabled when true

// ── API helpers ───────────────────────────────────────────────
const api = {
  async getBlocks()       { return (await fetch("/api/blocks")).json(); },
  async create(b)         { return (await fetch("/api/blocks",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(b)})).json(); },
  async update(id, b)     { return (await fetch(`/api/blocks/${id}`,{method:"PUT",headers:{"Content-Type":"application/json"},body:JSON.stringify(b)})).json(); },
  async delete(id)        { return (await fetch(`/api/blocks/${id}`,{method:"DELETE"})).json(); },
  async reorder(list)     { return (await fetch("/api/blocks/reorder",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(list)})).json(); },
  async getMeta(url)      { return (await fetch(`/api/meta?url=${encodeURIComponent(url)}`)).json(); }
};

// ── Init ──────────────────────────────────────────────────────
document.addEventListener("DOMContentLoaded", async () => {
  buildColorSwatches();
  initGrid();
  blocks = await api.getBlocks();
  renderAllBlocks();
  bindTopBar();
  bindModal();
  bindContextMenu();
  bindViewer();
  bindKeyboard();
  bindContextMenu_refresh();
  bindPageNav();
  updatePageNav();
});

// ── GridStack setup ───────────────────────────────────────────
function initGrid() {
  grid = GridStack.init({
    column: 12,
    cellHeight: 80,
    margin: 10,
    animate: true,
    float: false,
    resizable: { handles: "e,se,s,sw,w" },
    draggable: { handle: ".tile" }
  }, "#grid");

  grid.on("change", (_e, items) => {
    if (!items) return;
    const changes = items.map(el => ({
      id: el.el.dataset.blockId,
      x: el.x, y: el.y, w: el.w, h: el.h
    }));
    api.reorder(changes);
    // sync local state
    changes.forEach(c => {
      const b = blockById(c.id);
      if (b) Object.assign(b, { x: c.x, y: c.y, w: c.w, h: c.h });
    });
  });
}

// ── Render helpers ────────────────────────────────────────────
function renderAllBlocks() {
  // Destroy prior page widgets completely so their DOM doesn't linger and overlap.
  grid.removeAll(true);
  // Filter blocks for current page
  const pageBlocks = blocks.filter(b => (b.page || 1) === currentPage);
  // sort: pinned first
  [...pageBlocks].sort((a,b) => (b.pinned - a.pinned) || 0)
                 .forEach(addBlockToGrid);
  setupAllRefreshTimers();
  updatePageNav();
}

function addBlockToGrid(b) {
  const content = makeTileHTML(b);
  const el = grid.addWidget(`<div class="grid-stack-item" gs-x="${b.x}" gs-y="${b.y}" gs-w="${b.w}" gs-h="${b.h}" data-block-id="${b.id}"><div class="grid-stack-item-content">${content}</div></div>`);
  el.dataset.blockId = b.id;
  bindTileEvents(el, b.id);
}

function makeTileHTML(b) {
  const favicon = `https://www.google.com/s2/favicons?domain=${encodeURIComponent(new URL(b.url).hostname)}&sz=32`;
  const badges = `
    <div class="tile-badges">
      ${b.pinned  ? '<div class="badge pinned"><i class="fa fa-thumbtack"></i></div>' : ''}
      ${b.refresh ? '<div class="badge refresh"><i class="fa fa-clock-rotate-left"></i></div>' : ''}
    </div>`;
  return `
    <div class="tile" style="--tile-color:${b.color}">
      <div class="tile-bg"></div>
      ${badges}
      <div class="tile-body">
        <div class="tile-title">
          <img src="${favicon}" style="width:16px;height:16px;vertical-align:middle;margin-right:6px;border-radius:3px;" onerror="this.style.display='none'"/>
          ${escHtml(b.title)}
        </div>
        <div class="tile-url">${escHtml(b.url)}</div>
      </div>
    </div>`;
}

function refreshTileDOM(id) {
  const b = blockById(id);
  if (!b) return;
  const el = document.querySelector(`[data-block-id="${id}"]`);
  if (!el) return;
  el.querySelector(".grid-stack-item-content").innerHTML = makeTileHTML(b);
  bindTileEvents(el, id);
}

// ── Tile event binding ────────────────────────────────────────
function bindTileEvents(el, id) {
  const content = el.querySelector(".grid-stack-item-content");

  // left-click → open in new tab
  content.addEventListener("click", (e) => {
    if (e.button !== 0) return;
    const b = blockById(id);
    if (b) window.open(b.url, "_blank");
  });

  // right-click → context menu
  content.addEventListener("contextmenu", (e) => {
    e.preventDefault();
    ctxTargetId = id;
    showCtxMenu(e.clientX, e.clientY);
  });
}

// ── Viewer ────────────────────────────────────────────────────
function openViewer(id) {
  const b = blockById(id);
  if (!b) return;
  const viewer   = $("viewer");
  const iframe   = $("viewer-iframe");
  const blocked  = $("viewer-blocked");
  const title    = $("viewer-title");

  title.textContent = b.title;
  blocked.classList.add("hidden");
  iframe.classList.remove("hidden");
  iframe.src = b.url;
  viewer.classList.remove("hidden");
  viewer.dataset.currentId = id;
  viewer.dataset.currentUrl = b.url;

  // detect blocked iframe
  iframe.onload = () => {
    try {
      // if contentDocument is null or cross-origin throws, it loaded fine from our side
      void iframe.contentWindow.location.href;
    } catch (_) { /* cross-origin – normal */ }
  };
  iframe.onerror = () => {
    iframe.classList.add("hidden");
    blocked.classList.remove("hidden");
  };
}

function closeViewer() {
  const viewer = $("viewer");
  $("viewer-iframe").src = "about:blank";
  viewer.classList.add("hidden");
}

function bindViewer() {
  $("viewer-close").onclick = closeViewer;
  $("viewer-refresh").onclick = () => {
    const iframe = $("viewer-iframe");
    iframe.src = iframe.src; // reload
  };
  $("viewer-newtab").onclick = () => {
    window.open($("viewer").dataset.currentUrl, "_blank");
  };
  $("viewer-open-newtab").onclick = () => {
    window.open($("viewer").dataset.currentUrl, "_blank");
    closeViewer();
  };
}

// ── Context Menu ──────────────────────────────────────────────
function showCtxMenu(x, y) {
  const menu = $("ctx-menu");
  menu.classList.remove("hidden");
  // keep inside viewport
  const mw = 210, mh = 250;
  menu.style.left = (x + mw > window.innerWidth  ? x - mw : x) + "px";
  menu.style.top  = (y + mh > window.innerHeight ? y - mh : y) + "px";
}

function hideCtxMenu() {
  $("ctx-menu").classList.add("hidden");
}

function bindContextMenu() {
  $("ctx-menu").addEventListener("click", async (e) => {
    const li = e.target.closest("li[data-action]");
    if (!li) return;
    const action = li.dataset.action;
    const id = ctxTargetId;
    hideCtxMenu();

    if (action === "newtab")         window.open(blockById(id)?.url, "_blank");
    else if (action === "edit")      openEditModal(id);
    else if (action === "pin")       await togglePin(id);
    else if (action === "refresh-toggle") openRefreshModal(id);
    else if (action === "delete")    await deleteBlock(id);
  });

  document.addEventListener("click", hideCtxMenu);
  document.addEventListener("contextmenu", (e) => {
    if (!e.target.closest(".grid-stack-item-content")) hideCtxMenu();
  });
}

// ── Add / Edit Modal ──────────────────────────────────────────
function openEditModal(id = null) {
  editingId = id;
  const b = id ? blockById(id) : null;
  $("modal-title").textContent = id ? "編輯方塊" : "新增方塊";
  $("f-title").value   = b?.title   ?? "";
  $("f-url").value     = b?.url     ?? "";
  $("f-color").value   = b?.color   ?? "#4285f4";
  $("f-refresh").value = b?.refresh ?? 0;
  $("f-pinned").checked = b?.pinned ?? false;
  setActiveSwatch(b?.color ?? "#4285f4");
  $("modal-overlay").classList.remove("hidden");
  $("f-title").focus();
}

function closeEditModal() {
  $("modal-overlay").classList.add("hidden");
  editingId = null;
}

function bindModal() {
  $("btn-add").onclick = () => openEditModal(null);
  $("modal-close").onclick  = closeEditModal;
  $("modal-cancel").onclick = closeEditModal;

  $("btn-fetch-title").onclick = async () => {
    const url = $("f-url").value.trim();
    if (!url) return;
    $("btn-fetch-title").disabled = true;
    $("btn-fetch-title").textContent = "擷取中…";
    try {
      const {title} = await api.getMeta(url);
      $("f-title").value = title;
    } finally {
      $("btn-fetch-title").disabled = false;
      $("btn-fetch-title").innerHTML = '<i class="fa fa-wand-magic-sparkles"></i> 自動抓取標題';
    }
  };

  $("f-color").oninput = (e) => setActiveSwatch(e.target.value);

  $("block-form").addEventListener("submit", async (e) => {
    e.preventDefault();
    const payload = {
      title:   $("f-title").value.trim(),
      url:     $("f-url").value.trim(),
      color:   $("f-color").value,
      refresh: parseInt($("f-refresh").value) || 0,
      pinned:  $("f-pinned").checked
    };
    if (editingId) {
      const updated = await api.update(editingId, payload);
      const idx = blocks.findIndex(b => b.id === editingId);
      if (idx !== -1) blocks[idx] = { ...blocks[idx], ...updated };
      refreshTileDOM(editingId);
      setupRefreshTimer(editingId);
      toast("已儲存！");
    } else {
      const newBlock = await api.create({ ...payload, x:0, y:0, w:4, h:3, page: currentPage });
      blocks.push(newBlock);
      addBlockToGrid(newBlock);
      setupRefreshTimer(newBlock.id);
      toast("新增方塊成功！");
    }
    closeEditModal();
  });
}

// ── Refresh Modal ─────────────────────────────────────────────
function openRefreshModal(id) {
  const b = blockById(id);
  $("r-interval").value = b?.refresh ?? 0;
  $("refresh-modal").classList.remove("hidden");
  $("refresh-modal").dataset.targetId = id;
}

function bindContextMenu_refresh() {
  $("refresh-modal-close").onclick = () => $("refresh-modal").classList.add("hidden");
  $("refresh-cancel").onclick      = () => $("refresh-modal").classList.add("hidden");
  $("refresh-save").onclick = async () => {
    const id  = $("refresh-modal").dataset.targetId;
    const sec = parseInt($("r-interval").value) || 0;
    await api.update(id, { refresh: sec });
    const b = blockById(id);
    if (b) b.refresh = sec;
    refreshTileDOM(id);
    setupRefreshTimer(id);
    $("refresh-modal").classList.add("hidden");
    toast(sec ? `已設定每 ${sec} 秒更新` : "已關閉自動更新");
  };
}

// ── Auto-refresh timers ───────────────────────────────────────
function setupRefreshTimer(id) {
  if (refreshTimers[id]) clearInterval(refreshTimers[id]);
  const b = blockById(id);
  if (!b || !b.refresh) return;
  refreshTimers[id] = setInterval(() => {
    // If viewer is showing this block, reload the iframe
    const viewer = $("viewer");
    if (!viewer.classList.contains("hidden") && viewer.dataset.currentId === id) {
      const iframe = $("viewer-iframe");
      iframe.src = iframe.src;
    }
    // Optionally re-render badge (already there if refresh > 0)
  }, b.refresh * 1000);
}

function setupAllRefreshTimers() {
  blocks.forEach(b => setupRefreshTimer(b.id));
}

// ── Pin / delete ──────────────────────────────────────────────
async function togglePin(id) {
  const b = blockById(id);
  if (!b) return;
  const updated = await api.update(id, { pinned: !b.pinned });
  b.pinned = updated.pinned;
  refreshTileDOM(id);
  toast(b.pinned ? "已釘住" : "已取消釘住");
}

async function deleteBlock(id) {
  if (!confirm("確定刪除此方塊？")) return;
  await api.delete(id);
  blocks = blocks.filter(b => b.id !== id);
  const el = document.querySelector(`[data-block-id="${id}"]`);
  if (el) grid.removeWidget(el);
  if (refreshTimers[id]) { clearInterval(refreshTimers[id]); delete refreshTimers[id]; }
  toast("已刪除");
}

// ── Top bar ───────────────────────────────────────────────────
function bindTopBar() {
  $("btn-save-layout").onclick = async () => {
    const items = grid.engine.nodes.map(n => ({
      id: n.el.dataset.blockId, x: n.x, y: n.y, w: n.w, h: n.h
    }));
    await api.reorder(items);
    toast("排版已儲存！");
  };

  $("btn-toggle-edit").onclick = () => {
    editMode = !editMode;
    grid.setStatic(!editMode);
    const btn = $("btn-toggle-edit");
    btn.innerHTML = editMode
      ? '<i class="fa fa-lock-open"></i> 編輯中'
      : '<i class="fa fa-lock"></i> 鎖定';
    btn.classList.toggle("locked", !editMode);
  };
}

// ── Keyboard ──────────────────────────────────────────────────
function bindKeyboard() {
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
      closeViewer();
      hideCtxMenu();
      closeEditModal();
      $("refresh-modal").classList.add("hidden");
    }
  });
}

// ── Color swatches ────────────────────────────────────────────
function buildColorSwatches() {
  const container = $("color-swatches");
  PALETTE.forEach(c => {
    const div = document.createElement("div");
    div.className = "swatch";
    div.style.background = c;
    div.dataset.color = c;
    div.onclick = () => {
      $("f-color").value = c;
      setActiveSwatch(c);
    };
    container.appendChild(div);
  });
}

function setActiveSwatch(color) {
  document.querySelectorAll(".swatch").forEach(s => {
    s.classList.toggle("active", s.dataset.color === color);
  });
}

// ── Utilities ─────────────────────────────────────────────────
function $(id) { return document.getElementById(id); }

function blockById(id) { return blocks.find(b => b.id === id); }

function escHtml(str) {
  return String(str)
    .replace(/&/g,"&amp;").replace(/</g,"&lt;")
    .replace(/>/g,"&gt;").replace(/"/g,"&quot;");
}

let toastTimer = null;
function toast(msg) {
  const el = $("toast");
  el.textContent = msg;
  el.classList.remove("hidden");
  if (toastTimer) clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.add("hidden"), 2400);
}

// ── Page Navigation ───────────────────────────────────────────
function bindPageNav() {
  $("page-prev")?.addEventListener("click", () => {
    if (currentPage > 1) {
      currentPage--;
    } else {
      currentPage = 3; // Loop back to last page
    }
    renderAllBlocks();
  });

  $("page-next")?.addEventListener("click", () => {
    if (currentPage < 3) {
      currentPage++;
    } else {
      currentPage = 1; // Loop back to first page
    }
    renderAllBlocks();
  });
}

function updatePageNav() {
  const prevBtn = $("page-prev");
  const nextBtn = $("page-next");
  const pageInfo = $("page-info");
  
  if (!prevBtn || !nextBtn || !pageInfo) return;
  
  // Update page indicator
  const pageNames = { 1: "新聞", 2: "娛樂", 3: "科學" };
  pageInfo.textContent = pageNames[currentPage] || `第 ${currentPage} 頁`;
  
  // Always show both buttons for cycling navigation
  prevBtn.style.display = "flex";
  nextBtn.style.display = "flex";
  nextBtn.innerHTML = '<i class="fa fa-arrow-right"></i>';
  nextBtn.title = "下一頁";
}
