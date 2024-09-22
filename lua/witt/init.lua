local M = {}


function M.setup() 
end
M.namespace = vim.api.nvim_create_namespace("witt")

local function find_annotations()
	local bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local annotations = {}

	for i, line in ipairs(lines) do
		local col = line:find("//%s*%^%?")
		if col and i > 1 then
			-- The position of the "?" in "// ^?" (adjust 1-based col position)
			local target_col = col + #(line:match("//%s*"))
			table.insert(annotations, {
				line = i - 2,
				col = target_col - 1,
				annotation_line = i - 1,
				annotation_text = line,
			})
		end
	end
	return annotations
end

local function build_diagnostic(result, annotation)
	local message = "No type available"
	local severity = vim.diagnostic.severity.WARN

	if result and result.contents then
		local markdown = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
		message = table.concat(markdown, "\n"):sub(15, -5)
		severity = vim.diagnostic.severity.INFO
	end

	return {
		lnum = annotation.annotation_line,
		col = #annotation.annotation_text,
		message = message,
		severity = severity,
		source = "witt",
		namespace = M.namespace,
	}
end

function M.update_diagnostics()
	local bufnr = vim.api.nvim_get_current_buf()
	local annotations = find_annotations()
	local diagnostics = {}

	for _, annotation in ipairs(annotations) do
		local params = {
			textDocument = vim.lsp.util.make_text_document_params(),
			position = { line = annotation.line, character = annotation.col },
		}

		vim.lsp.buf_request(bufnr, "textDocument/hover", params, function(err, result)
			if err then
				vim.notify("Error: " .. err, vim.log.levels.ERROR)
			else
				table.insert(diagnostics, build_diagnostic(result, annotation))
			end

			if #diagnostics == #annotations then
				vim.diagnostic.set(M.namespace, bufnr, diagnostics, { signs = false })
			end
		end)
	end
end

function M.clear()
	vim.diagnostic.reset(M.namespace, vim.api.nvim_get_current_buf())
end

vim.api.nvim_create_user_command(
	"Witt",
	M.update_diagnostics,
	{ desc = "Get TypeScript type above the // ^? annotation" }
)
vim.api.nvim_create_user_command("WittClear", M.clear, { desc = "Remove the Witt Annotations" })

vim.api.nvim_create_autocmd({ "TextChanged" }, {
	pattern = "*.ts,*.tsx,*.mts",
	callback = M.update_diagnostics,
})

vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if client and client.name == "tsserver" then
			M.update_diagnostics()
		end
	end,
})

return M
