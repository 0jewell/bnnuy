-- modules
local fs = require('@lune/fs')
local net = require('@lune/net')
local serde = require('@lune/serde')

local ui = require('@lib/ui')
type progress_state = ui.progress_state

local api = require('@lib/api')
type api_key = api.api_key

local user = require('@lib/api/user')
type cookie = user.cookie

local badges = require('@lib/rbx/badges')
local passes = require('@lib/rbx/gamepasses')
local products = require('@lib/rbx/products')

local state = require('@self/state')
type state_data = state.state

local diff = require('@self/diff')
local types = require('@self/types')

export type progress_cb = (progress_state) -> ()

-- this
local function icon_name_from_item_name(name: string): string
    local normalized = string.lower(name)
    normalized = string.gsub(normalized, '[^%w]+', '-')
    normalized = string.gsub(normalized, '^-+', '')
    normalized = string.gsub(normalized, '-+$', '')

    if normalized == '' then
        return 'asset'
    end

    return normalized
end

type thumbnail_response = { data: { { imageUrl: string? } } }

local function try_download_remote_icon(icon_asset_id: number, output_path: string): boolean
    local thumb_url =
        `https://thumbnails.roblox.com/v1/assets?assetIds={icon_asset_id}&size=420x420&format=Png&isCircular=false`

    local thumb_response = net.request {
        url = thumb_url,
        method = 'GET',
    }
    if not thumb_response.ok or thumb_response.statusCode ~= 200 then
        return false
    end

    local payload: thumbnail_response = serde.decode('json', thumb_response.body)
    if #payload.data == 0 then
        return false
    end

    local image_url = payload.data[1].imageUrl
    if not image_url or image_url == '' then
        return false
    end

    local image_response = net.request {
        url = image_url,
        method = 'GET',
    }
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
    local path = `{icon_dir}/{file_base_name}-{asset_id}.png`

    if not fs.isFile(path) then
        local downloaded = false
        if icon_asset_id then
            downloaded = try_download_remote_icon(icon_asset_id, path)
        end

        if not downloaded then
            fs.writeFile(path, `imported placeholder icon for {asset_type} {asset_id} ({item_name})`)
        end
    end

    return path
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

local function unique_key(name: string, a: { [string]: any }, b: { [string]: any }): string
    local base = key_base_from_name(name)
    local key = base
    local index = 2

    while a[key] or b[key] do
        key = `{base}_{index}`
        index += 1
    end

    return key
end

local function contains_id(entries: { [string]: any }, id: number): boolean
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

local function ensure_state_tables(data: state_data)
    if not data.badges then data.badges = {} end
    if not data.passes then data.passes = {} end
    if not data.products then data.products = {} end
end

local function ensure_manifest_has_state(
    manifest: types.config,
    data: state_data
)
	ensure_state_tables(data)

	local badges_settings = manifest.experience.badges or {}
	manifest.experience.badges = badges_settings

	local passes_settings = manifest.experience.passes or {}
	manifest.experience.passes = passes_settings

	local products_settings = manifest.experience.products or {}
	manifest.experience.products = products_settings

	for key, stored in data.badges do
		if not badges_settings[key] then
			badges_settings[key] = diff.clone_snapshot(stored.config)
		end
	end

	for key, stored in data.passes do
		if not passes_settings[key] then
			passes_settings[key] = diff.clone_snapshot(stored.config)
		end
	end

	for key, stored in data.products do
		if not products_settings[key] then
			products_settings[key] = diff.clone_snapshot(stored.config)
		end
	end
end

local function coerce_string_field(value: any, field_path: string, allow_empty: boolean?): string
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

