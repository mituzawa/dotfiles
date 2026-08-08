-- Reading back what has scrolled off the Claude Code pane.
--
-- Claude Code runs on the alternate screen (it emits ESC[?1049h at startup), so
-- nvim's terminal buffer only ever holds the frame currently on display: <C-\><C-n>
-- followed by k has nothing above it to reach, by construction. The conversation
-- itself is on disk, one JSON object per line, under
-- ~/.claude/projects/<slugified-cwd>/<session-uuid>.jsonl.
--
--   :ClaudeLog   render the newest session for this project into a scratch buffer
--   :ClaudeLog!  open that .jsonl raw, for when the rendering hides something

local M = {}

-- Claude Code slugifies the directory it started in by replacing every
-- non-alphanumeric character with "-", so /home/mituzawa/dotfiles becomes
-- -home-mituzawa-dotfiles. The terminal spawns at the git root
-- (git_repo_cwd = true in the dein.toml hook), so resolve that rather than the
-- cwd of whichever buffer happens to be current.
local function session_dir()
	local root = vim.fs.root(0, ".git") or vim.uv.cwd()
	return vim.fs.joinpath(vim.fn.expand("~/.claude/projects"), (tostring(root):gsub("[^%w]", "-")))
end

-- The session being written right now is simply the most recently touched file:
-- --resume and --continue keep appending to the one they reopened.
local function newest_session(dir)
	local newest, newest_at
	local ok, iter = pcall(vim.fs.dir, dir)
	if not ok then
		return nil
	end
	for name, kind in iter do
		if kind == "file" and name:match("%.jsonl$") then
			local path = vim.fs.joinpath(dir, name)
			local stat = vim.uv.fs_stat(path)
			if stat and (not newest_at or stat.mtime.sec > newest_at) then
				newest, newest_at = path, stat.mtime.sec
			end
		end
	end
	return newest
end

-- Timestamps in the file are UTC, and os.time reads a table back as local time,
-- so the gap between the two readings of "now" is the shift to apply.
local function clock(iso)
	local y, mo, d, h, mi, s = tostring(iso):match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
	if not y then
		return ""
	end
	local now = os.time()
	local offset = os.difftime(now, os.time(os.date("!*t", now) --[[@as osdateparam]]))
	local at = os.time({
		year = tonumber(y) or 0,
		month = tonumber(mo) or 0,
		day = tonumber(d) or 0,
		hour = tonumber(h) or 0,
		min = tonumber(mi) or 0,
		sec = tonumber(s) or 0,
	})
	return os.date("%m/%d %H:%M", at + offset)
end

-- Truncation counts characters, not bytes: string.sub would happily cut a
-- multibyte character in half and leave invalid UTF-8 in the buffer.
local function oneline(text, limit)
	local flat = tostring(text or ""):gsub("%s+", " ")
	if vim.fn.strchars(flat) > limit then
		flat = vim.fn.strcharpart(flat, 0, limit) .. "…"
	end
	return flat
end

local function append(out, text)
	for _, line in ipairs(vim.split(tostring(text), "\n", { plain = true })) do
		out[#out + 1] = line
	end
end

-- Only user and assistant records carry conversation. The rest of the file is
-- bookkeeping -- mode, permission-mode, ai-title, file-history-snapshot and so
-- on -- and is skipped.
local function render(path)
	local out = { "# " .. vim.fs.basename(path), "" }
	for line in io.lines(path) do
		local ok, rec = pcall(vim.json.decode, line)
		if ok and type(rec) == "table" and (rec.type == "user" or rec.type == "assistant") then
			local content = type(rec.message) == "table" and rec.message.content or nil
			local body = {}
			if type(content) == "string" then
				append(body, content)
			elseif type(content) == "table" then
				for _, block in ipairs(content) do
					if block.type == "text" then
						append(body, block.text)
					-- Thinking is written to the file with the text stripped -- only the
					-- signature survives -- so an entry here would be an empty marker.
					elseif block.type == "thinking" and oneline(block.thinking, 300) ~= "" then
						body[#body + 1] = "> (thinking) " .. oneline(block.thinking, 300)
					elseif block.type == "tool_use" then
						body[#body + 1] = "`-> " .. tostring(block.name) .. "` " .. oneline(vim.json.encode(block.input), 200)
					elseif block.type == "tool_result" then
						local result = type(block.content) == "string" and block.content or vim.json.encode(block.content)
						body[#body + 1] = "`<- result` " .. oneline(result, 200)
					elseif block.type == "image" then
						body[#body + 1] = "`[image]`"
					end
				end
			end
			if #body > 0 then
				out[#out + 1] = ("## %s  %s"):format(rec.type, clock(rec.timestamp))
				out[#out + 1] = ""
				vim.list_extend(out, body)
				out[#out + 1] = ""
			end
		end
	end
	return out
end

function M.open(raw)
	local dir = session_dir()
	local path = newest_session(dir)
	if not path then
		vim.notify("No Claude transcript under " .. dir, vim.log.levels.WARN)
		return
	end
	if raw then
		vim.cmd("tabedit " .. vim.fn.fnameescape(path))
		-- This one is the real file on disk, and the session may still be writing
		-- to it, so lock the buffer rather than leaving it editable.
		vim.bo.modifiable = false
		vim.bo.readonly = true
		vim.cmd("normal! G")
		return
	end

	local lines = render(path)
	vim.cmd("tabnew")
	local buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].modifiable = false
	vim.bo[buf].readonly = true
	-- Naming is cosmetic; a second copy of the same session would collide (E95).
	pcall(vim.api.nvim_buf_set_name, buf, "claude://" .. vim.fs.basename(path))
	-- Land at the bottom: the point of opening this is the part that just scrolled off.
	vim.cmd("normal! G")
end

vim.api.nvim_create_user_command("ClaudeLog", function(opts)
	M.open(opts.bang)
end, { bang = true, desc = "Open this project's newest Claude Code transcript (! for raw JSONL)" })

return M
