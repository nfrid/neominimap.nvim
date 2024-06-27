local M = {}

local api = vim.api
local config = require("neominimap.config").get()
local log = require("neominimap.log")

---@type table<integer, integer>
local bufnr_to_mbufnr = {}

--- The winid of the minimap attached to the given window
---@param bufnr integer
---@return integer?
M.get_minimap_bufnr = function(bufnr)
    return bufnr_to_mbufnr[bufnr]
end

--- Set the winid of the minimap attached to the given window
---@param bufnr integer
---@param mbufnr integer?
M.set_minimap_bufnr = function(bufnr, mbufnr)
    bufnr_to_mbufnr[bufnr] = mbufnr
end

--- Return the list of buffers that has a minimap buffer attached to
--- @return integer[]
M.list_buffers = function()
    return vim.tbl_keys(bufnr_to_mbufnr)
end

---@param bufnr integer
---@return boolean
M.should_generate_minimap = function(bufnr)
    local filetype = vim.bo[bufnr].filetype
    local buftype = vim.bo[bufnr].buftype

    if vim.tbl_contains(config.exclude_buftypes, buftype) then
        return false
    end
    if vim.tbl_contains(config.exclude_filetypes, filetype) then
        return false
    end
    if config.max_lines and api.nvim_buf_line_count(bufnr) > config.max_lines then
        return false
    end

    return true
end

--- Create the minimap attached to the given buffer if possible
--- Remove minimap buffer if there is already one
--- @param bufnr integer
--- @return integer mbufnr bufnr of the minimap buffer if created, nil otherwise
M.create_minimap_buffer = function(bufnr)
    local util = require("neominimap.util")
    local ret = util.noautocmd(function()
        log.notify("Generating minimap for buffer " .. tostring(bufnr), vim.log.levels.INFO)
        local mbufnr = api.nvim_create_buf(false, true)
        log.notify(
            "A new buffer " .. tostring(mbufnr) .. " is created for buffer " .. tostring(bufnr),
            vim.log.levels.INFO
        )
        M.set_minimap_bufnr(bufnr, mbufnr)

        vim.bo[mbufnr].buftype = "nofile"
        vim.bo[mbufnr].swapfile = false
        vim.bo[mbufnr].bufhidden = "hide"

        log.notify("Minimap for buffer " .. tostring(bufnr) .. " is generated", vim.log.levels.INFO)
        return mbufnr
    end)()
    return ret
end

--- Refresh the minimap attached to the given buffer if possible
--- Remove a buffer that is attached to it
--- @param bufnr integer
--- @return integer? mbufnr bufnr of the minimap buffer if created, nil otherwise
M.refresh_minimap_buffer = function(bufnr)
    local util = require("neominimap.util")
    if not api.nvim_buf_is_valid(bufnr) or not M.should_generate_minimap(bufnr) then
        if M.get_minimap_bufnr(bufnr) then
            log.notify("Deleting minimap for buffer " .. tostring(bufnr), vim.log.levels.INFO)
            M.wipe_out_minimap_buffer(bufnr)
        end
        return nil
    end
    local mbufnr = M.get_minimap_bufnr(bufnr)
    if not mbufnr then
        mbufnr = M.create_minimap_buffer(bufnr)
    end

    local minimap = require("neominimap.text").gen(bufnr)
    vim.bo[mbufnr].modifiable = true
    util.noautocmd(api.nvim_buf_set_lines)(mbufnr, 0, -1, true, minimap)
    vim.bo[mbufnr].modifiable = false

    log.notify("Minimap for buffer " .. tostring(bufnr) .. " is refreshed", vim.log.levels.INFO)
    return mbufnr
end

--- Remove the minimap attached to the given buffer
--- @param bufnr integer
--- @return integer? mbufnr bufnr of the minimap buffer if successfully removed, nil otherwise
M.wipe_out_minimap_buffer = function(bufnr)
    if not api.nvim_buf_is_valid(bufnr) then
        return nil
    end
    local mbufnr = M.get_minimap_bufnr(bufnr)
    if not mbufnr then
        return nil
    end
    local util = require("neominimap.util")
    log.notify("Deleting minimap for buffer " .. tostring(bufnr), vim.log.levels.INFO)
    util.noautocmd(api.nvim_buf_delete)(mbufnr, { force = true })
    log.notify("Minimap Buffer for buffer " .. tostring(bufnr) .. " is deleted", vim.log.levels.INFO)
    bufnr_to_mbufnr[bufnr] = nil
    return bufnr
end

M.refresh_all_minimap_buffers = function()
    local buffer_list = api.nvim_list_bufs()
    for _, bufnr in ipairs(buffer_list) do
        M.refresh_minimap_buffer(bufnr)
    end
end

M.wipe_out_all_minimap_buffers = function()
    local buffer_list = M.list_buffers()
    for _, bufnr in ipairs(buffer_list) do
        M.wipe_out_minimap_buffer(bufnr)
    end
end

return M
