-- modules
local process = require('@lune/process')
local fs = require('@lune/fs')

local sync = require('@lib/sync')
local user = require('@lib/api/user')
local ui = require('@lib/ui')

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

local function parse_import_options(args: { string }): (number, string?, boolean)
	local experience_id: number? = nil
	local output: string? = nil
	local force = false

	local i = 1
	while i <= #args do
		local arg = args[i]

		if arg == '--force' or arg == '-f' then
			force = true
			i += 1
			continue
		end

		if arg == '--output' or arg == '-o' then
			output = args[i + 1]
			assert(output, 'missing value for --output')
			i += 2
			continue
		end

		if arg == '--api-key' or arg == '-k' then
			assert(args[i + 1], 'missing value for --api-key')
			i += 2
			continue
		end

		if arg ~= 'import' and string.sub(arg, 1, 1) ~= '-' and not experience_id then
			experience_id = tonumber(arg)
		end

		i += 1
	end

	assert(experience_id, 'missing experience id')
	return experience_id, output, force
end

local function print_welcome()
	local env = load_env()

	local has_key = get_api_key(process.args, env) ~= nil
	local has_cookie = get_cookie(env) ~= ''

	ui.welcome(version.version, has_key, has_cookie)
end

local function print_help()
	ui.help(version.version)
end

local function cmd_upload(args: { string })
	local env = load_env()

	local api_key = get_api_key(args, env) :: string
	if not api_key then
		ui.error('no API key provided')
		print_help()
		process.exit(1)
	end

	local cookie = get_cookie(env)

	local success, err = pcall(function()
		sync.all(api_key, cookie, version.version)
	end)

	if not success then
		ui.error(`sync failed: {tostring(err)}`)
		process.exit(1)
	end
end

local function cmd_import(args: { string })
	local env = load_env()
	local api_key = get_api_key(args, env) :: string
	if not api_key then
		ui.error('no API key provided')
		print_help()
		process.exit(1)
	end

	local cookie = get_cookie(env)
	local experience_id, output, force = parse_import_options(args)

	local success, err = pcall(function()
		sync.import(api_key, cookie, experience_id, output, force, version.version)
	end)

	if not success then
		ui.error(`import failed: {tostring(err)}`)
		process.exit(1)
	end
end

-- main
local args = process.args

if #args == 0 then
	print_welcome()
	process.exit(0)
end

local command = args[1]

if command == 'upload' or command == 'sync' then
	cmd_upload(args)
elseif command == 'import' then
	cmd_import(args)
elseif command == 'help' or command == '--help' or command == '-h' then
	print_help()
else
	ui.error(`unknown command: {command}`)
	print_help()
	process.exit(1)
end