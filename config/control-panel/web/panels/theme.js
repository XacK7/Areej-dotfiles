let api, current = null, presets = [];

async function refresh() {
  presets = await api.get("list");
  current = (await api.get("current")).name;
  render();
}

function render() {
  const grid = document.getElementById("theme-grid");
  grid.innerHTML = "";
  for (const p of presets) {
    const card = document.createElement("button");
    card.className = "theme-card" + (p.name === current ? " active" : "");
    const swatches = ["bg", "bg_alt", "fg", "accent", "accent_2",
                      "ok", "muted"]
      .map(slot => `<span class="swatch" style="background:${
        p.colors[slot]
      }"></span>`).join("");
    card.innerHTML = `<div class="swatches">${
      swatches}</div><div class="theme-label">${
      p.label}</div>`;
    card.onclick = () => apply(p.name);
    grid.appendChild(card);
  }
}

async function apply(name) {
  try {
    await api.post("apply", { name });
    current = name;
    api.notify(`Applied: ${name}`, "success");
    render();
  } catch (e) { api.notify("Failed: " + e.message, "error"); }
}

async function revert() {
  try {
    const res = await api.post("revert", {});
    current = res.name;
    api.notify(`Reverted to: ${current}`, "success");
    render();
  } catch (e) { api.notify("Revert failed: " + e.message, "error"); }
}

export default {
  id: "theme",
  title: "Theme",
  icon: "🎨",
  order: 30,
  mount(root, _api) {
    api = _api;
    root.innerHTML = `
      <h2 class="panel-h2">Color Theme</h2>
      <p>Pick a palette. Applies to rofi, waybar, mako, foot.
         Already-open foot windows keep their old colors.</p>
      <div id="theme-grid"></div>
      <div style="margin-top:16px;">
        <button id="theme-revert" class="ghost">Revert last apply</button>
      </div>
      <style>
        #theme-grid { display: grid; gap: 12px;
                      grid-template-columns: repeat(auto-fill,
                                                     minmax(220px, 1fr)); }
        .theme-card { background: var(--bg-alt); color: var(--fg);
                      border: 2px solid transparent; border-radius: 10px;
                      padding: 14px; cursor: pointer; text-align: left; }
        .theme-card:hover { border-color: var(--accent); }
        .theme-card.active { border-color: var(--accent); }
        .swatches { display: flex; gap: 4px; margin-bottom: 8px; }
        .swatch { width: 20px; height: 20px; border-radius: 50%;
                  border: 1px solid rgba(255,255,255,0.1); }
        .theme-label { font-weight: bold; }
      </style>`;
    document.getElementById("theme-revert").onclick = revert;
    refresh();
  },
  unmount() { presets = []; current = null; },
};
