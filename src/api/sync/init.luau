-- modules
local api = require('@lib/api')
type api_key = api.api_key

local badges = require('@lib/rbx/badges')
local passes = require('@lib/rbx/gamepasses')
local products = require('@lib/rbx/products')

local state = require('@self/state')
type state_data = state.state

local diff = require('@self/diff')
local types = require('@self/types')

local function sync_badges(
    api_key: string,
    experience_id: number,
    badge_settings: { [string]: types.badge_settings },
    data: state_data
)
    print('syncing badges...')

    for key, config in badge_settings do
        assert(config.icon, 'invalid config: no badge icon')

        if not data.badges then data.badges = {} end
        local stored = data.badges[key]
        local icon_hash = state.hash_file(config.icon)

        if stored then
            local changes = diff.from(stored.config, config)
            local icon_changed = stored.icon_hash ~= icon_hash

            if changes or icon_changed then
                print(`  updating badge: {config.name}`)

                local needs_update = changes and (changes.name or changes.description or changes.enabled)
                if needs_update then
                    badges.update_badge(api_key, stored.id, config.name, config.description, config.enabled ~= false)
                end

                if icon_changed then
                    print(`    icon changed, uploading...`)
                    badges.update_badge_icon(api_key, stored.id, config.icon)
                end

                data.badges[key].config = diff.clone_snapshot(config)
                data.badges[key].icon_hash = icon_hash
            end
        else
            print(`  creating badge: {config.name}`)
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
    end
end

local function sync_passes(
    api_key: string,
    experience_id: number,
    pass_configs: { [string]: types.gamepass_settings },
    data: state_data
)
    print('syncing passes...')

    for key, config in pass_configs do
        if not data.passes then data.passes = {} end
        local stored = data.passes[key]
        local icon_hash = state.hash_file(config.icon)

        if stored then
            local changes = diff.from(stored.config, config)
            local icon_changed = stored.icon_hash ~= icon_hash

            if changes or icon_changed then
                print(`  updating pass: {config.name}`)
                passes.update_game_pass(
                    api_key,
                    stored.id,
                    config.name,
                    config.description,
                    config.price,
                    if icon_changed then config.icon else nil
                )

                if icon_changed then
                    print(`    icon changed, uploading...`)
                end

                data.passes[key].config = diff.clone_snapshot(config)
                data.passes[key].icon_hash = icon_hash
            end
        else
            print(`  creating pass: {config.name}`)
            local response =
                passes.create_game_pass(api_key, experience_id, config.name, config.description, config.icon)

            data.passes[key] = {
                id = response.gamePassId,
                config = diff.clone_snapshot(config),
                icon_hash = icon_hash,
            }

            if config.price then
                passes.update_game_pass(
                    api_key,
                    response.gamePassId,
                    config.name,
                    config.description,
                    config.price,
                    nil
                )
            end
        end
    end
end

local function sync_products(
    api_key: string,
    experience_id: number,
    product_settings: { [string]: types.product_settings },
    data: state_data
)
    print('syncing products...')

    for key, config in product_settings do
        if not data.products then data.products = {} end
        local stored = data.products[key]
        local icon_hash = state.hash_file(config.icon)

        if stored then
            local changes = diff.from(stored.config, config)
            local icon_changed = stored.icon_hash ~= icon_hash

            if changes or icon_changed then
                print(`  updating product: {config.name}`)

                local needs_update = changes and (changes.name or changes.description or changes.price)
                if needs_update then
                    products.update_developer_product(
                        api_key,
                        experience_id,
                        stored.id,
                        config.name,
                        config.price,
                        config.description
                    )
                end

                if icon_changed then
                    print(`    icon changed, uploading...`)
                    products.create_developer_product_icon(api_key, stored.id, config.icon)
                end

                data.products[key].config = diff.clone_snapshot(config)
                data.products[key].icon_hash = icon_hash
            end
        else
            print(`  creating product: {config.name}`)
            local response =
                products.create_developer_product(api_key, experience_id, config.name, config.price, config.description)

            data.products[key] = {
                id = response.id,
                config = diff.clone_snapshot(config),
                icon_hash = icon_hash,
            }

            if config.icon then
                products.create_developer_product_icon(api_key, response.id, config.icon)
            end
        end
    end
end

local function sync(api_key: string)
    local config = state.read_manifest()

    local data = state.load_state() or state.create_initial_state(config.experience.id)
    assert(data.experience_id == config.experience.id, 'experience id mismatch in state file')

    if config.experience.badges then
        sync_badges(api_key, config.experience.id, config.experience.badges, data)
    end

    if config.experience.passes then
        sync_passes(api_key, config.experience.id, config.experience.passes, data)
    end

    if config.experience.products then
        sync_products(api_key, config.experience.id, config.experience.products, data)
    end

    state.save_state(data)
    print('sync complete!')
end

return table.freeze {
    sync = sync,
}