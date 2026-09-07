-- This is an index of book metadata only. The plugin never copies or parses
-- book content; it records the path, display metadata, series name and order.
local DATA_FILE = "series.idx"
local LEGACY_DATA_FILE = "series.tsv"

local function encode(value)
  value = tostring(value or "")
  return value:gsub("%%", "%%25"):gsub("\t", "%%09"):gsub("\r", "%%0D"):gsub("\n", "%%0A")
end

local function decode(value)
  return tostring(value or ""):gsub("%%0A", "\n"):gsub("%%0D", "\r"):gsub("%%09", "\t"):gsub("%%25", "%%")
end

local function load_records()
  local records = {}
  local text = inx.storage.read_all(DATA_FILE)
  if text == "" then text = inx.storage.read_all(LEGACY_DATA_FILE) end
  for line in text:gmatch("[^\r\n]+") do
    local path, title, author, series, order = line:match("^(.-)\t(.-)\t(.-)\t(.-)\t(.-)$")
    if path and path ~= "" and series and series ~= "" then
      records[#records + 1] = {path = decode(path), title = decode(title), author = decode(author), series = decode(series), order = tonumber(order) or 0}
    end
  end
  return records
end

local function save_records(records)
  local lines = {}
  for _, record in ipairs(records) do
    lines[#lines + 1] = table.concat({encode(record.path), encode(record.title), encode(record.author), encode(record.series), tostring(record.order or 0)}, "\t")
  end
  return inx.storage.write_text(DATA_FILE, table.concat(lines, "\n") .. (#lines > 0 and "\n" or ""))
end

local function json_string(value)
  value = tostring(value or "")
  return '"' .. value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\r", "\\r"):gsub("\n", "\\n") .. '"'
end

local function record_json(record)
  return "{" .. "\"path\":" .. json_string(record.path) .. "," .. "\"title\":" .. json_string(record.title) .. "," .. "\"author\":" .. json_string(record.author) .. "," .. "\"series\":" .. json_string(record.series) .. "," .. "\"order\":" .. tostring(record.order or 0) .. "}"
end

local function sort_records(records)
  table.sort(records, function(a, b)
    if a.series ~= b.series then return a.series < b.series end
    if a.order ~= b.order then return a.order < b.order end
    return a.title < b.title
  end)
end

function set_book(args)
  args = args or {}
  local path = tostring(args.path or "")
  local series = tostring(args.series or "")
  if path == "" then return "error" end
  local records = load_records()
  local found = false
  for index, record in ipairs(records) do
    if record.path == path then
      found = true
      if series == "" then
        table.remove(records, index)
      else
        record.title = tostring(args.title or record.title or "")
        record.author = tostring(args.author or record.author or "")
        record.series = series
        record.order = tonumber(args.order) or record.order or 0
      end
      break
    end
  end
  if not found and series ~= "" then
    records[#records + 1] = {path = path, title = tostring(args.title or ""), author = tostring(args.author or ""), series = series, order = tonumber(args.order) or 0}
  end
  return save_records(records) and "ok" or "error"
end

-- Update one series in a single write. The web editor sends the final order
-- and the paths removed from the series, so dragging several books does not
-- cause a request/write per row.
function save_series(args)
  args = args or {}
  local series = tostring(args.series or "")
  if series == "" then return "error" end

  local removed = {}
  for _, path in ipairs(args.remove or {}) do
    path = tostring(path or "")
    if path ~= "" then removed[path] = true end
  end

  local incoming = {}
  for _, book in ipairs(args.books or {}) do
    local path = tostring(book.path or "")
    if path ~= "" then
      incoming[path] = {
        title = tostring(book.title or ""),
        author = tostring(book.author or ""),
        order = tonumber(book.order) or 0,
      }
    end
  end

  local records = load_records()
  local updated = {}
  local found = {}
  for _, record in ipairs(records) do
    if removed[record.path] then
      -- Explicitly removed from the active series.
    elseif incoming[record.path] then
      local book = incoming[record.path]
      record.title = book.title ~= "" and book.title or record.title
      record.author = book.author ~= "" and book.author or record.author
      record.series = series
      record.order = book.order
      updated[#updated + 1] = record
      found[record.path] = true
    else
      updated[#updated + 1] = record
    end
  end

  for path, book in pairs(incoming) do
    if not found[path] then
      updated[#updated + 1] = {
        path = path,
        title = book.title,
        author = book.author,
        series = series,
        order = book.order,
      }
    end
  end
  return save_records(updated) and "ok" or "error"
end

function library_json()
  local records = load_records()
  sort_records(records)
  local result = {}
  for _, record in ipairs(records) do result[#result + 1] = record_json(record) end
  return "[" .. table.concat(result, ",") .. "]"
end

function next_book(args)
  args = args or {}
  local current_path = tostring(args.path or "")
  local records = load_records()
  sort_records(records)
  local current = nil
  for _, record in ipairs(records) do
    if record.path == current_path then current = record break end
  end
  if not current then return '{"path":""}' end
  local found_current = false
  for _, record in ipairs(records) do
    if record.series == current.series then
      if found_current then return record_json(record) end
      if record.path == current.path then found_current = true end
    end
  end
  return '{"path":""}'
end
