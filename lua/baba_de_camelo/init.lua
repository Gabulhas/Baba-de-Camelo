-- local q = require("vim.treesitter.query")
local ns_id = vim.api.nvim_create_namespace('baba_de_camelo_inlays')

M = {}

local function i(value)
    print(vim.inspect(value))
end

local all_symbols_query = vim.treesitter.parse_query("ocaml", [[(let_binding pattern: (value_name) @definitionname (#offset! @definitionname))]])

local function get_syntax_tree_root()
    local bufnr = vim.api.nvim_get_current_buf()
    local language_tree = vim.treesitter.get_parser(bufnr, 'ocaml')
    local syntax_tree = language_tree:parse()
    return syntax_tree[1]:root()
end

local function clean_markdown(symbol_type)
    return symbol_type:sub(10, #symbol_type - 4)
end

-- Renders symbol type as inlay
local function symbol_type_to_inlay(symbol_type, line)
    local bufnr = vim.api.nvim_get_current_buf()
    local opts = {end_line = line, virt_text = {{symbol_type, "Comment"}}, virt_text_pos = 'eol'}
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, line, 0, opts)

end

local function from_lsp_to_render(err, result, _, _)
    if err ~= nil then error(tostring(err)) end
    --[[
    {
        contents = {
            kind = "markdown",
            value = "```ocaml\nreg\n```"
        },
        range = {
            end = {
            character = 15,
            line = 106
            },
            start = {
                character = 8,
                line = 106
            }
        }
    } ]]
    local symbol_type = clean_markdown(result["contents"]["value"])
    local line = result["range"]["start"]["line"]

    symbol_type_to_inlay(symbol_type, line)

end

local function from_position_to_render(position)
    local bufnr = vim.api.nvim_get_current_buf()
    local character = position["character"]
    local line = position["line"]
    local params = vim.lsp.util.make_position_params()
    params["position"]["character"] = character
    params["position"]["line"] = line
    params["kind"] = "plaintext"
    vim.lsp.buf_request(bufnr, 'textDocument/hover', params, from_lsp_to_render)
end

local function pipeline()
    local bufnr = vim.api.nvim_get_current_buf()
    local root = get_syntax_tree_root()

    for _, _, metadata in all_symbols_query:iter_matches(root, bufnr) do
        from_position_to_render({character = metadata["content"][1][2], line = metadata["content"][1][1]})
    end

    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
end

M.pipeline = pipeline

vim.cmd [[autocmd BufWritePre *.ml lua M.pipeline()]]

return M
