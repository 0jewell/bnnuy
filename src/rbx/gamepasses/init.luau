-- modules
local serde = require('@lune/serde')
local fs = require('@lune/fs')

local api = require('@lib/api')
local form = require('@lib/api/form')
type api_key = api.api_key

-- this
export type asset_id = number

export type list_game_pass_response = {
    id: number,
    name: string,
    displayName: string,
    productId: number?,
    price: number?,
}

export type list_game_passes_response = {
    previousPageCursor: string?,
    nextPageCursor: string?,
    data: { list_game_pass_response },
}

export type get_game_pass_response = {
    TargetId: number,
    ProductType: string?,
    AssetId: number,
    ProductId: number,
    Name: string,
    Description: string,
    AssetTypeId: number,
    Creator: {
        Id: number,
        Name: string,
        CreatorType: string,
        CreatorTargetId: number,
    },
    IconImageAssetId: number,
    Created: string,
    Updated: string,
    PriceInRobux: number?,
    PriceInTickets: number?,
    Sales: number,
    IsNew: boolean,
    IsForSale: boolean,
    IsPublicDomain: boolean,
    IsLimited: boolean,
    IsLimitedUnique: boolean,
    Remaining: number?,
    MinimumMembershipLevel: number,
    ContentRatingTypeId: number,
}

export type create_game_pass_response = {
    gamePassId: number,
    name: string,
    description: string,
    iconImageAssetId: number,
}

local function list_game_passes(
    api_key: api_key,
    experience_id: asset_id,
    page_cursor: string?
): list_game_passes_response
    local path = `games/v1/games/{experience_id}/game-passes?limit=100`
    if page_cursor then
        path = path .. `&cursor={page_cursor}`
    end

    local response_body = api.request(api_key, path, 'GET', 'application/json', '')

    return serde.decode('json', response_body)
end

local function get_game_pass(
    api_key: api_key,
    game_pass_id: asset_id
): get_game_pass_response
    local response_body = api.request(
        api_key,
        `economy/v1/game-pass/{game_pass_id}/game-pass-product-info`,
        'GET',
        'application/json',
        ''
    )

    local model: get_game_pass_response = serde.decode('json', response_body)

    if model.TargetId == 0 then
        model.TargetId = game_pass_id
    end

    return model
end

local function get_all_game_passes(
    api_key: api_key,
    experience_id: asset_id
): { get_game_pass_response }
    local all_game_passes = {}
    local page_cursor: string? = nil

    while true do
        local response = list_game_passes(api_key, experience_id, page_cursor)

        for _, game_pass in response.data do
            local full_game_pass = get_game_pass(api_key, game_pass.id)
            table.insert(all_game_passes, full_game_pass)
        end

        if not response.nextPageCursor then
            break
        end

        page_cursor = response.nextPageCursor
    end

    return all_game_passes
end

local function create_game_pass(
    api_key: api_key,
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

    local response_body = api.request(
        api_key,
        'game-passes/v1/game-passes',
        'POST',
        `multipart/form-data; boundary={body.boundary}`,
        body.multipart()
    )

    return serde.decode('json', response_body)
end

local function update_game_pass(
    api_key: api_key,
    game_pass_id: asset_id,
    name: string,
    description: string,
    price: number?,
    icon_file_path: string?
): get_game_pass_response
    local body = form()
        .text('name', name).text('description', description).text('isForSale', if price then 'true' else 'false')

    if price then
        body.text('price', tostring(price))
    end

    if icon_file_path then
        local file_content = fs.readFile(icon_file_path)
        body.part { name = 'file', file_name = 'icon.png', content_type = 'image/png', content = file_content }
    end

    api.request(
        api_key,
        `game-passes/v1/game-passes/{game_pass_id}/details`,
        'POST',
        `multipart/form-data; boundary={body.boundary}`,
        body.multipart()
    )

    return get_game_pass(api_key, game_pass_id)
end

return table.freeze {
    list_game_passes = list_game_passes,
    get_game_pass = get_game_pass,
    get_all_game_passes = get_all_game_passes,
    create_game_pass = create_game_pass,
    update_game_pass = update_game_pass,
}