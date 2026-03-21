-- modules
local process = require('@lune/process')
local stdio = require('@lune/stdio')
local fs = require('@lune/fs')

local sync = require('@lib//sync')
local user = require('@lib/api/user')

local version = require('@self/version')

-- helpers
local function load_env(): { [string]: string }
    if not fs.isFile('.env') then
        return {}
    end

    local env = {}
    local content = fs.readFile('.env')

    for line in string.gmatch(content, '[^\r\n]+') do
        line = string.gsub(line, '^%s*(.-)%s*$', '%1')

        if line ~= '' and not string.match(line, '^#') then
            local key, value = string.match(line, '([^=]+)=(.+)')
            if key and value then
                key = string.gsub(key, '^%s*(.-)%s*$', '%1')
                value = string.gsub(value, '^%s*(.-)%s*$', '%1')
                value = string.gsub(value, '^["\'](.+)["\']$', '%1')
                env[key] = value
            end
        end
    end

    return env
end

local function get_api_key(
    args: { string },
    env: { [string]: string }
): string?
    for i, arg in args do
        if arg == '--api-key' or arg == '-k' then
            return args[i + 1]
        end
    end

    return env.ROBLOX_API_KEY
end

local function get_cookie(env: { [string]: string }): string
    return user.get_cookie(env.ROBLOX_COOKIE)
end

local function print_help()
    print(stdio.style('bold') .. 'bnnuy ' .. version.version .. stdio.style('reset') .. ' - roblox asset management\n')
    print(stdio.style('bold') .. 'usage:' .. stdio.style('reset'))
    print('  bnnuy <command> [options]\n')
    print(stdio.style('bold') .. 'commands:' .. stdio.style('reset'))
    print('  upload             upload badges, passes, and products')
    print('  help               show this help message\n')
    print(stdio.style('bold') .. 'options:' .. stdio.style('reset'))
    print('  --api-key, -k      roblox API key (or use .env)')
    print('  --help, -h         show help\n')
    print(stdio.style('bold') .. 'enviroment:' .. stdio.style('reset'))
    print('  Create a .env file with:')
    print('    ROBLOX_API_KEY=your-api-key')
    print('    ROBLOX_COOKIE=your-cookie (optional)')
end

local function cmd_upload(args: { string })
    local env = load_env()
    print(stdio.color('cyan') .. 'starting upload...' .. stdio.color('reset') .. '\n')

    local api_key = get_api_key(args, env) :: string
    if not api_key then
        print(stdio.color('red') .. 'no API key provided' .. stdio.color('reset'))
        print_help()
        process.exit(1)
    end

    print(stdio.color('green') .. '✓' .. stdio.color('reset') .. ' API key loaded')

    local cookie = get_cookie(env)
    print(stdio.color('green') .. '✓' .. stdio.color('reset') .. ' Cookie loaded\n')

    local success, err = pcall(function()
        sync.all(api_key, cookie)
    end)

    if not success then
        print('\n' .. stdio.color('red') .. `sync failed: {tostring(err)}` .. stdio.color('reset'))
        process.exit(1)
    end

    print('\n' .. stdio.color('green') .. 'upload complete' .. stdio.color('reset'))
end

-- this
local args = process.args

if #args == 0 then
    print_help()
    process.exit(0)
end

local command = args[1]

if command == 'upload' or command == 'sync' then
    cmd_upload(args)
elseif command == 'help' or command == '--help' or command == '-h' then
    print_help()
else
    print(stdio.color('red') .. 'unknown command: ' .. command .. stdio.color('reset') .. '\n')
    print_help()
    process.exit(1)
end