local function sync_badges(
    api_key: api_key,
    experience_id: number,
    badge_settings: { [string]: types.badge_settings },
    data: state_data,
    ps: ui.progress_state,
    cb: progress_cb
)
    local items = {}
    for key, config in badge_settings do
        table.insert(items, { key = key, config = config })
    end

    ps.badges.total = #items
    cb(ps)

    for _, item in items do
        local key = item.key
        local config = item.config

        local success, err = pcall(function()
            validate_badge_config(key, config)

            if not data.badges then data.badges = {} end
            local stored = data.badges[key]
            local icon_hash = state.hash_file(config.icon)

            if stored then
                local changes = diff.from(stored.config, config)
                local icon_changed = stored.icon_hash ~= icon_hash

                if changes or icon_changed then
                    local needs_update = changes and (changes.name or changes.description or changes.enabled)
                    if needs_update then
                        badges.update_badge(
                            api_key,
                            stored.id,
                            config.name,
                            config.description,
                            config.enabled ~= false
                        )
                    end

                    if icon_changed then
                        badges.update_badge_icon(api_key, stored.id, config.icon)
                    end

                    data.badges[key].config = diff.clone_snapshot(config)
                    data.badges[key].icon_hash = icon_hash
                end
            else
                local response = badges.create_badge(
                    api_key,
                    experience_id,
                    config.name,
                    config.description,
                    config.icon,
                    1,
                    0,
                    config.enabled ~= false
                )
                data.badges[key] = {
                    id = response.id,
                    config = diff.clone_snapshot(config),
                    icon_hash = icon_hash,
                }
            end
        end)

        if success then
            ps.badges.current += 1
        else
            ps.badges.failed += 1
            ui.warn(`badge '{key}': {tostring(err)}`)
        end

        cb(ps)
    end
end

local function sync_passes(
    cookie: cookie,
    experience_id: number,
    pass_configs: { [string]: types.gamepass_settings },
    data: state_data,
    ps: ui.progress_state,
    cb: progress_cb
)
    local items = {}
    for key, config in pass_configs do
        table.insert(items, { key = key, config = config })
    end

    ps.passes.total = #items
    cb(ps)

    local remote_passes_by_name: { [string]: number }? = nil
    local processed_pass_ids: { [number]: string } = {}

    local function ensure_remote_passes_index()
        if remote_passes_by_name then return remote_passes_by_name end

        local new_index = {}
        remote_passes_by_name = new_index

        for _, remote_pass in passes.get_all_game_passes(cookie, experience_id) do
            if not new_index[remote_pass.name] then
                new_index[remote_pass.name] = remote_pass.gamePassId
            end
        end

        return new_index
    end

    for _, item in items do
        local key = item.key
        local config = item.config

        local success, err: any = pcall(function()
            validate_pass_config(key, config)

            if not data.passes then data.passes = {} end
            local stored = data.passes[key]
            local icon_hash = state.hash_file(config.icon)

            if stored then
                normalize_stored_pass_config(key, stored.config)

                if not stored.id then
                    local index = ensure_remote_passes_index()

                    local resolved_id = index[config.name]
                    assert(resolved_id, `could not resolve game pass id for '{config.name}'`)

                    stored.id = resolved_id
                    data.passes[key].id = resolved_id
                end

                if processed_pass_ids[stored.id] then
                    local original_key = processed_pass_ids[stored.id]
                    ui.warn(`duplicate pass mapping: '{key}' and '{original_key}' point to the same id ({stored.id}); skipping '{key}'`)
                    return
                end
                processed_pass_ids[stored.id] = key

                local changes = diff.from(stored.config, config)
                local icon_changed = stored.icon_hash ~= icon_hash

                if changes or icon_changed then
                    passes.update_game_pass(
                        cookie,
                        experience_id,
                        stored.id,
                        config.name,
                        config.description,
                        config.price,
                        if icon_changed and config.icon then config.icon else nil
                    )
                    data.passes[key].config = diff.clone_snapshot(config)
                    data.passes[key].icon_hash = icon_hash
                end
            else
                local response = passes.create_game_pass(
                    cookie, experience_id,
                    config.name,
                    config.description,
                    config.icon
                )
                data.passes[key] = {
                    id = response.gamePassId,
                    config = diff.clone_snapshot(config),
                    icon_hash = icon_hash,
                }

                passes.update_game_pass(
                    cookie,
                    experience_id,
                    response.gamePassId,
                    config.name,
                    config.description,
                    config.price,
                    config.icon
                )
            end
        end)

        if success then
            ps.passes.current += 1
        else
            ps.passes.failed += 1
            ui.warn(`pass '{key}': {tostring(err)}`)
        end

        cb(ps)
    end
end

