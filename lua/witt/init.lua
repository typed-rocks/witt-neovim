local M = {}

M.namespace = vim.api.nvim_create_namespace("witt")


local function get_position_above_annotation()

	local bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	local annotations = {}
	for i = 1, #lines do
		local line = lines[i]

		local col = string.find(line, "//%s*%^%?")
		if col then
			-- The position of the "?" in "// ^?" (adjust 1-based col position)
			local target_col = col + string.len(string.match(line, "//%s*"))
			
			local has_previous_line = i > 1
			if has_previous_line then
				table.insert(
					annotations,
					{ line = i - 2, col = target_col - 1, annotation_line_nr = i - 1, lineValue = line }
				)
			end
		end
	end
	return annotations
end

function M.get_all()
	local annotations = get_position_above_annotation()

	local diagnostics = {}
	for i = 1, #annotations do
		local annotation = annotations[i]
		M.get_type_above_annotation(diagnostics, annotation)
	end
end

local function add_diagnostic(result, annotation)
	local base = {
		lnum = annotation.annotation_line_nr,
		col = #annotation.lineValue,
		source = "witt",
		namespace = M.namespace,
	}
	if result and result.contents then
		local markdown_lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
		local type_info = table.concat(markdown_lines, "\n")

		local target_col = assert(string.find(type_info, "= "), "Type does not work") + 2;

		local cleaned_info = type_info.sub(type_info, 15, -5)

		base.severity = vim.diagnostic.severity.INFO
		base.message = cleaned_info
	else
		base.severity = vim.diagnostic.severity.WARN
		base.message = "No type available"
	end
	return base
end

function M.get_type_above_annotation(diagnostics, annotation)
	-- Request type at the position above "// ^?"
	local params =
	{ textDocument = vim.lsp.util.make_text_document_params(), position = { line = annotation.line, character = annotation.col } }
	vim.lsp.buf_request(0, "textDocument/hover", params, function(err, result, ctx, config)
		if err ~= nil then
			vim.notify("Error: " .. err, vim.log.levels.ERROR)
			return
		end
		local new_diagnostic = add_diagnostic(result, annotation)

		table.insert(diagnostics, new_diagnostic)
		local buf = vim.api.nvim_get_current_buf()
		M.reset()
		vim.diagnostic.set(M.namespace, buf, diagnostics, { signs = false })
	end)
end
function M.reset() 
	local buf = vim.api.nvim_get_current_buf()
	vim.diagnostic.reset(M.namespace, buf)

end

vim.api.nvim_create_user_command(
	"Witt",
	M.get_all,
	{ desc = "Get TypeScript type above the // ^? annotation" }
)

vim.api.nvim_create_user_command(
	"WittClear",
	M.reset,
	{desc = "Remove the Witt Annotations"}
)

vim.api.nvim_create_autocmd({'BufWritePre'}, {
	pattern = '*.ts,*.tsx,*.mts',
	command = "WittClear"
})

return M
