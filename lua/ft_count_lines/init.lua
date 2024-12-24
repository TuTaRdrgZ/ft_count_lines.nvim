---@diagnostic disable: undefined-global

local M = {}

local group = vim.api.nvim_create_augroup("CountLines", { clear = true })
local ns = vim.api.nvim_create_namespace("count_lines") -- Namespace for extmarks
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
	keybinding = "<leader>Fc", -- Default keybinding for enabling the count lines feature
	display_mode = "under",
}

-- Function to get current buffer lines
local function get_buffer_lines(bufnr)
	return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

-- Function to run the counting of function lines and set virtual lines
local function set_virtual_lines(bufnr)
	-- Clear previous virtual lines
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

	local parser = vim.treesitter.get_parser(bufnr, "c")
	local tree = parser:parse()[1]

	if not tree then
		return
	end

	local query = vim.treesitter.query.get("c", "count_lines")
	if not query then
		return
	end

	for id, node in query:iter_captures(tree:root(), bufnr) do
		if query.captures[id] == "body" then
			local start_row, _, end_row, _ = node:range()
			local result = end_row - start_row - 2 -- Calculate the number of lines
			local emotion = result > 25 and "Error" or "Comment"
			local text = " FUNCTION LINES: " .. result .. " "
			local emoji = result > 25 and "⚠⚠" or "——"
			local message = { { emoji .. text .. emoji, emotion } }

			if result > 0 then
				if default_options.display_mode == "under" then
					-- Set extmark with virtual lines
					vim.api.nvim_buf_set_extmark(bufnr, ns, end_row, 0, {
						virt_lines = { message }, -- Display message below the function
					})
				else
					-- Set extmark with virtual text
					vim.api.nvim_buf_set_extmark(bufnr, ns, start_row, 0, {
						virt_text = message, -- Display message at the end of the line
						virt_text_pos = "eol", -- Position at the end of the line
					})
				end
			end
		end
	end

	-- Update cache of lines
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
	-- Set virtual lines on buffer write (after the file is saved)
	vim.api.nvim_create_autocmd({ "BufWritePost" }, {
		pattern = { "*.c" }, -- Apply to .c files
		group = group,
		callback = function(event)
			if not enabled then
				return
			end -- Check if counting is enabled
			set_virtual_lines(event.buf) -- Run virtual lines on save
		end,
	})

	-- Detect line changes without saving the file
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		pattern = { "*.c" }, -- Apply to .c files
		group = group,
		callback = function(event)
			if not enabled then
				return
			end -- Check if counting is enabled

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
				set_virtual_lines(bufnr) -- Re-run virtual lines if there were changes
			end
		end,
	})
end

-- Enable function
function M.enable()
	if not enabled then
		enabled = true
		set_autocmd() -- Reset autocommands when enabling
		-- Run virtual lines immediately after enabling
		local bufnr = vim.api.nvim_get_current_buf() -- Get the current buffer number
		set_virtual_lines(bufnr) -- Run virtual lines immediately
	end
end

-- Disable function
function M.disable()
	if enabled then
		enabled = false
		vim.api.nvim_clear_autocmds({ group = group }) -- Clear autocommands to disable
		vim.api.nvim_buf_clear_namespace(0, ns, 0, -1) -- Clear virtual lines when disabled
	end
end

-- Toggle function
function M.toggle()
	if enabled then
		vim.notify("Disabling Count Lines Feature", "Info", { title = "Count Lines" })
		M.disable()
	else
		vim.notify("Enabling Count Lines Feature", "Info", { title = "Count Lines" })
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

	vim.api.nvim_set_keymap(
		"n",
		opts.keybinding,
		"<CMD>lua require('ft_count_lines').toggle()<CR>",
		{ noremap = true, silent = true, desc = "Toggle Count Lines Feature" }
	)
	if opts.enable_on_start then
		M.enable() -- Enable the feature if configured to do so on startup
	end
	default_options = opts
	vim.api.nvim_create_user_command("CountLines", M.toggle, {})
end

return M
