local stdio = require('@lune/stdio')

local c = {
    reset = stdio.color('reset'),
    white = '\27[38;2;245;240;244m',
    pink = '\27[38;2;235;205;223m',
    eye = '\27[38;2;110;85;75m',
    title = '\27[38;2;245;189;230m',
    text = '\27[38;2;255;245;225m',
    soft = '\27[38;2;210;196;255m',
    muted = '\27[38;2;130;120;150m',
    green = '\27[38;2;180;230;180m',
    red = '\27[38;2;230;150;150m',
    yellow = '\27[38;2;255;220;150m',
}

local BUNNY = {
    c.white .. ' ██  ██ ',
    c.white .. ' ██  ██ ',
    c.white .. '████████',
    c.white .. '██' .. c.eye .. '█' .. c.white .. '██' .. c.eye .. '█' .. c.white .. '██',
    c.white .. '███' .. c.pink .. '█' .. c.white .. '████',
    c.white .. ' ██████ ',
}

local BAR_WIDTH = 12
local FILL = '█'
local EMPTY = '░'
local CURSOR_UP = '\27[%dA'
local CURSOR_START = '\27[0G'
local CLEAR_LINE = '\27[2K'

local function visible_len(text: string): number
    local stripped = string.gsub(text, '\27%[[%d;]*m', '')
    return utf8.len(stripped) or 0
end

local function pad_right(text: string, width: number): string
    local len = visible_len(text)
    return text .. string.rep(' ', math.max(0, width - len))
end

local function status(ok: boolean, label: string): string
    local dot = ok and (c.green .. '●') or (c.red .. '●')
    return dot .. c.muted .. ' ' .. label .. c.reset
end

local function render_bar(current: number, total: number): string
    local ratio = if total > 0 then math.min(current / total, 1) else 0
    local filled = math.floor(ratio * BAR_WIDTH)
    local bar = c.soft .. string.rep(FILL, filled) .. c.muted .. string.rep(EMPTY, BAR_WIDTH - filled) .. c.reset
    local pct = c.muted .. math.floor(ratio * 100) .. '%' .. c.reset
    return bar .. ' ' .. pct
end

local function print_with_bunny(lines: { string })
    local leftWidth = 44
    local leftMargin = '  '
    local gap = '   '
    local bunnyStart = 2
    local total = math.max(#lines, bunnyStart + #BUNNY - 1)

    for i = 1, total do
        local left = lines[i] or ''
        local bi = i - bunnyStart + 1
        local right = bi >= 1 and bi <= #BUNNY and BUNNY[bi] or ''
        print(leftMargin .. pad_right(left, leftWidth) .. gap .. right .. c.reset)
    end
end

local function clear_lines(n: number)
    for _ = 1, n do
        stdio.write(string.format(CURSOR_UP, 1) .. CURSOR_START .. CLEAR_LINE)
    end
end

local function welcome(version: string, has_key: boolean, has_cookie: boolean)
    print_with_bunny({
        '',
        c.title .. stdio.style('bold') .. 'bnnuy' .. c.muted .. '  ' .. version .. stdio.style('reset'),
        '',
        c.text .. "Let's get started.",
        '',
        status(has_key, 'api key'),
        status(has_cookie, 'cookie'),
        '',
        c.soft .. '○ commands:',
        c.muted .. '  upload',
        c.muted .. '  import <id>',
        c.muted .. '  help',
        '',
    })
end

local function help(version: string)
    print_with_bunny({
        '',
        c.title .. stdio.style('bold') .. 'bnnuy' .. c.muted .. '  ' .. version .. stdio.style('reset'),
        '',
        c.soft .. '○ commands:',
        c.muted .. '  upload',
        c.muted .. '  import <id>',
        c.muted .. '  help',
        '',
        c.soft .. '○ options:',
        c.muted .. '  --api-key, -k',
        c.muted .. '  --output,  -o',
        c.muted .. '  --force,   -f',
        c.muted .. '  --help,    -h',
        '',
        c.soft .. '○ environment:',
        c.muted .. '  ROBLOX_API_KEY=your-api-key',
        c.muted .. '  ROBLOX_COOKIE=your-cookie',
        '',
    })
end

export type progress_state = {
    badges: { current: number, total: number, failed: number },
    passes: { current: number, total: number, failed: number },
    products: { current: number, total: number, failed: number },
    label: string,
    done: boolean,
}

local progress_lines = 0

local function render_progress(version: string, s: progress_state)
    local function track(name: string, t: { current: number, total: number, failed: number }): string
        local bar = render_bar(t.current, t.total)
        local label = pad_right(c.muted .. name, 14)
        local count = c.muted .. t.current .. '/' .. t.total
        local warn = t.failed > 0 and (c.yellow .. '  ⚠ ' .. t.failed .. ' failed' .. c.reset) or ''
        return label .. bar .. '  ' .. count .. warn
    end

    local lines = {
        '',
        c.title .. stdio.style('bold') .. 'bnnuy' .. c.muted .. '  ' .. version .. stdio.style('reset'),
        '',
        c.text .. s.label,
        '',
        track('badges', s.badges),
        track('passes', s.passes),
        track('products', s.products),
        '',
    }
    local rendered_lines = math.max(#lines, 2 + #BUNNY - 1)

    if progress_lines > 0 then
        clear_lines(progress_lines)
    end

    print_with_bunny(lines)
    progress_lines = rendered_lines
end

local function start_progress(version: string): (progress_state) -> ()
    progress_lines = 0

    local state: progress_state = {
        badges = { current = 0, total = 0, failed = 0 },
        passes = { current = 0, total = 0, failed = 0 },
        products = { current = 0, total = 0, failed = 0 },
        label = 'starting...',
        done = false,
    }

    render_progress(version, state)

    return function(next: progress_state)
        render_progress(version, next)
    end
end

local function finish(ok: boolean, message: string)
    local dot = ok and (c.green .. '✓') or (c.red .. '✗')
    print('\n  ' .. dot .. c.reset .. '  ' .. message .. '\n')
end

local function error(message: string)
    print('  ' .. c.red .. '✗' .. c.reset .. '  ' .. message)
end

local function warn(message: string)
    print('  ' .. c.yellow .. '⚠' .. c.reset .. '  ' .. message)
end

return table.freeze {
    c = c,
    finish = finish,
    error = error,
    warn = warn,
    start_progress = start_progress,
    help = help,
    welcome = welcome
}