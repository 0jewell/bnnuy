-- modules
local ui = require('@lib/ui')

local badges = require('@lib/rbx/badges')
local passes = require('@lib/rbx/gamepasses')
local products = require('@lib/rbx/products')

local state = require('@lib/sync/state')
local diff = require('@lib/sync/diff')

local common = require('./common')
type api_key = common.api_key
type cookie = common.cookie
type state_data = common.state_data
type progress_state = common.progress_state
type progress_cb = common.progress_cb

local types = require('@lib/sync/types')
type manifest_config_type = types.config
type badge_settings_type = types.badge_settings
type pass_settings_type = types.gamepass_settings
type product_settings_type = types.product_settings

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

local MAX_ACTIVITY_NAME_LEN = 28

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

local function sync_badges(
    api_key: api_key,
    experience_id: number,
    badge_settings: { [string]: badge_settings_type },
    data: state_data,
    progress: progress_state,
    update_progress: progress_cb,
    failures: { string }
)
    local items = {}
    for key, config in badge_settings do
        table.insert(items, { key = key, config = config })
    end

    progress.badges.total = #items
    update_progress(progress)

    local badges_state = common.get_or_create_badges_state(data)

    for _, item in items do
        local key = item.key
        local config = item.config

        local success, err = pcall(function()
            common.validate_badge_config(key, config)

            local stored = badges_state[key]
            local icon_hash = state.hash_file(config.icon)

            if stored then
                local changes = diff.from(stored.config, config)
                local icon_changed = stored.icon_hash ~= icon_hash

                if changes or icon_changed then
                    local needs_update = changes and (changes.name or changes.description or changes.enabled)
                    if needs_update then
                        set_activity_label(progress, update_progress, 'updating', 'badge', key)
                        badges.update_badge(
                            api_key,
                            stored.id,
                            config.name,
                            config.description,
                            config.enabled ~= false
                        )
                    end

                    if icon_changed then
                        set_activity_label(progress, update_progress, 'updating icon for', 'badge', key)
                        badges.update_badge_icon(api_key, stored.id, config.icon)
                    end

                    badges_state[key].config = diff.clone_snapshot(config)
                    badges_state[key].icon_hash = icon_hash
                end
            else
                set_activity_label(progress, update_progress, 'creating', 'badge', key)
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

                badges_state[key] = {
                    id = response.id,
                    config = diff.clone_snapshot(config),
                    icon_hash = icon_hash,
                }
            end
        end)

        if success then
            progress.badges.current += 1
        else
            progress.badges.failed += 1
            table.insert(failures, `badge '{key}': {tostring(err)}`)
        end

        update_progress(progress)
    end
end

local function sync_passes(
    cookie: cookie,
    experience_id: number,
    pass_settings: { [string]: pass_settings_type },
    data: state_data,
    progress: progress_state,
    update_progress: progress_cb,
    failures: { string }
)
    local items = {}
    for key, config in pass_settings do
        table.insert(items, { key = key, config = config })
    end

    progress.passes.total = #items
    update_progress(progress)

    local passes_state = common.get_or_create_passes_state(data)
    local remote_passes_by_name: { [string]: number }? = nil
    local processed_pass_ids: { [number]: string } = {}

    local function ensure_remote_passes_index(): { [string]: number }
        if remote_passes_by_name then
            return remote_passes_by_name
        end

        local new_index = {}
        for _, remote_pass in passes.get_all_game_passes(cookie, experience_id) do
            if not new_index[remote_pass.name] then
                new_index[remote_pass.name] = remote_pass.gamePassId
            end
        end

        remote_passes_by_name = new_index
        return new_index
    end

    for _, item in items do
        local key = item.key
        local config = item.config

        local success, err: any = pcall(function()
            local stored = passes_state[key]
            if stored then
                if config.price == nil then
                    config.price = stored.config.price
                end

                if config.forSale == nil then
                    config.forSale = stored.config.forSale
                end
            end

            common.validate_pass_config(key, config)

            local icon_hash = state.hash_file(config.icon)

            if stored then
                common.normalize_stored_pass_config(key, stored.config)

                if not stored.id then
                    local resolved_id = ensure_remote_passes_index()[config.name]
                    assert(resolved_id, `could not resolve game pass id for '{config.name}'`)
                    stored.id = resolved_id
                    passes_state[key].id = resolved_id
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
                    set_activity_label(progress, update_progress, 'updating', 'pass', key)
                    passes.update_game_pass(
                        cookie,
                        experience_id,
                        stored.id,
                        config.name,
                        config.description,
                        config.price,
                        if icon_changed and config.icon then config.icon else nil,
                        config.forSale
                    )

                    passes_state[key].config = diff.clone_snapshot(config)
                    passes_state[key].icon_hash = icon_hash
                end
            else
                set_activity_label(progress, update_progress, 'creating', 'pass', key)
                local response = passes.create_game_pass(
                    cookie,
                    experience_id,
                    config.name,
                    config.description,
                    config.icon
                )

                passes_state[key] = {
                    id = response.gamePassId,
                    config = diff.clone_snapshot(config),
                    icon_hash = icon_hash,
                }

                set_activity_label(progress, update_progress, 'updating', 'pass', key)
                passes.update_game_pass(
                    cookie,
                    experience_id,
                    response.gamePassId,
                    config.name,
                    config.description,
                    config.price,
                    config.icon,
                    config.forSale
                )
            end
        end)

        if success then
            progress.passes.current += 1
        else
            progress.passes.failed += 1
            table.insert(failures, `pass '{key}': {tostring(err)}`)
        end

        update_progress(progress)
    end
