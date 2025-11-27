-- quickadoc.nvim
-- Minimal Neovim plugin to create timestamped AsciiDoc notes.
-- Provides :AdocLog command, <leader>en to create, and <leader>fn to open fzf in notes dir.

local M = {}

local defaults = {
  dir = "~/github/notes",                         -- Where to create notes
  enable_default_mapping = true,                  -- Set default keymaps
  create_map = "<leader>en",                      -- Create new note
  find_rg_map = "<leader>er",                     -- Open fzf in notes dir (grep)
  find_file_map = "<leader>ef",                   -- Open fzf in notes dir (filename)
  filename_pattern = "log-%Y%m%d-%H%M%S_.adoc",    -- Lua os.date() pattern
  timestamp_pattern = "%Y%m%d-%H%M%S",            -- Lua os.date() pattern
  header_template = "= Log {timestamp}\n:revdate: {date}\n\n", -- AsciiDoc header
  open_cmd = "edit",                              -- edit | tabedit | vnew | split
}

local opts = nil

local function ensure_dir(path)
  if vim.fn.isdirectory(path) == 0 then
    vim.fn.mkdir(path, "p")
  end
end

local function populate_template(template, timestamp)
  local date = os.date("%Y-%m-%d")
  return (template:gsub("{timestamp}", timestamp):gsub("{date}", date))
end

local function create_log()
  local notes_dir = vim.fn.expand(opts.dir)
  ensure_dir(notes_dir)

  local timestamp    = os.date(opts.timestamp_pattern)
  local base_name    = os.date(opts.filename_pattern) -- e.g. "2025-11-27-123456.adoc"
  local base_no_ext  = base_name:gsub("%.adoc$", "")  -- strip .adoc once, if present

  -- inner function to actually create/open the file once we know suffix
  local function create_with_suffix(suffix)
    suffix = suffix or ""
    local filename = base_no_ext .. suffix .. ".adoc"
    local filepath = notes_dir .. "/" .. filename

    if vim.fn.filereadable(filepath) == 0 then
      local ok, fh = pcall(io.open, filepath, "w")
      if not ok or not fh then
        vim.notify("quickadoc: cannot write file: " .. filepath, vim.log.levels.ERROR)
        return
      end
      fh:write(populate_template(opts.header_template, timestamp))
      fh:close()
    end

    vim.cmd((opts.open_cmd or "edit") .. " " .. vim.fn.fnameescape(filepath))
    vim.cmd("normal! G") -- Move cursor to end of the file (buffer, not filename)
  end

  -- Try to use vim.ui.input if available (Neovim 0.6+), fall back to no suffix
  if vim.ui and vim.ui.input then
    vim.ui.input({
      prompt  = "Filename suffix (optional) " .. base_no_ext .. "",
      default = "",
    }, function(input)
      if input == nil then
        -- user cancelled: do nothing
        return
      end
      create_with_suffix(input)
    end)
  else
    -- no nice UI available, just create with no suffix
    create_with_suffix("")
  end
end

local function open_fzf_notes_rg()
  local notes_dir = vim.fn.expand(opts.dir)
  ensure_dir(notes_dir)

  if vim.fn.exists(":Rg") == 2 then
    -- Use ripgrep content search via fzf.vim
    vim.cmd("lcd " .. vim.fn.fnameescape(notes_dir) .. " | Rg")
  elseif pcall(require, "telescope.builtin") then
    require("telescope.builtin").live_grep({ cwd = notes_dir, previewer = true })
  else
    vim.notify("quickadoc: no FZF (Rg) or Telescope found", vim.log.levels.WARN)
  end
end

local function open_fzf_notes_file()
  local notes_dir = vim.fn.expand(opts.dir)
  ensure_dir(notes_dir)

  if vim.fn.exists(":FZF") == 2 then
    vim.fn['fzf#vim#files'](notes_dir, vim.fn['fzf#vim#with_preview'](), 0)
  elseif pcall(require, "telescope.builtin") then
    require("telescope.builtin").find_files({ cwd = notes_dir, previewer = true })
  else
    vim.notify("quickadoc: no FZF or Telescope found", vim.log.levels.WARN)
  end
end

function M.setup(user_opts)
  opts = vim.tbl_deep_extend("force", defaults, user_opts or {})

  vim.api.nvim_create_user_command("AdocLog", function()
    create_log()
  end, { desc = "Create a timestamped AsciiDoc log note" })

  if opts.enable_default_mapping then
    if opts.create_map and opts.create_map ~= "" then
      vim.keymap.set("n", opts.create_map, create_log, { desc = "New AsciiDoc log note" })
    end
    if opts.find_rg_map and opts.find_rg_map ~= "" then
      vim.keymap.set("n", opts.find_rg_map, open_fzf_notes_rg, { desc = "Open note finder (fzf/telescope)" })
    end
    if opts.find_file_map and opts.find_file_map ~= "" then
      vim.keymap.set("n", opts.find_file_map, open_fzf_notes_file, { desc = "Open note finder (fzf/telescope)" })
    end
  end
end

return M
