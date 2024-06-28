local api = vim.api
local config = require("neominimap.config").get()
local util = require("neominimap.util")
local logger = require("neominimap.logger")
local buffer = require("neominimap.buffer")

---@type table<integer, integer>
local winid_to_mwinid = {}

--- The winid of the minimap attached to the given window
---@param winid integer
---@return integer?
local get_minimap_winid = function(winid)
    return winid_to_mwinid[winid]
end

--- Set the winid of the minimap attached to the given window
---@param winid integer
---@param mwinid integer?
local set_minimap_winid = function(winid, mwinid)
    winid_to_mwinid[winid] = mwinid
end

--- Return the list of windows that one minimap is attached to
--- @return integer[]
local list_windows = function()
    return vim.tbl_keys(winid_to_mwinid)
end

---@param winid integer
---@return boolean
local should_show_minimap = function(winid)
    if not api.nvim_win_is_valid(winid) then
        logger.log(string.format("Window %d is not valid", winid), vim.log.levels.WARN)
        return false
    end
    local bufnr = api.nvim_win_get_buf(winid)
    if not buffer.get_minimap_bufnr(bufnr) then
        logger.log(
            string.format("No minimap buffer available for buffer %d in window %d", bufnr, winid),
            vim.log.levels.TRACE
        )
        return false
    end

    if util.win_get_height(winid) == 0 or api.nvim_win_get_width(winid) == 0 then
        logger.log(string.format("Window %d has zero height or width", winid), vim.log.levels.TRACE)
        return false
    end

    logger.log(string.format("Minimap can be shown for window %d", winid), vim.log.levels.TRACE)
    return true
end

---@param winid integer
local get_window_config = function(winid)
    logger.log(string.format("Getting window configuration for window %d", winid), vim.log.levels.TRACE)
    local minimap_height = util.win_get_height(winid)
    if config.max_minimap_height then
        minimap_height = math.min(minimap_height, config.max_minimap_height)
    end

    local col = api.nvim_win_get_width(winid)
    local row = 0

    local height = (function()
        local border = config.window_border
        if type(border) == "string" then
            return border == "none" and minimap_height or minimap_height - 2
        else
            local h = minimap_height
            if border[2] ~= "" then
                h = h - 1
            end
            if border[6] ~= "" then
                h = h - 1
            end
            return h
        end
    end)()

    return {
        relative = "win",
        win = winid,
        anchor = "NE",
        width = config.minimap_width + 4,
        height = height,
        row = row,
        col = col,
        focusable = false,
        zindex = config.z_index,
        style = "minimal",
        border = config.window_border,
    }
end

--- WARN: This function does not check whether a minimap should be created for this window nor if this window is valid.
--- Create the minimap attached to the given window
---@param winid integer
---@return integer? mwinid winid of the minimap window if created, nil otherwise
local create_minimap_window = function(winid)
    logger.log(string.format("Attempting to create minimap for window %d", winid), vim.log.levels.TRACE)

    local bufnr = api.nvim_win_get_buf(winid)
    local mbufnr = buffer.get_minimap_bufnr(bufnr)

    if not mbufnr then
        logger.log(string.format("Minimap buffer not available for window %d", winid), vim.log.levels.TRACE)
        return nil
    end
    local ret = util.noautocmd(function()
        logger.log(string.format("Creating minimap window for window %d", winid), vim.log.levels.TRACE)
        local win_cfg = get_window_config(winid)
        win_cfg.noautocmd = true --Set noautocmd here for noautocmd can only set for none existing window
        local mwinid = api.nvim_open_win(mbufnr, false, win_cfg)
        set_minimap_winid(winid, mwinid)

        vim.wo[mwinid].winhl = "Normal:NeominimapBackground,FloatBorder:NeominimapBorder"
        vim.wo[mwinid].wrap = false
        vim.wo[mwinid].foldcolumn = "0"
        vim.wo[mwinid].scrolloff = 0
        vim.wo[mwinid].sidescrolloff = 0
        vim.wo[mwinid].winblend = 0
        logger.log(string.format("Minimap window %d created for window %d", mwinid, winid), vim.log.levels.TRACE)
        return mwinid
    end)()
    return ret
end