end

local function sync_products(
    cookie: cookie,
    experience_id: number,
    product_settings: { [string]: product_settings_type },
    data: state_data,
    progress: progress_state,
    update_progress: progress_cb,
    failures: { string }
)
    local items = {}
    for key, config in product_settings do
        table.insert(items, { key = key, config = config })
    end

    progress.products.total = #items
    update_progress(progress)

    local products_state = common.get_or_create_products_state(data)

    for _, item in items do
        local key = item.key
        local config = item.config

        local success, err = pcall(function()
            common.validate_product_config(key, config)

            local stored = products_state[key]
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
                        set_activity_label(progress, update_progress, 'updating', 'product', key)
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
                        set_activity_label(progress, update_progress, 'updating icon for', 'product', key)
                        products.create_developer_product_icon(cookie, stored.id, config.icon)
                    end

                    products_state[key].config = diff.clone_snapshot(config)
                    products_state[key].icon_hash = icon_hash
                end
            else
                assert(config.price ~= nil, `invalid manifest field 'experience.products.{key}.price': expected number`)
                set_activity_label(progress, update_progress, 'creating', 'product', key)
                local response = products.create_developer_product(
                    cookie,
                    experience_id,
                    config.name,
                    config.price,
                    config.description
                )

                products_state[key] = {
                    id = response.productId,
                    config = diff.clone_snapshot(config),
                    icon_hash = icon_hash,
                }

                if config.icon then
                    set_activity_label(progress, update_progress, 'updating icon for', 'product', key)
                    products.create_developer_product_icon(cookie, response.productId, config.icon)
                end
            end
        end)

        if success then
            progress.products.current += 1
        else
            progress.products.failed += 1
            table.insert(failures, `product '{key}': {tostring(err)}`)
        end

        update_progress(progress)
    end
end

local function run(api_key: api_key, cookie: cookie, version: string)
    local manifest: manifest_config_type = state.read_manifest()
    local data = state.load_state() or state.create_initial_state(manifest.experience.id)
    assert(data.experience_id == manifest.experience.id, 'experience id mismatch in state file')

    local progress = ui.make_progress('uploading...')
    local update_progress = ui.start_progress(version)
    local failures = {}

    if manifest.experience.badges then
        sync_badges(api_key, manifest.experience.id, manifest.experience.badges, data, progress, update_progress, failures)
    end
    if manifest.experience.passes then
        sync_passes(cookie, manifest.experience.id, manifest.experience.passes, data, progress, update_progress, failures)
    end
    if manifest.experience.products then
        sync_products(cookie, manifest.experience.id, manifest.experience.products, data, progress, update_progress, failures)
    end

    state.save_state(data)
    state.clean_state_file()
    print_failure_report('upload', failures)
end

return run
