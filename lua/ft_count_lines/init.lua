---@diagnostic disable: undefined-global
local M = {}

-- this plugin uses nvim-treesitter to count the number of lines in a function.
-- it uses treesitter to catch the current node at the cursor and then counts the number of lines in that node.
-- the type of node is called body and its parent must be a function_definition, so it only works with functions.
-- it should work with the CursorMoved autocmd


local group = vim.api.nvim_create_augroup("CountLines", { clear = true })

vim.api.nvim_create_autocmd({"CursorMoved"}, {
  vim.treesitter.query.set(
  "c",
  "count_lines",
  [[

    (function_definition
     type: (primitive_type)
     declarator: (function_declarator 
        declarator: (identifier)
        parameters: (parameter_list
          (parameter_declaration
			type: (type_identifier)
			declarator: (identifier)))))
        body: (compound_statement) @body
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
      if result > 25 then
        vim.api.nvim_buf_set_virtual_text(event.buf, ns, start_row, {{">> " .. result .. " <<", "ErrorMsg"}}, {})
      else
        vim.api.nvim_buf_set_virtual_text(event.buf, ns, start_row, {{">> " .. result .. " <<", "Comment"}}, {})
      end
    end

    -- local node_parent = node:parent()
    -- if node:type() == "compound_statement" and node_parent:type() == "function_definition" then
    --   local start_row, _, end_row, _ = node:range()
    --   local result = end_row - start_row - 1
    --   if result > 25 then
    --     print("AAA FUNCTION LINES: " .. (result) .. " AAA")
    --   else
    --     print("--- FUNCTION LINES: " .. (result) .. " ---")
    --   end
    -- end
  end
})


return M
