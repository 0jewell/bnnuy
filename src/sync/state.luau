-- modules
local serde = require('@lune/serde')
local fs = require('@lune/fs')
local process = require('@lune/process')

local types = require('./types')
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

local function make_base_manifest(experience_id: number): types.config
    return {
        experience = {
            id = experience_id,
            badges = {},
            passes = {},
            products = {}
        }
    }
end

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

local function read_manifest(path: string?): types.config
    local manifest_path = path or MANIFEST_FILE

    if not fs.isFile(manifest_path) then
        print('manifest file doesnt exist')
        process.exit(0)
    end

    return serde.decode('yaml', fs.readFile(manifest_path))
end

local function load_manifest(path: string?): types.config?
    local manifest_path = path or MANIFEST_FILE
    if not fs.isFile(manifest_path) then
        return nil
    end

    return serde.decode('yaml', fs.readFile(manifest_path))
end

local function save_manifest(config: types.config, path: string?)
    local manifest_path = path or MANIFEST_FILE
    fs.writeFile(manifest_path, serde.encode('yaml', config, true))
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
    load_manifest = load_manifest,
    make_manifest = make_base_manifest,
    save_manifest = save_manifest,
    create_initial_state = create_initial_state
}