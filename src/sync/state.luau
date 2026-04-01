-- modules
local fs = require('@lune/fs')
local process = require('@lune/process')
local serde = require('@lune/serde')

local types = require('./types')
type badge_settings = types.badge_settings
type gamepass_settings = types.gamepass_settings
type product_settings = types.product_settings

local yaml = require('./yaml')

-- this
export type state = {
    experience_id: number,
    badges: { [string]: { id: number, config: badge_settings, icon_hash: string } }?,
    passes: { [string]: { id: number, config: gamepass_settings, icon_hash: string } }?,
    products: { [string]: { id: number, config: product_settings, icon_hash: string } }?,
}

local STATE_FILE = '.bnnuy-state.yml'
local MANIFEST_FILE = 'bnnuy.yml'

local function make_base_manifest(experience_id: number): types.config
    return {
        experience = {
            id = experience_id,
            badges = {},
            passes = {},
            products = {},
        }
    }
end

local function hash_file(path: string): string
    return serde.hash('sha256', fs.readFile(path))
end

local function load_state(): state?
    if not fs.isFile(STATE_FILE) then return nil end
    return yaml.read_file(STATE_FILE)
end

local function compact_state(data: state): state
    local compacted: state = {
        experience_id = data.experience_id,
    }

    if data.badges and next(data.badges) ~= nil then
        compacted.badges = data.badges
    end

    if data.passes and next(data.passes) ~= nil then
        compacted.passes = data.passes
    end

    if data.products and next(data.products) ~= nil then
        compacted.products = data.products
    end

    return compacted
end

local function save_state(data: state)
    yaml.write_file(STATE_FILE, compact_state(data))
end

local function read_manifest(path: string?): types.config
    local manifest_path = path or MANIFEST_FILE

    if not fs.isFile(manifest_path) then
        print('manifest file doesnt exist')
        process.exit(0)
    end

    return yaml.read_file(manifest_path)
end

local function load_manifest(path: string?): types.config?
    local manifest_path = path or MANIFEST_FILE

    if not fs.isFile(manifest_path) then
        return nil
    end

    return yaml.read_file(manifest_path)
end

local function save_manifest(config: types.config, path: string?)
    local manifest_path = path or MANIFEST_FILE
    yaml.write_file(manifest_path, config)
end

local function clean_yaml_files(extra_manifest_path: string?)
    local yaml_files = {
        MANIFEST_FILE,
        STATE_FILE,
    }

    if extra_manifest_path then
        table.insert(yaml_files, extra_manifest_path)
    end

    yaml.clean_files(yaml_files)
end

local function create_initial_state(experience_id: number): state
    return {
        experience_id = experience_id,
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
    create_initial_state = create_initial_state,
    clean_yaml_files = clean_yaml_files
}