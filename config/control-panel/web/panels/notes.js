const fmtTime = (epoch) => {
  const d = new Date(epoch * 1000);
  return d.toLocaleString();
};

let state = { notes: [], selected: null, dirty: false, saveTimer: null };
let api;

function escapeHTML(s) {
  return s.replace(/[&<>"']/g, c => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  }[c]));
}

async function refreshList() {
  state.notes = await api.get("list");
  renderList();
}

function renderList() {
  const list = document.getElementById("notes-list");
  if (!list) return;
  list.innerHTML = "";
  for (const n of state.notes) {
    const li = document.createElement("li");
    li.className = "notes-item" + (n.id === state.selected ? " active" : "");
    li.innerHTML = `<div class="notes-title">${
      escapeHTML(n.title)
    }</div><div class="notes-mtime">${fmtTime(n.mtime)}</div>`;
    li.onclick = () => loadNote(n.id);
    list.appendChild(li);
  }
}

async function loadNote(id) {
  if (state.dirty && !confirm("Discard unsaved changes?")) return;
  if (id === null) {
    state.selected = null;
    document.getElementById("notes-title").value = "";
    document.getElementById("notes-body").value = "";
  } else {
    const n = await api.get(`get/${id}`);
    state.selected = id;
    document.getElementById("notes-title").value = n.title;
    document.getElementById("notes-body").value = n.body;
  }
  state.dirty = false;
  renderList();
}

async function save() {
  const title = document.getElementById("notes-title").value;
  const body = document.getElementById("notes-body").value;
  const payload = { title, body };
  if (state.selected) payload.id = state.selected;
  const res = await api.post("save", payload);
  state.selected = res.id;
  state.dirty = false;
  api.notify("Saved", "success");
  await refreshList();
}

async function del() {
  if (!state.selected) return;
  if (!await api.confirm("Delete this note?")) return;
  await api.post(`delete/${state.selected}`, {});
  state.selected = null;
  document.getElementById("notes-title").value = "";
  document.getElementById("notes-body").value = "";
  state.dirty = false;
  await refreshList();
}

function scheduleSave() {
  state.dirty = true;
  if (state.saveTimer) clearTimeout(state.saveTimer);
  state.saveTimer = setTimeout(() => save().catch(e =>
    api.notify("Save failed: " + e.message, "error")
  ), 1000);
}

function keydown(e) {
  if (e.ctrlKey && e.key === "s") {
    e.preventDefault();
    save().catch(err => api.notify("Save failed: " + err.message, "error"));
  }
}

export default {
  id: "notes",
  title: "Notes",
  icon: "📝",
  order: 10,
  mount(root, _api) {
    api = _api;
    root.innerHTML = `
      <h2 class="panel-h2">Notes</h2>
      <div class="notes-grid">
        <div class="notes-side">
          <div class="notes-actions">
            <button id="notes-new">New</button>
            <button id="notes-save" class="ghost">Save</button>
            <button id="notes-delete" class="ghost">Delete</button>
          </div>
          <ul id="notes-list"></ul>
        </div>
        <div class="notes-edit">
          <input id="notes-title" placeholder="Title" />
          <textarea id="notes-body" placeholder="Body…"></textarea>
        </div>
      </div>
      <style>
        .notes-grid { display: grid; grid-template-columns: 280px 1fr;
                      gap: 16px; }
        .notes-actions { display: flex; gap: 6px; margin-bottom: 10px; }
        ul#notes-list { list-style: none; padding: 0; margin: 0;
                        display: flex; flex-direction: column; gap: 4px; }
        .notes-item { padding: 8px 10px; border-radius: 6px;
                      background: var(--bg-alt); cursor: pointer; }
        .notes-item.active { background: var(--accent); color: var(--bg); }
        .notes-title { font-weight: bold; }
        .notes-mtime { font-size: 11px; color: var(--muted); }
        .notes-item.active .notes-mtime { color: var(--bg); opacity: 0.7; }
        .notes-edit { display: flex; flex-direction: column; gap: 8px; }
        #notes-body { min-height: 380px; font-family: monospace; }
      </style>`;

    document.getElementById("notes-new").onclick = () => loadNote(null);
    document.getElementById("notes-save").onclick = () =>
      save().catch(e => api.notify("Save failed: " + e.message, "error"));
    document.getElementById("notes-delete").onclick = () =>
      del().catch(e => api.notify("Delete failed: " + e.message, "error"));
    document.getElementById("notes-title").addEventListener(
      "input", scheduleSave);
    document.getElementById("notes-body").addEventListener(
      "input", scheduleSave);
    window.addEventListener("keydown", keydown);
    refreshList();
  },
  unmount(root) {
    if (state.saveTimer) clearTimeout(state.saveTimer);
    state = { notes: [], selected: null, dirty: false, saveTimer: null };
    window.removeEventListener("keydown", keydown);
  },
};