local function sync_products(
    cookie: cookie,
    experience_id: number,
    product_settings: { [string]: types.product_settings },
    data: state_data,
    ps: progress_state,
    cb: progress_cb
)
    local items = {}
    for key, config in product_settings do
        table.insert(items, { key = key, config = config })
    end

    ps.products.total = #items
    cb(ps)

    for _, item in items do
        local key = item.key
        local config = item.config

        local success, err = pcall(function()
            validate_product_config(key, config)

            if not data.products then data.products = {} end
            local stored = data.products[key]

            if stored and config.price == nil then
                config.price = stored.config.price
            end

            local icon_hash = state.hash_file(config.icon)

            if stored then
                local changes = diff.from(stored.config, config)
                local icon_changed = stored.icon_hash ~= icon_hash

                if changes or icon_changed then
                    local needs_update = changes and (changes.name or changes.description or changes.price)
                    if needs_update then
                        products.update_developer_product(
                            cookie,
                            experience_id,
                            stored.id,
                            config.name,
                            config.price,
                            config.description
                        )
                    end

                    if icon_changed then
                        products.create_developer_product_icon(cookie, stored.id, config.icon)
                    end

                    data.products[key].config = diff.clone_snapshot(config)
                    data.products[key].icon_hash = icon_hash
                end
            else
                assert(config.price ~= nil, `invalid manifest field 'experience.products.{key}.price': expected number`)
                local response = products.create_developer_product(
                    cookie,
                    experience_id,
                    config.name,
                    config.price,
                    config.description
                )
                data.products[key] = {
                    id = response.productId,
                    config = diff.clone_snapshot(config),
                    icon_hash = icon_hash,
                }

                if config.icon then
                    products.create_developer_product_icon(cookie, response.productId, config.icon)
                end
            end
        end)

        if success then
            ps.products.current += 1
        else
            ps.products.failed += 1
            ui.warn(`product '{key}': {tostring(err)}`)
        end

        cb(ps)
    end
end

local function import_badges(
    api_key: api_key,
    experience_id: number,
    manifest: types.config,
    data: state_data,
    ps: progress_state,
    cb: progress_cb
): number
    local badges_settings = manifest.experience.badges
        or error(`attempt to import badges without ensuring manifest`)

    local imported = 0
    local list = badges.get_all_badges(api_key, experience_id)

    ps.badges.total = #list
    cb(ps)

    for _, badge in list do
        local success, err = pcall(function()
            if not contains_id(data.badges, badge.id) then
                local key = unique_key(badge.name, badges_settings, data.badges)
                local icon = ensure_icon_file('badge', badge.id, badge.name, badge.iconImageId)

                local config: types.badge_settings = {
                    name = badge.name,
                    description = badge.description,
                    icon = icon,
                    enabled = badge.enabled,
                }
                badges_settings[key] = config

                data.badges[key] = {
                    id = badge.id,
                    config = diff.clone_snapshot(config),
                    icon_hash = state.hash_file(icon),
                }

                imported += 1
            end
        end)

        if success then
            ps.badges.current += 1
        else
            ps.badges.failed += 1
            ui.warn(`badge import failed: {tostring(err)}`)
        end

        cb(ps)
    end

    return imported
end

local function import_passes(
    cookie: cookie,
    experience_id: number,
    manifest: types.config,
    data: state_data,
    ps: progress_state,
    cb: progress_cb
): number
    local passes_settings = manifest.experience.passes
        or error(`attempt to import passes without ensuring manifest`)

    local imported = 0
    local list = passes.get_all_game_passes(cookie, experience_id)

    ps.passes.total = #list
    cb(ps)

    for _, pass in list do
        local success, err = pcall(function()
            local pass_id = pass.gamePassId
            local pass_price: number? = nil

            if pass.priceInformation then
                pass_price = pass.priceInformation.defaultPriceInRobux
            end

            local existing_key: string? = nil
            for key, stored in data.passes do

                if stored.id == pass_id then
                    existing_key = key
                    break
                end

                if tostring(stored.config.name) == pass.name then
                    existing_key = key
                end
            end

            if existing_key then
                data.passes[existing_key].id = pass_id

                if passes_settings[existing_key] then
                    passes_settings[existing_key].name = pass.name
                    passes_settings[existing_key].description = pass.description

                    if pass_price ~= nil then
                        passes_settings[existing_key].price = pass_price
                    end
                end

            elseif not contains_id(data.passes, pass_id) then
                local key = unique_key(pass.name, passes_settings, data.passes)
                local icon = ensure_icon_file('pass', pass_id, pass.name, pass.iconAssetId)

                local config: types.gamepass_settings = {
                    name = pass.name,
                    description = pass.description,
                    icon = icon,
                    price = pass_price,
                }
                passes_settings[key] = config

                data.passes[key] = {
                    id = pass_id,
                    config = diff.clone_snapshot(config),
                    icon_hash = state.hash_file(icon),
                }

                imported += 1
            end
        end)

        if success then
            ps.passes.current += 1
        else
            ps.passes.failed += 1
            ui.warn(`pass import failed: {tostring(err)}`)
        end

        cb(ps)
    end

    return imported
