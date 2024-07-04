local M = {}

---@class Neominimap.InternalConfig
---@field auto_enable boolean
---@field log_path string
---@field log_level integer
---@field notification_level integer
---@field exclude_filetypes (string[])
---@field exclude_buftypes (string[])
---@field buf_filter fun(bufnr: integer): boolean
---@field win_filter fun(winid: integer): boolean
---@field max_minimap_height number?
---@field minimap_width number
---@field x_multiplier integer
---@field y_multiplier integer
---@field delay integer
---@field diagnostic Neominimap.InternalDiagnosticConfig
---@field use_highlight boolean
---@field use_treesitter boolean
---@field use_git boolean
---@field z_index number
---@field window_border string | string[]

---@class Neominimap.InternalDiagnosticConfig
---@field enable boolean
---@field severity integer
---@field priority Neominimap.InternalDiagnosticPriority
---@field colors Neominimap.InternalDiagnosticColors

---@class Neominimap.InternalDiagnosticPriority
---@field ERROR integer
---@field WARN integer
---@field INFO integer
---@field HINT integer
---
---@class Neominimap.InternalDiagnosticColors
---@field ERROR string
---@field WARN string
---@field INFO string
---@field HINT string

---@enum Neominimap.Relative
M.RELATIVE = {
    win = "win",
    editor = "editor",
}

---@param name string
---@return string
local get_hl_fg = function(name)
    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    return string.format("#%06x", hl.fg)
end

---@type Neominimap.InternalConfig
M.default_config = {
    auto_enable = true,
    log_level = vim.log.levels.OFF,
    notification_level = vim.log.levels.INFO,
    log_path = vim.fn.stdpath("data") .. "/neominimap.log",
    exclude_filetypes = { "help" },
    exclude_buftypes = {
        "nofile",
        "nowrite",
        "quickfix",
        "terminal",
        "prompt",
    },
    buf_filter = function()
        return true
    end,
    win_filter = function()
        return true
    end,
    max_minimap_height = nil,
    minimap_width = 20,
    x_multiplier = 4,
    y_multiplier = 1,
    delay = 200,
    diagnostic = {
        enable = true,
        severity = vim.diagnostic.severity.WARN,
        colors = {
            ERROR = get_hl_fg("DiagnosticError"),
            WARN = get_hl_fg("DiagnosticWarn"),
            INFO = get_hl_fg("DiagnosticInfo"),
            HINT = get_hl_fg("DiagnosticHint"),
        },
        priority = {
            ERROR = 100,
            WARN = 90,
            INFO = 80,
            HINT = 70,
        },
    },
    use_highlight = true,
    use_treesitter = true,
    use_git = true,
    z_index = 1, -- The z-index the floating window will be on
    window_border = "single", -- The border style of the floating window (accepts all usual options)
}

return M
