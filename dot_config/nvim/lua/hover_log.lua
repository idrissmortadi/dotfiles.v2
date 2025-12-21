local M = {}

local BUF_NAME = "HoverLog"
local buf = nil
local win = nil

local function ensure_window()
  if buf and vim.api.nvim_buf_is_valid(buf) then
    if win and vim.api.nvim_win_is_valid(win) then
      return buf, win
    end
  end

  -- create scratch buffer
  buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, BUF_NAME)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false

  -- open vertical split without stealing focus
  local cur_win = vim.api.nvim_get_current_win()
  vim.cmd("vsplit")
  win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_set_current_win(cur_win)

  return buf, win
end

function M.hover_append()
  vim.notify("Hover Log")
  buf, win = ensure_window()

  local params = vim.lsp.util.make_position_params(win, "utf-8")
  vim.lsp.buf_request(0, "textDocument/hover", params, function(_, result)
    if not result or not result.contents then
      return
    end

    local lines = vim.lsp.util.convert_input_to_markdown_lines(result.contents)
    if vim.tbl_isempty(lines) then
      return
    end

    vim.api.nvim_buf_set_lines(buf, -1, -1, false, {
      "────────────────────────",
    })
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
  end)
end

return M
