-- modules
local fs = require('@lune/fs')
local net = require('@lune/net')
local serde = require('@lune/serde')

local ui = require('@lib/ui')
export type progress_state = ui.progress_state
export type progress_cb = (progress_state) -> ()

local api = require('@lib/api')
export type api_key = api.api_key

local user = require('@lib/api/user')
export type cookie = user.cookie

local state = require('@lib/sync/state')
export type state_data = state.state

local diff = require('@lib/sync/diff')
local types = require('@lib/sync/types')

export type thumbnail_response = { data: { { imageUrl: string? } } }
local MAX_ACTIVITY_NAME_LEN = 28

local function print_failure_report(
    operation: string,
    failures: { string }
)
    if #failures == 0 then
        ui.finish(true, `{operation} complete`)
        return
    end

    ui.finish(false, `{operation} complete with {#failures} failure(s)`)
    for _, failure in failures do
        ui.warn(failure)
    end
end

local function truncate_activity_name(name: string): string
    local len = utf8.len(name)
    if not len or len <= MAX_ACTIVITY_NAME_LEN then
        return name
    end

    local cut_index = utf8.offset(name, MAX_ACTIVITY_NAME_LEN + 1)
    if cut_index then
        return string.sub(name, 1, cut_index - 1) .. '...'
    end

    return string.sub(name, 1, MAX_ACTIVITY_NAME_LEN) .. '...'
end

local function set_activity_label(
    progress: progress_state,
    update_progress: progress_cb,
    action: string,
    asset_type: string,
    key: string
)
    local safe_key = truncate_activity_name(key)
    progress.label = `{action} {asset_type} '{safe_key}'...`
    update_progress(progress)
end

local function icon_name_from_item_name(name: string): string
    local normalized = string.lower(name)
    normalized = string.gsub(normalized, '[^%w]+', '-')
    normalized = string.gsub(normalized, '^-+', '')
    normalized = string.gsub(normalized, '-+$', '')
    return if normalized == '' then 'asset' else normalized
end

local function try_download_remote_icon(icon_asset_id: number, output_path: string): boolean
    local thumbnail_url =
        `https://thumbnails.roblox.com/v1/assets?assetIds={icon_asset_id}&size=420x420&format=Png&isCircular=false`

    local thumbnail_response = net.request({
        url = thumbnail_url,
        method = 'GET',
    })
    if not thumbnail_response.ok or thumbnail_response.statusCode ~= 200 then
        return false
    end

    local payload: thumbnail_response = serde.decode('json', thumbnail_response.body)
    if #payload.data == 0 then
        return false
    end

    local image_url = payload.data[1].imageUrl
    if not image_url or image_url == '' then
        return false
    end

    local image_response = net.request({
        url = image_url,
        method = 'GET',
    })
    if not image_response.ok or image_response.statusCode ~= 200 then
        return false
    end

    fs.writeFile(output_path, image_response.body)
    return true
end

local function ensure_icon_file(
    asset_type: string,
    asset_id: number,
    item_name: string,
    icon_asset_id: number?
): string
    local icon_dir = '.bnnuy-icons'
    if not fs.isDir(icon_dir) then
        fs.writeDir(icon_dir)
    end

    local file_base_name = icon_name_from_item_name(item_name)
    local icon_path = `{icon_dir}/{file_base_name}-{asset_id}.png`

    if not fs.isFile(icon_path) then
        local downloaded = false
        if icon_asset_id then
            downloaded = try_download_remote_icon(icon_asset_id, icon_path)
        end

        if not downloaded then
            fs.writeFile(icon_path, `imported placeholder icon for {asset_type} {asset_id} ({item_name})`)
        end
    end

    return icon_path
end

local function key_base_from_name(name: string): string
    local key = string.lower(name)
    key = string.gsub(key, '[^%w]+', '_')
    key = string.gsub(key, '^_+', '')
    key = string.gsub(key, '_+$', '')

    if key == '' then
        return 'asset'
    end
    if string.match(key, '^%d') then
        return `asset_{key}`
    end
    return key
end

local function unique_key(
    name: string,
    manifest_entries: { [string]: any },
    state_entries: { [string]: any }
): string
    local base = key_base_from_name(name)
    local key = base
    local index = 2

    while manifest_entries[key] or state_entries[key] do
        key = `{base}_{index}`
        index += 1
    end

    return key
end

local function contains_id(entries: { [string]: any }?, id: number): boolean
    if not entries then
        return false
    end

    for _, item in entries do
        if item.id == id then
            return true
        end
    end

    return false
end

local function get_or_create_badges_state(data: state_data): { [string]: any }
    local badges_state: any = data.badges

    if not badges_state then
        badges_state = {}
        data.badges = badges_state
    end

    return badges_state
end

local function get_or_create_passes_state(data: state_data): { [string]: any }
    local passes_state: any = data.passes

    if not passes_state then
        passes_state = {}
        data.passes = passes_state
    end

    return passes_state
end

