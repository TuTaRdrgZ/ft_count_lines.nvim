---@diagnostic disable: undefined-global
local M = {}

local group = vim.api.nvim_create_augroup("CountLines", { clear = true })

vim.api.nvim_create_autocmd({"TextChanged"}, {
  vim.treesitter.query.set(
  "c",
  "count_lines",
  [[
    (function_definition) @body
  ]]
  ),
  pattern = "*.c",
  group = group,
  callback = function(event)

    -- local node = ts_utils.get_node_at_cursor()
    local parser = vim.treesitter.get_parser(event.buf, "c")
    local tree = parser:parse()[1]

    if tree == nil then
      return
    end

    local query = vim.treesitter.query.get("c", "count_lines")
    if query == nil then
      return
    end
    local all_functions = {}

    for id, node in query:iter_captures(tree:root(), event.buf) do
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

    local ns = vim.api.nvim_create_namespace("count_lines")
    vim.api.nvim_buf_clear_namespace(event.buf, ns, 0, -1)

    for _, node in ipairs(all_functions) do
      local start_row, _, end_row, _ = node:range()
      local result = end_row - start_row - 2
      local str = "FUNCTION LINES: " .. result

      if result > 25 then
        vim.api.nvim_buf_set_virtual_text(event.buf, ns, start_row, {{"   " .. str .. "   ", "ErrorMsg"}}, {})
      else
        vim.api.nvim_buf_set_virtual_text(event.buf, ns, start_row, {{">> " .. str .. " <<", "Comment"}}, {})
      end
    end
  end
})

return M
