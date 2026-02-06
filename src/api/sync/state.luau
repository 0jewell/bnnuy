-- modules
local serde = require('@lune/serde')
local fs = require('@lune/fs')
local process = require('@lune/process')

local types = require('@lib/api/sync/types')
type badge_settings = types.badge_settings
type gamepass_settings = types.gamepass_settings
type product_settings = types.product_settings

-- this
export type state = {
    experience_id: number,
    badges: { [string]: { id: number, config: badge_settings, icon_hash: string } },
    passes: { [string]: { id: number, config: gamepass_settings, icon_hash: string } },
    products: { [string]: { id: number, config: product_settings, icon_hash: string } },
}

local STATE_FILE = '.bnnuy-state.yml'
local MANIFEST_FILE = 'bnnuy.yml'

local function hash_file(path: string): string
    return serde.hash('sha256', fs.readFile(path))
end

local function load_state(): state?
    if not fs.isFile(STATE_FILE) then return nil end
    return serde.decode('yaml', fs.readFile(STATE_FILE))
end

local function save_state(state: state)
    fs.writeFile(STATE_FILE, serde.encode('yaml', state, true))
end

local function read_manifest(): types.config
    if not fs.isFile(MANIFEST_FILE) then
        print('manifest file doesnt exist')
        process.exit(0)
    end

    return serde.decode('yaml', fs.readFile(MANIFEST_FILE))
end

local function create_initial_state(experience_id: number): state
    return {
        experience_id = experience_id,
        badges = {},
        passes = {},
        products = {},
    }
end

-- end
return table.freeze {
    hash_file = hash_file,
    load_state = load_state,
    save_state = save_state,
    read_manifest = read_manifest,
    create_initial_state = create_initial_state
}