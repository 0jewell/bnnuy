-- modules
local serde = require('@lune/serde')
local fs = require('@lune/fs')

local user = require('@lib/api/user')
type cookie = user.cookie

local form = require('@lib/api/form')

-- this
export type asset_id = number

export type list_game_pass_response = {
    gamePassId: number,
    name: string,
    description: string,
    iconAssetId: number?,
    isForSale: boolean?,
    priceInformation: {
        defaultPriceInRobux: number?,
        enabledFeatures: { string }?,
    }?,
    createdTimestamp: string?,
    updatedTimestamp: string?,
}

export type list_game_passes_response = {
    gamePasses: { list_game_pass_response }
}

export type get_game_pass_response = {
    targetId: number,
    productType: string?,
    assetId: number,
    productId: number,
    name: string,
    description: string,
    assetTypeId: number,
    creator: {
        id: number,
        name: string,
        creatorType: string,
        creatorTargetId: number,
    },
    iconImageAssetId: number,
    created: string,
    updated: string,
    priceInRobux: number?,
    priceInTickets: number?,
    sales: number,
    isNew: boolean,
    isForSale: boolean,
    isPublicDomain: boolean,
    isLimited: boolean,
    isLimitedUnique: boolean,
    remaining: number?,
    minimumMembershipLevel: number,
    contentRatingTypeId: number,
}

export type create_game_pass_response = {
    gamePassId: number,
    name: string,
    description: string,
    iconImageAssetId: number,
}

local function list_game_passes(
    cookie: cookie,
    experience_id: asset_id
): list_game_passes_response
    local path = `game-passes/v1/universes/{experience_id}/game-passes/creator?limit=100`
    local response_body = user.request(cookie, path, 'GET', 'application/json', '')

    return serde.decode('json', response_body)
end

local function get_game_pass(
    cookie: cookie,
    experience_id: asset_id,
    game_pass_id: asset_id
): get_game_pass_response
    local response_body = user.request(
        cookie,
        `game-passes/v1/universes/{experience_id}/game-passes/{game_pass_id}/creator`,
        'GET',
        'application/json',
        ''
    )

    local model: get_game_pass_response = serde.decode('json', response_body)

    if model.targetId == 0 then
        model.targetId = game_pass_id
    end

    return model
end

local function get_all_game_passes(
    cookie: cookie,
    experience_id: asset_id
): { list_game_pass_response }
    local all_game_passes = {}

    local response = list_game_passes(cookie, experience_id)
    local items = response.gamePasses

    for _, game_pass in items do
        assert(game_pass.gamePassId, "invalid game pass payload: missing 'gamePassId'")
        table.insert(all_game_passes, game_pass)
    end

    return all_game_passes
end

local function create_game_pass(
    cookie: cookie,
    experience_id: asset_id,
    name: string,
    description: string,
    icon_file_path: string
): create_game_pass_response
    local file_content = fs.readFile(icon_file_path)

    local body = form()
        .text('Name', name)
        .text('Description', description)
        .text('UniverseId', tostring(experience_id))
        .part {
            name = 'File',
            file_name = 'icon.png',
            content_type = 'image/png',
            content = file_content
        }

    local response_body = user.request(
        cookie,
        `game-passes/v1/universes/{experience_id}/game-passes`,
        'POST',
        `multipart/form-data; boundary={body.boundary}`,
        body.multipart()
    )

    return serde.decode('json', response_body)
end

local function update_game_pass(
    cookie: cookie,
    experience_id: asset_id,
    game_pass_id: asset_id,
    name: string,
    description: string,
    price: number?,
    icon_file_path: string?,
    for_sale: boolean?
): get_game_pass_response
    local is_for_sale = if for_sale ~= nil then for_sale else (price ~= nil)

    local body = form()
        .text('name', name)
        .text('description', description)
        .text('isForSale', if is_for_sale then 'true' else 'false')

    if is_for_sale and price then
        body.text('price', tostring(price))
    end

    if icon_file_path then
        local file_content = fs.readFile(icon_file_path)
        body.part { name = 'file', file_name = 'icon.png', content_type = 'image/png', content = file_content }
    end

    user.request(
        cookie,
        `game-passes/v1/universes/{experience_id}/game-passes/{game_pass_id}`,
        'PATCH',
        `multipart/form-data; boundary={body.boundary}`,
        body.multipart()
    )

    return get_game_pass(cookie, experience_id, game_pass_id)
end

return table.freeze {
    list_game_passes = list_game_passes,
    get_game_pass = get_game_pass,
    get_all_game_passes = get_all_game_passes,
    create_game_pass = create_game_pass,
    update_game_pass = update_game_pass
}