end

local function import_products(
    cookie: cookie,
    experience_id: number,
    manifest: types.config,
    data: state_data,
    ps: progress_state,
    cb: progress_cb
): number
    local products_settings = manifest.experience.products
        or error(`attempt to import products without ensuring manifest`)

    local imported = 0
    local list = products.get_all_developer_products(cookie, experience_id)

    ps.products.total = #list
    cb(ps)

    for _, product in list do
        local success, err = pcall(function()
            if not contains_id(data.products, product.productId) then
                local key = unique_key(product.name, products_settings, data.products)
                local icon = ensure_icon_file('product', product.productId, product.name, product.iconImageAssetId)

                local config: types.product_settings = {
                    name = product.name,
                    description = product.description,
                    icon = icon,
                    price = product.priceInRobux,
                }
                products_settings[key] = config

                data.products[key] = {
                    id = product.productId,
                    config = diff.clone_snapshot(config),
                    icon_hash = state.hash_file(icon),
                }

                imported += 1
            end
        end)

        if success then
            ps.products.current += 1
        else
            ps.products.failed += 1
            ui.warn(`product import failed: {tostring(err)}`)
        end

        cb(ps)
    end

    return imported
end

local function sync(api_key: api_key, cookie: cookie, version: string)
    local config = state.read_manifest()

    local data = state.load_state() or state.create_initial_state(config.experience.id)
    assert(data.experience_id == config.experience.id, 'experience id mismatch in state file')

    ensure_state_tables(data)

	local ps: progress_state = {
		badges = { current = 0, total = 0, failed = 0 },
		passes = { current = 0, total = 0, failed = 0 },
		products = { current = 0, total = 0, failed = 0 },
		label = "uploading...",
		done = false,
	}

    local update = ui.start_progress(version)

    if config.experience.badges then
        sync_badges(api_key, config.experience.id, config.experience.badges, data, ps, update)
    end
    if config.experience.passes then
        sync_passes(cookie, config.experience.id, config.experience.passes, data, ps, update)
    end
    if config.experience.products then
        sync_products(cookie, config.experience.id, config.experience.products, data, ps, update)
    end

    state.save_state(data)
    ui.finish(true, 'upload complete')
end

local function import_all_assets(
    api_key: api_key,
    cookie: cookie,
    experience_id: number,
    output: string?,
    force: boolean?,
    version: string
)
    local output_file = output or 'bnnuy.yml'
    local manifest: types.config
    local data: state_data

    if force then
        manifest = state.make_manifest(experience_id)
        data = state.create_initial_state(experience_id)
    else
        data = state.load_state() or state.create_initial_state(experience_id)
        assert(data.experience_id == experience_id, 'experience id mismatch in state file. use --force to overwrite')
        manifest = state.load_manifest(output_file) or state.make_manifest(experience_id)
        assert(manifest.experience.id == experience_id, 'experience id mismatch in manifest file. use --force to overwrite')
        ensure_manifest_has_state(manifest, data)
    end

    ensure_state_tables(data)

	local ps: ui.progress_state = {
		badges = { current = 0, total = 0, failed = 0 },
		passes = { current = 0, total = 0, failed = 0 },
		products = { current = 0, total = 0, failed = 0 },
		label = "importing...",
		done = false,
	}

    local update = ui.start_progress(version)

    local badges_ok, badges_err = pcall(import_badges, api_key, experience_id, manifest, data, ps, update)
    if not badges_ok then
        ps.badges.failed += 1
        ui.warn(`badge import failed: {tostring(badges_err)}`)
    end
    update(ps)

    local passes_ok, passes_err = pcall(import_passes, cookie, experience_id, manifest, data, ps, update)
    if not passes_ok then
        ps.passes.failed += 1
        ui.warn(`pass import failed: {tostring(passes_err)}`)
    end
    update(ps)

    local products_ok, products_err = pcall(import_products, cookie, experience_id, manifest, data, ps, update)
    if not products_ok then
        ps.products.failed += 1
        ui.warn(`product import failed: {tostring(products_err)}`)
    end
    update(ps)

    state.save_manifest(manifest, output_file)
    state.save_state(data)
    ui.finish(true, 'import complete')
end

return table.freeze {
    all    = sync,
    import = import_all_assets
}