-- Study Cards is intentionally a Lua plugin. The firmware supplies only the
-- Lua VM and generic storage bridge; card creation and exports live here.
local function html_escape(value)
  value = tostring(value or "")
  value = value:gsub("&", "&amp;")
  value = value:gsub("<", "&lt;")
  value = value:gsub(">", "&gt;")
  value = value:gsub('"', "&quot;")
  return value
end

local function anki_field(value)
  value = html_escape(value)
  value = value:gsub("\t", " ")
  value = value:gsub("\r\n", "<br>"):gsub("\n", "<br>"):gsub("\r", "<br>")
  return value
end

local function json_escape(value)
  value = tostring(value or "")
  value = value:gsub("\\", "\\\\")
  value = value:gsub('"', '\\"')
  value = value:gsub("\r", "\\r")
  value = value:gsub("\n", "\\n")
  value = value:gsub("\t", "\\t")
  return value
end

-- Answers are kept in a sidecar file so old cards.jsonl files remain valid.
-- Hex encoding keeps every UTF-8 byte, including tabs and line breaks, safe in
-- the one-record-per-line storage format.
local function hex_encode(value)
  local encoded = {}
  for index = 1, #value do
    encoded[#encoded + 1] = string.format("%02x", string.byte(value, index))
  end
  return table.concat(encoded)
end

local function hex_decode(value)
  local decoded = {}
  for index = 1, #value, 2 do
    local byte = tonumber(value:sub(index, index + 1), 16)
    if not byte then return "" end
    decoded[#decoded + 1] = string.char(byte)
  end
  return table.concat(decoded)
end

local function read_answers()
  local answers = {}
  for line in inx.storage.read_all("answers.tsv"):gmatch("[^\r\n]+") do
    local index, value = line:match("^(%d+)\t(.*)$")
    if index and value then answers[tonumber(index)] = hex_decode(value) end
  end
  return answers
end

local function write_answers(answers)
  local indexes = {}
  for index in pairs(answers) do indexes[#indexes + 1] = index end
  table.sort(indexes)
  local lines = {}
  for _, index in ipairs(indexes) do
    lines[#lines + 1] = tostring(index) .. "\t" .. hex_encode(answers[index])
  end
  local contents = table.concat(lines, "\n")
  if #contents > 0 then contents = contents .. "\n" end
  return inx.storage.write_text("answers.tsv", contents)
end

local function card_line_with_answer(line, answer)
  local field = '"back":"' .. json_escape(answer) .. '"'
  local replaced = line:gsub('"back":"[^"]*"', function() return field end, 1)
  if replaced ~= line then return replaced end
  local closing = line:sub(-1) == "}" and #line - 1 or #line
  return line:sub(1, closing) .. ',"back":"' .. json_escape(answer) .. '"}'
end

function add_card(card)
  local saved = {
    id = tostring(card.timestamp or 0) .. "-" .. tostring(math.random(0, 2147483647)),
    front = card.selected_text or "",
    back = "",
    context = card.selection_context or card.selected_text or "",
    book = card.book_title or "",
    chapter = card.chapter_title or "",
    tags = "inx study",
    page = card.page_number or 0,
    spine = card.spine_index or 0,
    created = card.timestamp or 0
  }
  local anki = anki_field(saved.front) .. "\t" .. anki_field(saved.back) .. "\t" .. anki_field(saved.tags) .. "\n"
  return inx.storage.append_json("cards.jsonl", saved) and inx.storage.append_text("cards.anki", anki)
end

function cards_json()
  local lines = {}
  local answers = read_answers()
  local index = 0
  for line in inx.storage.read_all("cards.jsonl"):gmatch("[^\r\n]+") do
    index = index + 1
    if answers[index] then line = card_line_with_answer(line, answers[index]) end
    lines[#lines + 1] = line
  end
  return '{"ok":true,"cards":[' .. table.concat(lines, ",") .. ']}'
end

function export_json()
  return cards_json()
end

function export_anki()
  local answers = read_answers()
  local output = {"#separator:Tab", "#html:true", "#tags column:3"}
  local index = 0
  for line in inx.storage.read_all("cards.anki"):gmatch("[^\r\n]+") do
    index = index + 1
    local front, oldBack, tags = line:match("^([^\t]*)\t([^\t]*)\t(.*)$")
    if front and tags then
      local back = answers[index] and anki_field(answers[index]) or oldBack
      output[#output + 1] = front .. "\t" .. back .. "\t" .. tags
    else
      output[#output + 1] = line
    end
  end
  return table.concat(output, "\n") .. "\n"
end

function set_answer(args)
  local index = tonumber(args and args.index)
  if not index or index < 1 or index % 1 ~= 0 then return '{"ok":false,"error":"Invalid card index"}' end
  local answer = tostring(args and args.answer or "")
  local answers = read_answers()
  if #answer == 0 then
    answers[index] = nil
  else
    answers[index] = answer
  end
  if not write_answers(answers) then return '{"ok":false,"error":"Could not save answer"}' end
  return '{"ok":true}'
end
