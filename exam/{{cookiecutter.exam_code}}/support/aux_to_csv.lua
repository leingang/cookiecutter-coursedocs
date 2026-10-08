local aux_to_csv = {}

local function trim_trailing_zeros(value)
  local formatted = string.format("%.10f", value)
  formatted = formatted:gsub("(%..-)0+$", "%1")
  formatted = formatted:gsub("%.$", "")
  if not formatted:find("%.") then
    formatted = formatted .. ".0"
  end
  return formatted
end

local function roman_to_int(roman)
  local values = {
    i = 1,
    v = 5,
    x = 10,
    l = 50,
    c = 100,
    d = 500,
    m = 1000,
  }
  local total = 0
  local previous = 0
  for index = #roman, 1, -1 do
    local symbol = roman:sub(index, index):lower()
    local value = values[symbol]
    if not value then
      return nil, "invalid roman numeral: " .. roman
    end
    if value < previous then
      total = total - value
    else
      total = total + value
      previous = value
    end
  end
  return total
end

function aux_to_csv.parse_aux_file(aux_path)
  local handle, open_error = io.open(aux_path, "r")
  if not handle then
    return nil, string.format("could not open aux file '%s': %s", aux_path, open_error or "unknown error")
  end

  local answers = {}
  local points = {}

  for line in handle:lines() do
    local question_number, answer_letter = line:match("\\newlabel{question@(%d+)@correctchoice}{{([A-E])}")
    if question_number and answer_letter then
      answers[tonumber(question_number)] = answer_letter
    end

    local roman_question, point_value = line:match("\\gdef\\pointsofq@([ivxlcdm]+){([%d%.]+)}")
    if roman_question and point_value then
      local question_index = roman_to_int(roman_question)
      if question_index then
        points[question_index] = tonumber(point_value)
      end
    end
  end

  handle:close()
  return {
    answers = answers,
    points = points,
  }
end

function aux_to_csv.write_csv(parsed, csv_path)
  local handle, open_error = io.open(csv_path, "w")
  if not handle then
    return nil, string.format("could not open csv file '%s': %s", csv_path, open_error or "unknown error")
  end

  handle:write("Question,Answers,Points,Type\n")

  local question_numbers = {}
  for question_number in pairs(parsed.answers) do
    question_numbers[#question_numbers + 1] = question_number
  end
  table.sort(question_numbers)

  for _, question_number in ipairs(question_numbers) do
    local point_value = parsed.points[question_number] or 0
    local row = string.format(
      "%d,%s,%s,Exact\n",
      question_number,
      parsed.answers[question_number],
      trim_trailing_zeros(point_value)
    )
    handle:write(row)
  end

  handle:close()
  return true
end

function aux_to_csv.convert(aux_path, csv_path)
  local parsed, parse_error = aux_to_csv.parse_aux_file(aux_path)
  if not parsed then
    return nil, parse_error
  end

  return aux_to_csv.write_csv(parsed, csv_path)
end

function aux_to_csv.register_for_job(jobname)
  local aux_path = jobname .. ".aux"
  local csv_path = jobname .. ".csv"
  local callback_name = "aux_to_csv_stop_run"

  luatexbase.add_to_callback("stop_run", function()
    local ok, convert_error = aux_to_csv.convert(aux_path, csv_path)
    if not ok then
      texio.write_nl("term and log", "aux_to_csv: " .. convert_error)
      return
    end
    texio.write_nl("term and log", "aux_to_csv: wrote " .. csv_path)
  end, callback_name)
end

if arg and arg[0] and arg[0]:match("aux_to_csv%.lua$") then
  local aux_path = arg[1]
  local csv_path = arg[2]
  if not aux_path or not csv_path then
    io.stderr:write("usage: texlua aux_to_csv.lua INPUT.aux OUTPUT.csv\n")
    os.exit(1)
  end

  local ok, convert_error = aux_to_csv.convert(aux_path, csv_path)
  if not ok then
    io.stderr:write(convert_error .. "\n")
    os.exit(1)
  end
end

return aux_to_csv
