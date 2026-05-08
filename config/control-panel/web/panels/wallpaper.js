let api, current = null, items = [];

function escapeHTML(s) {
  return s.replace(/[&<>"']/g, c => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  }[c]));
}

async function refresh() {
  const dirRes = await api.get("dir");
  document.getElementById("wp-dir").value = dirRes.path;
  current = (await api.get("current")).name;
  items = await api.get("list");
  renderGrid();
}

function renderGrid() {
  const grid = document.getElementById("wp-grid");
  grid.innerHTML = "";
  for (const it of items) {
    const card = document.createElement("button");
    card.className = "wp-card" + (it.name === current ? " active" : "");
    card.innerHTML = `<div class="wp-name">${escapeHTML(it.name)}</div>`;
    card.onclick = () => apply(it.name);
    grid.appendChild(card);
  }
}

async function apply(name) {
  try {
    await api.post("set", { name });
    current = name;
    api.notify(`Wallpaper set: ${name}`, "success");
    renderGrid();
  } catch (e) {
    api.notify("Failed: " + e.message, "error");
  }
}

async function setDir() {
  const path = document.getElementById("wp-dir").value;
  try {
    await api.post("dir", { path });
    api.notify("Source directory updated", "success");
    refresh();
  } catch (e) {
    api.notify("Failed: " + e.message, "error");
  }
}

export default {
  id: "wallpaper",
  title: "Wallpaper",
  icon: "🖼️",
  order: 20,
  mount(root, _api) {
    api = _api;
    root.innerHTML = `
      <h2 class="panel-h2">Wallpaper</h2>
      <div class="wp-dir-row">
        <label for="wp-dir">Source folder</label>
        <input id="wp-dir" />
        <button id="wp-dir-set">Set</button>
      </div>
      <div id="wp-grid"></div>
      <style>
        .wp-dir-row { display: flex; gap: 8px; align-items: center;
                      margin-bottom: 16px; }
        .wp-dir-row input { flex: 1; }
        #wp-grid { display: grid; gap: 10px;
                   grid-template-columns: repeat(auto-fill,
                                                  minmax(180px, 1fr)); }
        .wp-card { background: var(--bg-alt); border: 1px solid transparent;
                   color: var(--fg); padding: 10px; border-radius: 8px;
                   cursor: pointer; text-align: left; }
        .wp-card:hover { border-color: var(--accent); }
        .wp-card.active { border-color: var(--accent); background: var(--accent);
                          color: var(--bg); }
        .wp-name { font-size: 12px; word-break: break-all; }
      </style>`;
    document.getElementById("wp-dir-set").onclick = setDir;
    refresh();
  },
  unmount() { items = []; current = null; },
};