local function get_or_create_products_state(data: state_data): { [string]: any }
    local products_state: any = data.products

    if not products_state then
        products_state = {}
        data.products = products_state
    end

    return products_state
end

local function ensure_manifest_has_state(manifest: types.config, data: state_data)
    local badges_settings = manifest.experience.badges or {}
    manifest.experience.badges = badges_settings

    local passes_settings = manifest.experience.passes or {}
    manifest.experience.passes = passes_settings

    local products_settings = manifest.experience.products or {}
    manifest.experience.products = products_settings

    if data.badges then
        for key, stored in data.badges do
            if not badges_settings[key] then
                badges_settings[key] = diff.clone_snapshot(stored.config)
            end
        end
    end

    if data.passes then
        for key, stored in data.passes do
            if not passes_settings[key] then
                passes_settings[key] = diff.clone_snapshot(stored.config)
            end
        end
    end

    if data.products then
        for key, stored in data.products do
            if not products_settings[key] then
                products_settings[key] = diff.clone_snapshot(stored.config)
            end
        end
    end
end

local function coerce_string_field(
    value: any,
    field_path: string,
    allow_empty: boolean?
): string
    if type(value) == 'string' then
        if not allow_empty then
            assert(value ~= '', `invalid manifest field '{field_path}': expected non-empty string`)
        end
        return value
    end

    if type(value) == 'number' then
        return tostring(value)
    end

    error(`invalid manifest field '{field_path}': expected non-empty string`)
end

local function coerce_number_field(value: any, field_path: string): number
    if type(value) == 'number' then
        return value
    end

    if type(value) == 'string' then
        local parsed = tonumber(value)
        if parsed then
            return parsed
        end
    end

    error(`invalid manifest field '{field_path}': expected number`)
end

local function coerce_boolean_field(value: any, field_path: string): boolean
    if type(value) == 'boolean' then
        return value
    end

    error(`invalid manifest field '{field_path}': expected boolean`)
end

local function validate_badge_config(key: string, config: types.badge_settings)
    local base = `experience.badges.{key}`

    config.name = coerce_string_field(config.name, `{base}.name`)
    config.description = coerce_string_field(config.description, `{base}.description`, true)

    config.icon = coerce_string_field(config.icon, `{base}.icon`)
    assert(fs.isFile(config.icon), `invalid manifest field '{base}.icon': file not found ({config.icon})`)
end

local function validate_pass_config(key: string, config: types.gamepass_settings)
    local base = `experience.passes.{key}`
    config.name = coerce_string_field(config.name, `{base}.name`)

    if config.description == nil then
        config.description = ''
    else
        config.description = coerce_string_field(config.description, `{base}.description`, true)
    end

    config.icon = coerce_string_field(config.icon, `{base}.icon`)
    assert(fs.isFile(config.icon), `invalid manifest field '{base}.icon': file not found ({config.icon})`)

    if config.price ~= nil then
        config.price = coerce_number_field(config.price, `{base}.price`)
    end

    if config.forSale ~= nil then
        config.forSale = coerce_boolean_field(config.forSale, `{base}.forSale`)
    end

    if config.forSale == true then
        assert(config.price ~= nil, `invalid manifest field '{base}.price': expected number when forSale is true`)
    end
end

local function normalize_stored_pass_config(key: string, config: types.gamepass_settings)
    local base = `state.passes.{key}.config`
    config.name = coerce_string_field(config.name, `{base}.name`)

    if config.description == nil then
        config.description = ''
    else
        config.description = coerce_string_field(config.description, `{base}.description`, true)
    end

    config.icon = coerce_string_field(config.icon, `{base}.icon`)

    if config.price ~= nil then
        config.price = coerce_number_field(config.price, `{base}.price`)
    end

    if config.forSale ~= nil then
        config.forSale = coerce_boolean_field(config.forSale, `{base}.forSale`)
    end
end

local function validate_product_config(key: string, config: types.product_settings)
    local base = `experience.products.{key}`
    config.name = coerce_string_field(config.name, `{base}.name`)

    if config.description == nil then
        config.description = ''
    else
        config.description = coerce_string_field(config.description, `{base}.description`, true)
    end

    config.icon = coerce_string_field(config.icon, `{base}.icon`)
    assert(fs.isFile(config.icon), `invalid manifest field '{base}.icon': file not found ({config.icon})`)

    if config.price ~= nil then
        config.price = coerce_number_field(config.price, `{base}.price`)
    end
end

return table.freeze {
    print_failure_report = print_failure_report,
    set_activity_label = set_activity_label,
    ensure_icon_file = ensure_icon_file,
    unique_key = unique_key,
    contains_id = contains_id,
    get_or_create_badges_state = get_or_create_badges_state,
    get_or_create_passes_state = get_or_create_passes_state,
    get_or_create_products_state = get_or_create_products_state,
    ensure_manifest_has_state = ensure_manifest_has_state,
    validate_badge_config = validate_badge_config,
    validate_pass_config = validate_pass_config,
    normalize_stored_pass_config = normalize_stored_pass_config,
    validate_product_config = validate_product_config
}