--- Close the minimap attached to the given window
---@param winid integer
---@return integer? mwinid winid of the minimap window if successfully removed, nil otherwise
local close_minimap_window = function(winid)
    local mwinid = get_minimap_winid(winid)
    set_minimap_winid(winid, nil)
    logger.log(string.format("Attempting to close minimap for window %d", winid), vim.log.levels.TRACE)
    if mwinid and api.nvim_win_is_valid(mwinid) then
        logger.log(string.format("Deleting minimap window %d", mwinid), vim.log.levels.TRACE)
        util.noautocmd(api.nvim_win_close)(mwinid, true)
        return mwinid
    else
        logger.log(string.format("Minimap window %d is not valid or already closed", winid), vim.log.levels.TRACE)
    end
    return nil
end

--- Refresh the minimap attached to the given window
--- Close window if minimap should not be shown or if the minimap buffer is not available
--- Otherwise, create the minimap if it does not exist
--- Otherwise, reset the window config
--- Reset the buffer if the it does not match the current window
---@param winid integer
---@return integer? mwinid winid of the minimap window if created, nil otherwise
local refresh_minimap_window = function(winid)
    logger.log(string.format("Refreshing minimap for window %d", winid), vim.log.levels.TRACE)
    if not should_show_minimap(winid) then
        logger.log(string.format("Minimap should not be shown for window %d", winid), vim.log.levels.TRACE)
        if get_minimap_winid(winid) then
            close_minimap_window(winid)
        end
        return nil
    end

    local bufnr = api.nvim_win_get_buf(winid)
    local mbufnr = buffer.get_minimap_bufnr(bufnr)
    if not mbufnr then
        logger.log(string.format("Minimap buffer not available for window %d", winid), vim.log.levels.TRACE)
        if get_minimap_winid(winid) then
            close_minimap_window(winid)
        end
        return nil
    end

    local mwinid = get_minimap_winid(winid) or create_minimap_window(winid)
    if not mwinid then
        logger.log(string.format("Failed to create minimap for window %d", winid), vim.log.levels.TRACE)
        return nil
    end

    local cfg = get_window_config(winid)
    util.noautocmd(api.nvim_win_set_config)(mwinid, cfg)

    if api.nvim_win_get_buf(mwinid) ~= mbufnr then
        api.nvim_win_set_buf(mwinid, mbufnr)
    end

    -- TODO: Scroll the window
    logger.log(string.format("Minimap for window %d refreshed", winid), vim.log.levels.TRACE)
    return mwinid
end

--- Refresh all minimaps in the given tab
---@param tabid integer
local refresh_minimaps_in_tab = function(tabid)
    logger.log(string.format("Refreshing all minimaps in tab %d", tabid), vim.log.levels.TRACE)
    local win_list = api.nvim_tabpage_list_wins(tabid)
    for _, winid in ipairs(win_list) do
        refresh_minimap_window(winid)
    end
    logger.log(string.format("All minimaps in tab %d refreshed", tabid), vim.log.levels.TRACE)
end

--- Close all minimaps in the given tab
---@param tabid integer
local close_minimap_in_tab = function(tabid)
    logger.log(string.format("Closing all minimaps in tab %d", tabid), vim.log.levels.TRACE)
    local win_list = api.nvim_tabpage_list_wins(tabid)
    for _, winid in ipairs(win_list) do
        close_minimap_window(winid)
    end
    logger.log(string.format("All minimaps in tab %d closed", tabid), vim.log.levels.TRACE)
end

--- Refresh all minimaps across tabs
local refresh_all_minimap_windows = function()
    logger.log("Refreshing all minimap windows", vim.log.levels.TRACE)
    local win_list = api.nvim_list_wins()
    for _, winid in ipairs(win_list) do
        refresh_minimap_window(winid)
    end
    logger.log("All minimap windows refreshed", vim.log.levels.TRACE)
end

--- Close all minimaps across tabs
local close_all_minimap_windows = function()
    logger.log("Closing all minimap windows", vim.log.levels.TRACE)
    for _, winid in ipairs(list_windows()) do
        close_minimap_window(winid)
    end
end

return {
    get_minimap_winid = get_minimap_winid,
    list_windows = list_windows,
    refresh_minimap_window = refresh_minimap_window,
    refresh_minimaps_in_tab = refresh_minimaps_in_tab,
    refresh_all_minimap_windows = refresh_all_minimap_windows,
    close_minimap_window = close_minimap_window,
    close_minimap_in_tab = close_minimap_in_tab,
    close_all_minimap_windows = close_all_minimap_windows,
}
