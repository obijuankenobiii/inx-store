let indexedBooks = [];
let assignments = [];
let activeSeries = "";
let draftBooks = [];
let dirty = false;
let draggedPath = "";

const $ = id => document.getElementById(id);
function esc(value) { return String(value || "").replace(/[&<>\"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;"}[c])); }
function api(path, init) {
  return fetch(path, init).then(async response => {
    const text = await response.text();
    if (!response.ok) { const error = new Error(text || "Request failed"); error.status = response.status; throw error; }
    return text;
  });
}
function setStatus(message) { $("status").textContent = message; }
let toastTimer = 0;
function showToast(message) {
  const toast = $("toast");
  toast.textContent = message;
  toast.classList.add("visible");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove("visible"), 2200);
}
function names() { return [...new Set(assignments.map(item => item.series).filter(Boolean))].sort((a, b) => a.localeCompare(b)); }
function assignmentFor(path) { return assignments.find(item => item.path === path) || {}; }
function bookFor(path) { return indexedBooks.find(item => item.path === path) || assignmentFor(path) || {path, name:path}; }
function cover(book) { return book.coverUrl ? `<img src="${esc(book.coverUrl)}" alt="">` : esc((book.name || book.title || "?").slice(0, 1).toUpperCase()); }
function draftHas(path) { return draftBooks.some(book => book.path === path); }
function dragPath(event) { return event.dataTransfer?.getData("text/plain") || draggedPath; }
function beginDrag(event, row) {
  draggedPath = row.dataset.path;
  row.classList.add("dragging");
  if (event.dataTransfer) {
    event.dataTransfer.setData("text/plain", draggedPath);
    event.dataTransfer.effectAllowed = "move";
  }
}
function endDrag(row) {
  row.classList.remove("dragging");
  draggedPath = "";
}

function renderSeriesSelect() {
  const select = $("series-select");
  const options = names();
  if (activeSeries && !options.includes(activeSeries)) options.push(activeSeries);
  select.innerHTML = options.length ? options.map(name => `<option value="${esc(name)}">${esc(name)}</option>`).join("") : `<option value="">No series yet</option>`;
  select.value = options.includes(activeSeries) ? activeSeries : "";
}

function startSeries(name) {
  activeSeries = name;
  draftBooks = assignments.filter(item => item.series === name)
    .sort((a, b) => (Number(a.order) || 0) - (Number(b.order) || 0))
    .map(item => ({path:item.path, title:item.title || "", author:item.author || ""}));
  dirty = false;
  render();
}

function renderAvailable() {
  const query = $("book-search").value.trim().toLowerCase();
  const list = indexedBooks.filter(book => {
    const text = `${book.name || ""} ${book.title || ""} ${book.author || ""} ${book.path || ""}`.toLowerCase();
    return !query || text.includes(query);
  });
  $("book-count").textContent = ` · ${indexedBooks.length} books`;
  const host = $("available-books");
  if (!list.length) { host.innerHTML = `<div class="series-empty">No matching books.</div>`; return; }
  host.innerHTML = list.map(book => {
    const added = draftHas(book.path);
    const assignment = assignmentFor(book.path);
    const meta = added ? "In this series" : (assignment.series ? `In ${esc(assignment.series)}` : "Not in a series");
    return `<div class="book-item${added ? " added" : ""}" draggable="true" data-path="${esc(book.path)}"><div class="book-cover">${cover(book)}</div><div class="book-copy"><strong>${esc(book.name || book.title || book.path)}</strong><small>${meta}</small></div><button class="book-add" type="button" data-add="${esc(book.path)}" aria-label="Add book">+</button></div>`;
  }).join("");
  host.querySelectorAll(".book-item").forEach(row => {
    row.addEventListener("dragstart", event => beginDrag(event, row));
    row.addEventListener("dragend", () => endDrag(row));
  });
  host.querySelectorAll("[data-add]").forEach(button => button.addEventListener("click", () => addBook(button.dataset.add)));
}

