---@diagnostic disable: undefined-global

local M = {}

local group = vim.api.nvim_create_augroup("CountLines", { clear = true })
local ns = vim.api.nvim_create_namespace("count_lines") -- Namespace for diagnostics
local enabled = false -- State flag
local line_cache = {} -- Cache to track lines' content

vim.treesitter.query.set(
  "c",
  "count_lines",
  [[
    (function_definition) @body
  ]]
)

-- Default options
local default_options = {
  enable_on_start = false, -- Whether to enable the count lines feature when Neovim starts
  keybinding = "<leader>Fc" -- Default keybinding for enabling the count lines feature
}

-- Function to get current buffer lines
local function get_buffer_lines(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

-- Function to run the counting of function lines and populate diagnostics
local function set_diagnostics(bufnr)
  vim.diagnostic.reset(ns, bufnr) -- Clear previous diagnostics

  local parser = vim.treesitter.get_parser(bufnr, "c")
  local tree = parser:parse()[1]

  if not tree then
    return
  end

  local query = vim.treesitter.query.get("c", "count_lines")
  if not query then
    return
  end

  local all_functions = {}

  for id, node in query:iter_captures(tree:root(), bufnr) do
    if query.captures[id] == "body" then
      table.insert(all_functions, {
        node = node,
        range = function()
          return node:range()
        end,
      })
    end
  end

  if #all_functions == 0 then
    return
  end

  local diagnostics = {}

  for _, node in ipairs(all_functions) do
    local start_row, _, end_row, _ = node:range()
    local result = end_row - start_row - 2 -- Calculate the number of lines

    local message = "FUNCTION LINES: " .. result
    local severity = result > 25 and vim.diagnostic.severity.ERROR or vim.diagnostic.severity.INFO

    table.insert(diagnostics, {
      lnum = end_row, -- Line number (0-indexed)
      col = 0, -- Column (start at 0 for now)
      severity = severity, -- Severity based on the number of lines
      message = message
    })
  end

  -- Set diagnostics for the buffer
  vim.diagnostic.set(ns, bufnr, diagnostics)

  -- Update cache of lines after diagnostics
  line_cache[bufnr] = get_buffer_lines(bufnr)
end

-- Function to check if a line has changed compared to the cache
local function line_changed(bufnr, line_num)
  local cached_lines = line_cache[bufnr]
  local current_lines = get_buffer_lines(bufnr)

  return cached_lines and cached_lines[line_num] ~= current_lines[line_num]
end

-- Autocommand function to handle line changes or file save
local function set_autocmd()
  -- Run diagnostics on buffer write (after the file is saved)
  vim.api.nvim_create_autocmd({"BufWritePost"}, {
    pattern = {"*.c"}, -- Apply to .c files
    group = group,
    callback = function(event)
      if not enabled then return end -- Check if counting is enabled
      set_diagnostics(event.buf) -- Run counting diagnostics on save
    end
  })

  -- Detect line changes without saving the file
  vim.api.nvim_create_autocmd({"TextChanged", "TextChangedI"}, {
    pattern = {"*.c"}, -- Apply to .c files
    group = group,
    callback = function(event)
      if not enabled then return end -- Check if counting is enabled

      local bufnr = event.buf
      local changed = false

      local current_lines = get_buffer_lines(bufnr)
      for i = 0, #current_lines - 1 do
        if line_changed(bufnr, i) then
          changed = true
          break
        end
      end

      if changed then
        set_diagnostics(bufnr) -- Re-run diagnostics if there were changes
      end
    end
  })
end

-- Enable function
function M.enable()
  if not enabled then
    enabled = true
    set_autocmd() -- Reset autocommands when enabling
    -- Run diagnostics immediately after enabling
    local bufnr = vim.api.nvim_get_current_buf() -- Get the current buffer number
    set_diagnostics(bufnr) -- Run counting diagnostics immediately
  end
end

-- Disable function
function M.disable()
  if enabled then
    enabled = false
    vim.api.nvim_clear_autocmds({ group = group }) -- Clear autocommands to disable
    vim.diagnostic.reset(ns) -- Clear diagnostics when disabled
  end
end

-- Toggle function
function M.toggle()
  if enabled then
    print("Disabling Count Lines Feature")
    M.disable()
  else
    print("Enabling Count Lines Feature")
    M.enable()
  end
end

-- Status function
function M.status()
  print("Count Lines Feature is " .. (enabled and "Enabled" or "Disabled"))
  return enabled
end

-- Setup function to initialize the plugin with options
function M.setup(opts)
  -- Merge user-provided options with defaults
  opts = opts or {}
  opts = vim.tbl_extend("force", default_options, opts)

  vim.api.nvim_set_keymap('n', opts.keybinding, "<CMD>lua require('ft_count_lines').toggle()<CR>", { noremap = true, silent = true,
  desc = "Toggle Count Lines Feature" })
  if opts.enable_on_start then
    M.enable() -- Enable the feature if configured to do so on startup
  end
end

return M

