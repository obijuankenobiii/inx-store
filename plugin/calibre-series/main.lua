-- Calibre writes series metadata into the EPUB OPF as calibre:series and
-- calibre:series_index. The firmware passes the parsed metadata to this
-- plugin; this file only owns the small user-facing series index.
local DATA_FILE = "calibre-series.idx"

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
  for line in text:gmatch("[^\r\n]+") do
    local path, title, author, series, order, source = line:match("^(.-)\t(.-)\t(.-)\t(.-)\t(.-)\t(.-)$")
    if path and path ~= "" and series and series ~= "" then
      records[#records + 1] = {
        path = decode(path), title = decode(title), author = decode(author), series = decode(series),
        order = tonumber(order) or 0, source = source == "calibre" and "calibre" or "manual"
      }
    end
  end
  return records
end

local function save_records(records)
  local lines = {}
  for _, record in ipairs(records) do
    lines[#lines + 1] = table.concat({encode(record.path), encode(record.title), encode(record.author),
      encode(record.series), tostring(record.order or 0), record.source == "calibre" and "calibre" or "manual"}, "\t")
  end
  return inx.storage.write_text(DATA_FILE, table.concat(lines, "\n") .. (#lines > 0 and "\n" or ""))
end

local function record_json(record)
  local function json_string(value)
    value = tostring(value or "")
    return '"' .. value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\r", "\\r"):gsub("\n", "\\n") .. '"'
  end
  return "{" .. '"path":' .. json_string(record.path) .. ',"title":' .. json_string(record.title) ..
    ',"author":' .. json_string(record.author) .. ',"series":' .. json_string(record.series) ..
    ',"order":' .. tostring(record.order or 0) .. '}'
end

local function sort_records(records)
  table.sort(records, function(a, b)
    if a.series ~= b.series then return a.series < b.series end
    if a.order ~= b.order then return a.order < b.order end
    return a.title < b.title
  end)
end

local function import_calibre_books(args)
  local records = load_records()
  local by_path = {}
  for _, record in ipairs(records) do by_path[record.path] = record end
  local changed = false
  local present = {}

  for _, book in ipairs((args or {}).books or {}) do
    local path = tostring(book.path or "")
    if path ~= "" then
      present[path] = true
      local series = tostring(book.series or "")
      local record = by_path[path]
      if series ~= "" then
        local order = tonumber(book.series_index) or 0
        if not record then
          record = {path = path, title = tostring(book.title or ""), author = tostring(book.author or ""),
            series = series, order = order, source = "calibre"}
          records[#records + 1] = record
          by_path[path] = record
          changed = true
        elseif record.source == "calibre" and (record.series ~= series or record.order ~= order or
            record.title ~= tostring(book.title or record.title) or record.author ~= tostring(book.author or record.author)) then
          record.series = series
          record.order = order
          record.title = tostring(book.title or record.title)
          record.author = tostring(book.author or record.author)
          changed = true
        end
      elseif record and record.source == "calibre" then
        by_path[path] = nil
        for index, candidate in ipairs(records) do
          if candidate == record then table.remove(records, index) break end
        end
        changed = true
      end
    end
  end
  if changed then save_records(records) end
  return records
end

function library_json(args)
  local records = import_calibre_books(args)
  sort_records(records)
  local result = {}
  for _, record in ipairs(records) do result[#result + 1] = record_json(record) end
  return "[" .. table.concat(result, ",") .. "]"
end

function set_book(args)
  args = args or {}
  local path = tostring(args.path or "")
  local series = tostring(args.series or "")
  if path == "" then return "error" end
  local records = load_records()
  for index, record in ipairs(records) do
    if record.path == path then
      if series == "" then table.remove(records, index)
      else
        record.title = tostring(args.title or record.title or "")
        record.author = tostring(args.author or record.author or "")
        record.series = series
        record.order = tonumber(args.order) or record.order or 0
        record.source = "manual"
      end
      return save_records(records) and "ok" or "error"
    end
  end
  if series ~= "" then
    records[#records + 1] = {path = path, title = tostring(args.title or ""), author = tostring(args.author or ""),
      series = series, order = tonumber(args.order) or 0, source = "manual"}
  end
  return save_records(records) and "ok" or "error"
end

function next_book(args)
  args = args or {}
  local records = import_calibre_books(args)
  local current_path = tostring(args.path or "")
  sort_records(records)
  local current
  for _, record in ipairs(records) do if record.path == current_path then current = record break end end
  if not current then return '{"path":""}' end
  local found = false
  for _, record in ipairs(records) do
    if record.series == current.series then
      if found then return record_json(record) end
      if record.path == current.path then found = true end
    end
  end
  return '{"path":""}'
end