function renderSeriesBooks(animate = false) {
  const host = $("series-book-list");
  const previousPositions = animate
    ? new Map([...host.querySelectorAll(".series-item")].map(row => [row.dataset.path, row.getBoundingClientRect().top]))
    : null;
  $("active-series-name").textContent = activeSeries || "Choose or create a series";
  if (!activeSeries) { host.innerHTML = `<div class="series-empty">Choose an existing series or create one, then drag books here.</div>`; return; }
  if (!draftBooks.length) { host.innerHTML = `<div class="series-empty">Drop books here to build this series.</div>`; return; }
  host.innerHTML = draftBooks.map((book, index) => {
    const info = bookFor(book.path);
    return `<div class="series-item" draggable="true" data-path="${esc(book.path)}"><span class="series-order">${index + 1}</span><div class="book-cover">${cover(info)}</div><div class="book-copy"><strong>${esc(info.name || info.title || book.title || book.path)}</strong><small>${esc(info.author || book.author || info.path)}</small></div><button class="book-remove" type="button" data-remove="${esc(book.path)}" aria-label="Remove book">×</button></div>`;
  }).join("");
  host.querySelectorAll(".series-item").forEach(row => {
    row.addEventListener("dragstart", event => beginDrag(event, row));
    row.addEventListener("dragend", () => endDrag(row));
    row.addEventListener("dragenter", event => { event.preventDefault(); if (event.dataTransfer) event.dataTransfer.dropEffect = "move"; row.classList.add("dragover"); });
    row.addEventListener("dragover", event => { event.preventDefault(); if (event.dataTransfer) event.dataTransfer.dropEffect = "move"; row.classList.add("dragover"); });
    row.addEventListener("dragleave", () => row.classList.remove("dragover"));
    row.addEventListener("drop", event => {
      event.preventDefault();
      event.stopPropagation();
      row.classList.remove("dragover");
      dropBook(dragPath(event), draftBooks.findIndex(book => book.path === row.dataset.path));
    });
  });
  host.querySelectorAll("[data-remove]").forEach(button => button.addEventListener("click", () => removeBook(button.dataset.remove)));
  if (previousPositions) {
    requestAnimationFrame(() => {
      host.querySelectorAll(".series-item").forEach(row => {
        const previousTop = previousPositions.get(row.dataset.path);
        if (previousTop === undefined) return;
        const offset = previousTop - row.getBoundingClientRect().top;
        if (!offset) return;
        row.style.transition = "none";
        row.style.transform = `translateY(${offset}px)`;
        requestAnimationFrame(() => {
          row.style.transition = "transform .18s ease";
          row.style.transform = "";
        });
      });
    });
  }
}

function render(animate = false) {
  renderSeriesSelect();
  renderAvailable();
  renderSeriesBooks(animate);
  $("save-series").disabled = !activeSeries || !dirty;
}

function addBook(path, index = draftBooks.length) {
  if (!path || !activeSeries || draftHas(path)) return;
  const info = bookFor(path);
  draftBooks.splice(Math.max(0, index), 0, {path, title:info.title || info.name || "", author:info.author || ""});
  dirty = true;
  render();
}

function dropBook(path, index) {
  if (!path || !activeSeries) return;
  const oldIndex = draftBooks.findIndex(book => book.path === path);
  if (oldIndex >= 0) {
    const [book] = draftBooks.splice(oldIndex, 1);
    // `index` is the target's original index. Keeping it unchanged means a
    // downward move inserts after the target once the dragged item is removed,
    // while an upward move inserts before it.
    draftBooks.splice(Math.max(0, index), 0, book);
  } else {
    addBook(path, index);
    return;
  }
  dirty = true;
  render(true);
}

function removeBook(path) {
  draftBooks = draftBooks.filter(book => book.path !== path);
  dirty = true;
  render();
}

