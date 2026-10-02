local DATA_FILE = "presets.tsv"

local function encode(value)
  value = tostring(value or "")
  return value:gsub("%%", "%%25"):gsub("\t", "%%09"):gsub("\r", "%%0D"):gsub("\n", "%%0A")
end

local function decode(value)
  return tostring(value or ""):gsub("%%0A", "\n"):gsub("%%0D", "\r"):gsub("%%09", "\t"):gsub("%%25", "%%")
end

local function json_string(value)
  value = tostring(value or "")
  return '"' .. value:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\r", "\\r"):gsub("\n", "\\n") .. '"'
end

local function load_presets()
  local result = {}
  for line in inx.storage.read_all(DATA_FILE):gmatch("[^\r\n]+") do
    local name, options = line:match("^(.-)\t(.*)$")
    if name and name ~= "" and options and options ~= "" then
      result[#result + 1] = {name = decode(name), options = decode(options)}
    end
  end
  return result
end

local function save_presets(presets)
  local lines = {}
  for _, preset in ipairs(presets) do
    lines[#lines + 1] = encode(preset.name) .. "\t" .. encode(preset.options)
  end
  return inx.storage.write_text(DATA_FILE, table.concat(lines, "\n") .. (#lines > 0 and "\n" or ""))
end

function list_presets()
  local result = {}
  for _, preset in ipairs(load_presets()) do
    result[#result + 1] = "{" .. "\"name\":" .. json_string(preset.name) .. ",\"options\":" .. preset.options .. "}"
  end
  return "[" .. table.concat(result, ",") .. "]"
end

function save_preset(args)
  args = args or {}
  local name = tostring(args.name or "")
  local options = tostring(args.options or "")
  if name == "" or options == "" or #name > 48 or #options > 4096 then return "{\"ok\":false,\"error\":\"Invalid preset\"}" end
  local presets = load_presets()
  local replaced = false
  for _, preset in ipairs(presets) do
    if preset.name == name then preset.options = options; replaced = true end
  end
  if not replaced then presets[#presets + 1] = {name = name, options = options} end
  return save_presets(presets) and "{\"ok\":true}" or "{\"ok\":false,\"error\":\"Could not save preset\"}"
end

function delete_preset(args)
  local name = tostring((args or {}).name or "")
  local kept = {}
  for _, preset in ipairs(load_presets()) do
    if preset.name ~= name then kept[#kept + 1] = preset end
  end
  return save_presets(kept) and "{\"ok\":true}" or "{\"ok\":false,\"error\":\"Could not delete preset\"}"
end
