local function create_server(host, port, on_connect)
  local server = vim.loop.new_tcp()
  server:bind(host, port)
  server:listen(128, function(err)
    assert(not err, err)  -- Check for errors.
    local sock = vim.loop.new_tcp()
    server:accept(sock)  -- Accept client connection.
    on_connect(sock)  -- Start reading messages.
  end)
  return server
end

local function process(message) 
  local data = vim.api.nvim_call_function("json_decode", {message})
  local languages = data["languages"]
  local lang_java = languages["java"]
  local task_name = lang_java["taskClass"]

  -- save json to local
  local data_file = assert(io.open(task_name .. ".json", "w"))
  data_file:write(message)
  data_file:close()

  local task_file_name = task_name .. ".cpp"  
  local task_file = assert(io.open(task_file_name, "w"))
  task_file:close()

  -- open new buffer for this task
  vim.api.nvim_command("e " .. task_file_name)
end

local function parse()
  local server = create_server("127.0.0.1", 1327, function(sock)
    local message = ""
    sock:read_start(function(err, chunk)
      assert(not err, err)  -- Check for errors.
      if chunk then
        message = message .. chunk
      else  -- EOF (stream closed).
        sock:close()  -- Always close handles to avoid leaks.
        local lines = {}
        for line in string.gmatch(message, "[^\r\n]+") do
          table.insert(lines, line)
        end
        message = lines[#lines]
        vim.schedule(function()
          process(message)
        end)
      end
    end)
  end)
end

local function trim(s)
  return s:match"^%s*(.*%S)" or ""
end

local function build(str)
  local build_option = ""
  if str == nil or str == "" then
    build_option = "g++" -- default build option
  else
    build_option = str
  end
  vim.api.nvim_command("w") -- save buffer
  local task_name = vim.api.nvim_call_function("expand", {"%:r"}) -- current file name without extension
  local task_file_name = task_name .. ".cpp"
  local submit_file_name = "submit.cpp" -- submit file to judge
  os.execute("cp " .. task_file_name .. " " .. submit_file_name)

  local message = vim.api.nvim_call_function("system", {build_option ..
  " " .. task_file_name ..
  " -o " ..
  task_name})

  local response_code = vim.api.nvim_call_function("eval", {"v:shell_error"})

  print(build_option 
  .. " "
  .. task_file_name 
  .. " -o " 
  .. task_name)

  if response_code == 0 then
    print("Build successful")
  else
    print(message)
  end
end

local function test()
  local task_name = vim.api.nvim_call_function("expand", {"%:r"}) 
  local task_file_name = task_name .. ".cpp"

  local input_file_name = "test.input"
  local output_file_name = "test.output"
  local result_output_file_name = "result.output"

  local data_file_name = task_name .. ".json"
  local data_file = assert(io.open(data_file_name, "r"))
  local data = data_file:read()

  data = vim.api.nvim_call_function("json_decode", {data})
  data_file:close()

  local tests = data["tests"]

  for test_id, current_test in ipairs(tests) do
    print("Test #" .. test_id .. ":")

    local input_file = assert(io.open(input_file_name, "w+"))
    local output_file = assert(io.open(output_file_name, "w+"))
    local result_output_file = assert(io.open(result_output_file_name, "w+"))

    input_file:write(current_test["input"])
    result_output_file:write(trim(current_test["output"]))

    input_file:close()
    result_output_file:close()
    output_file:close()

    print(vim.api.nvim_call_function("system", {"time ./" ..
    task_name ..
    " < " ..
    input_file_name ..
    " > " ..
    output_file_name}))

    local diff_message = vim.api.nvim_call_function("system", {"diff -c "
    .. output_file_name
    .. " "
    .. result_output_file_name})

    local diff_response_code = vim.api.nvim_call_function("eval", {"v:shell_error"})

    if diff_response_code == 0 then
      print("Passed !!!")
    else
      print(diff_message)
    end
  end
end

-- Remove specific task file, default will remove the task that in current buffer 
local function remove(str)
  local task_name = ""
  if str == nil or str == "" then
    task_name = vim.api.nvim_call_function("expand", {"%:r"})
  else
    task_name = str 
  end
  local files = {task_name .. ".json",
  task_name .. ".cpp",
  task_name}
  for i, v in ipairs(files) do
    if vim.api.nvim_call_function("buffer_exists", {v}) > 0 then
      vim.api.nvim_command("bd! " .. v)
    end
    os.remove(v)
  end
end

-- Remove all task file by finding *.json data file in current directory
local function remove_all()
  local file_list = vim.api.nvim_call_function("glob", {"*.json", 0, 1})
  for i, v in ipairs(file_list) do
    local task_name = v:match("(.+)%..+$")
    remove(task_name)
  end
end

return {
  parse = parse,
  build = build,
  test = test,
  remove = remove,
  remove_all = remove_all
}