async function saveSeries() {
  if (!activeSeries || !dirty) return;
  const current = new Set(draftBooks.map(book => book.path));
  const remove = assignments.filter(item => item.series === activeSeries && !current.has(item.path)).map(item => item.path);
  const books = draftBooks.map((book, index) => {
    const info = bookFor(book.path);
    return {path:book.path, title:info.title || info.name || book.title || "", author:info.author || book.author || "", order:index + 1};
  });
  setStatus("Saving series…");
  try {
    await api("/api/plugin/series/save_series", {method:"POST", headers:{"Content-Type":"application/json"}, body:JSON.stringify({series:activeSeries, books, remove})});
    assignments = JSON.parse(await api("/api/plugin/series/library_json"));
    dirty = false;
    render();
    setStatus("Series saved.");
    showToast("Series created");
  } catch (error) { setStatus(error.message); }
}

async function loadIndex() {
  indexedBooks = JSON.parse(await api("/api/library-index"));
  $("index-state").classList.remove("visible");
  $("workspace").classList.remove("hidden");
}

async function load() {
  try {
    setStatus("Loading library index…");
    assignments = JSON.parse(await api("/api/plugin/series/library_json"));
    await loadIndex();
    const available = names();
    if (!available.includes(activeSeries)) activeSeries = available[0] || "";
    startSeries(activeSeries);
    setStatus(available.length ? "Drag books into a series, reorder them, then save once." : "Create a series to begin.");
  } catch (error) {
    if (error.status === 404) {
      $("workspace").classList.add("hidden");
      $("index-state").classList.add("visible");
      setStatus("The library index is not available.");
    } else setStatus(error.message);
  }
}

async function refreshIndex() {
  const button = $("refresh-index");
  button.disabled = true;
  setStatus("Building library index…");
  try { await api("/api/library-index/refresh", {method:"POST"}); } catch (error) { if (error.status !== 409) { setStatus(error.message); button.disabled = false; return; } }
  for (let attempt = 0; attempt < 90; attempt += 1) {
    await new Promise(resolve => setTimeout(resolve, 800));
    try {
      const status = JSON.parse(await api("/api/library-index/status"));
      if (status.available && !status.refreshing) { button.disabled = false; await load(); return; }
    } catch (_) {}
  }
  button.disabled = false;
  setStatus("Library index refresh is still running. Tap again when it finishes.");
}

$("series-select").addEventListener("change", event => {
  if (dirty && !window.confirm("Discard unsaved series changes?")) { event.target.value = activeSeries; return; }
  startSeries(event.target.value);
});
$("new-series").addEventListener("click", () => {
  const name = $("new-series-name").value.trim();
  if (!name) { setStatus("Enter a series name first."); $("new-series-name").focus(); return; }
  activeSeries = name;
  draftBooks = [];
  dirty = true;
  $("new-series-name").value = "";
  render();
  setStatus(`“${name}” is ready. Drag books into it, then save once.`);
});
$("new-series-name").addEventListener("keydown", event => { if (event.key === "Enter") $("new-series").click(); });
$("save-series").addEventListener("click", saveSeries);
$("refresh").addEventListener("click", load);
$("refresh-index").addEventListener("click", refreshIndex);
$("book-search").addEventListener("input", renderAvailable);
$("books-toggle").addEventListener("click", event => {
  const panel = $("books-panel");
  const collapsed = panel.classList.toggle("books-collapsed");
  event.currentTarget.setAttribute("aria-expanded", String(!collapsed));
  event.currentTarget.textContent = collapsed ? "Show books" : "Collapse";
});
$("series-books").addEventListener("dragover", event => { event.preventDefault(); $("series-books").classList.add("dragover"); });
$("series-books").addEventListener("dragleave", event => { if (event.target === $("series-books")) $("series-books").classList.remove("dragover"); });
$("series-books").addEventListener("drop", event => { event.preventDefault(); $("series-books").classList.remove("dragover"); const path = dragPath(event); if (path) dropBook(path, draftBooks.length); });
load();
