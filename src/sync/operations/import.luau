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

local function import_badges(
    api_key: api_key,
    experience_id: number,
    manifest: manifest_config_type,
    data: state_data,
    progress: progress_state,
    update_progress: progress_cb,
    failures: { string }
): number
    local badges_settings = manifest.experience.badges
        or error(`attempt to import badges without ensuring manifest`)

    local badges_state = common.get_or_create_badges_state(data)

    local imported = 0
    local remote_badges = badges.get_all_badges(api_key, experience_id)

    progress.badges.total = #remote_badges
    update_progress(progress)

    for _, badge in remote_badges do
        local success, err: any = pcall(function()
            if common.contains_id(badges_state, badge.id) then
                return
            end

            local key = common.unique_key(badge.name, badges_settings, badges_state)
            set_activity_label(progress, update_progress, 'importing', 'badge', key)
            local icon = common.ensure_icon_file('badge', badge.id, badge.name, badge.iconImageId)

            local config: badge_settings_type = {
                name = badge.name,
                description = badge.description,
                icon = icon,
                enabled = badge.enabled,
            }
            common.validate_badge_config(key, config)
            badges_settings[key] = config

            badges_state[key] = {
                id = badge.id,
                config = diff.clone_snapshot(config),
                icon_hash = state.hash_file(icon),
            }

            imported += 1
        end)

        if success then
            progress.badges.current += 1
        else
            progress.badges.failed += 1
            table.insert(failures, `badge import failed: {tostring(err)}`)
        end

        update_progress(progress)
    end

    return imported
end

local function import_passes(
    cookie: cookie,
    experience_id: number,
    manifest: manifest_config_type,
    data: state_data,
    progress: progress_state,
    update_progress: progress_cb,
    failures: { string }
): number
    local pass_settings = manifest.experience.passes
        or error(`attempt to import passes without ensuring manifest`)
    local passes_state = common.get_or_create_passes_state(data)

    local imported = 0
    local remote_passes = passes.get_all_game_passes(cookie, experience_id)

    progress.passes.total = #remote_passes
    update_progress(progress)

    for _, pass in remote_passes do
        local success, err: any = pcall(function()
            local pass_id = pass.gamePassId
            local pass_price: number? = nil
            local pass_for_sale = pass.isForSale

            if pass.priceInformation then
                pass_price = pass.priceInformation.defaultPriceInRobux
            end
            if pass_for_sale == true and pass_price == nil then
                pass_for_sale = false
            end

            local existing_key: string? = nil
            for key, stored in passes_state do
                if stored.id == pass_id then
                    existing_key = key
                    break
                end
            end

            if existing_key then
                passes_state[existing_key].id = pass_id

                local existing_config = pass_settings[existing_key]
                if existing_config then
                    existing_config.name = pass.name
                    existing_config.description = pass.description
                    existing_config.forSale = pass_for_sale
                    if pass_price ~= nil then
                        existing_config.price = pass_price
                    end
                    common.validate_pass_config(existing_key, existing_config)
                end
                return
            end

            if common.contains_id(passes_state, pass_id) then
                return
            end

            local key = common.unique_key(pass.name, pass_settings, passes_state)
            set_activity_label(progress, update_progress, 'importing', 'pass', key)
            local icon = common.ensure_icon_file('pass', pass_id, pass.name, pass.iconAssetId)
            local config: pass_settings_type = {
                name = pass.name,
                description = pass.description,
                icon = icon,
                forSale = pass_for_sale,
                price = pass_price,
            }

            common.validate_pass_config(key, config)
            pass_settings[key] = config
            passes_state[key] = {
                id = pass_id,
                config = diff.clone_snapshot(config),
                icon_hash = state.hash_file(icon),
            }
            imported += 1
        end)

        if success then
            progress.passes.current += 1
        else
            progress.passes.failed += 1
            table.insert(failures, `pass import failed: {tostring(err)}`)
        end

        update_progress(progress)
    end

    return imported
end

local function import_products(
    cookie: cookie,
    experience_id: number,
    manifest: manifest_config_type,
    data: state_data,
    progress: progress_state,
    update_progress: progress_cb,
    failures: { string }
): number
    local product_settings = manifest.experience.products
        or error(`attempt to import products without ensuring manifest`)

    local products_state = common.get_or_create_products_state(data)

    local imported = 0
    local remote_products = products.get_all_developer_products(cookie, experience_id)

    progress.products.total = #remote_products
    update_progress(progress)

    for _, product in remote_products do
        local success, err: any = pcall(function()
            if common.contains_id(products_state, product.productId) then
                return
            end

            local key = common.unique_key(product.name, product_settings, products_state)
            set_activity_label(progress, update_progress, 'importing', 'product', key)
            local icon = common.ensure_icon_file('product', product.productId, product.name, product.iconImageAssetId)
            local config: product_settings_type = {
                name = product.name,
                description = product.description,
                icon = icon,
                price = product.priceInRobux,
            }

            common.validate_product_config(key, config)
            product_settings[key] = config
            products_state[key] = {
                id = product.productId,
                config = diff.clone_snapshot(config),
                icon_hash = state.hash_file(icon),
            }
            imported += 1
        end)

        if success then
            progress.products.current += 1
        else
            progress.products.failed += 1
            table.insert(failures, `product import failed: {tostring(err)}`)
        end

        update_progress(progress)
    end

    return imported
end

local function run(
    api_key: api_key,
    cookie: cookie,
    experience_id: number,
    output: string?,
    force: boolean?,
    version: string
)
    local output_file = output or 'bnnuy.yml'
    local manifest: manifest_config_type
    local data: state_data

    if force then
        manifest = state.make_manifest(experience_id)
        data = state.create_initial_state(experience_id)
    else
        data = state.load_state() or state.create_initial_state(experience_id)
        assert(data.experience_id == experience_id, 'experience id mismatch in state file. use --force to overwrite')

        manifest = state.load_manifest(output_file) or state.make_manifest(experience_id)
        assert(manifest.experience.id == experience_id, 'experience id mismatch in manifest file. use --force to overwrite')

        common.ensure_manifest_has_state(manifest, data)
    end

    local progress = ui.make_progress('importing...')
    local update_progress = ui.start_progress(version)
    local failures = {}

    local badges_ok, badges_err = pcall(
        import_badges,
        api_key,
        experience_id,
        manifest,
        data,
        progress,
        update_progress,
        failures
    )
    if not badges_ok then
        progress.badges.failed += 1
        table.insert(failures, `badge import failed: {tostring(badges_err)}`)
        update_progress(progress)
    end

    local passes_ok, passes_err = pcall(
        import_passes,
        cookie,
        experience_id,
        manifest,
        data,
        progress,
        update_progress,
        failures
    )
    if not passes_ok then
        progress.passes.failed += 1
        table.insert(failures, `pass import failed: {tostring(passes_err)}`)
        update_progress(progress)
    end

    local products_ok, products_err = pcall(
        import_products,
        cookie,
        experience_id,
        manifest,
        data,
        progress,
        update_progress,
        failures
    )
    if not products_ok then
        progress.products.failed += 1
        table.insert(failures, `product import failed: {tostring(products_err)}`)
        update_progress(progress)
    end

    state.save_manifest(manifest, output_file)
    state.save_state(data)
    state.clean_yaml_files(output_file)
    print_failure_report('import', failures)
end

return run
