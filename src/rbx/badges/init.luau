-- modules
local serde = require('@lune/serde')
local fs = require('@lune/fs')

local api = require('@lib/api')
local form = require('@lib/api/form')
type api_key = api.api_key

-- types
export type asset_id = number
export type creator_type = number

export type create_badge_response = {
    id: number,
    name: string,
    description: string,
    displayName: string,
    displayDescription: string,
    enabled: boolean,
    iconImageId: number,
    displayIconImageId: number,
    awarder: {
        id: number,
        type: number,
        name: string,
    },
    statistics: {
        pastDayAwardedCount: number,
        awardedCount: number,
        winRatePercentage: number,
    },
    created: string,
    updated: string,
}

export type list_badge_response = {
    id: number,
    name: string,
    description: string,
    displayName: string,
    displayDescription: string,
    enabled: boolean,
    iconImageId: number,
    displayIconImageId: number,
    created: string,
    updated: string,
    statistics: {
        pastDayAwardedCount: number,
        awardedCount: number,
        winRatePercentage: number,
    },
    awarding_universe: {
        id: number,
        name: string,
        rootPlaceId: number,
    },
}

export type list_badges_response = {
    previousPageCursor: string?,
    nextPageCursor: string?,
    data: { list_badge_response },
}

export type upload_image_response = {
    targetId: number,
    state: string,
    uploadAssetId: number,
}

-- this
local function create_badge(
    api_key: api_key,
    experience_id: asset_id,
    name: string,
    description: string,
    icon_file_path: string,
    payment_source_type: creator_type,
    expected_cost: number,
    is_active: boolean?
): create_badge_response
    local file_content = fs.readFile(icon_file_path)

    local body = form()
        .part { name = 'files', file_name = 'icon.png', content_type = 'image/png', content = file_content }
        .text('name', name)
        .text('description', description)
        .text('paymentSourceType', tostring(payment_source_type))
        .text('expectedCost', tostring(expected_cost))

    if is_active ~= nil then
        body.text('isActive', tostring(is_active))
    end

    local response_body = api.request(
        api_key,
        `legacy-badges/v1/universes/{experience_id}/badges`,
        'POST',
        `multipart/form-data; boundary={body.boundary}`,
        body.multipart()
    )

    return serde.decode('json', response_body)
end

local function update_badge(
    api_key: api_key,
    badge_id: asset_id,
    name: string,
    description: string,
    enabled: boolean
): ()
    api.request(
        api_key,
        `legacy-badges/v1/badges/{badge_id}`,
        'PATCH',
        'application/json',
        serde.encode('json', {
            name = name,
            description = description,
            enabled = enabled,
        })
    )
end

local function get_create_badge_free_quota(
    api_key: api_key,
    experience_id: asset_id
)
    local response_body = api.request(
        api_key,
        `legacy-badges/v1/universes/{experience_id}/free-badges-quota`,
        'GET',
        'application/json',
        ''
    )

    return serde.decode('json', response_body)
end

local function list_badges(
    api_key: api_key,
    experience_id: asset_id,
    page_cursor: string?
)
    local path = `legacy-badges/v1/universes/{experience_id}/badges`
    if page_cursor then
        path = path .. `?cursor={page_cursor}`
    end

    local response_body = api.request(api_key, path, 'GET', 'application/json', '')

    return serde.decode('json', response_body)
end

local function get_all_badges(
    api_key: api_key,
    experience_id: asset_id
)
    local all_badges = {}
    local page_cursor: string? = nil

    while true do
        local response = list_badges(api_key, experience_id, page_cursor)

        for _, badge in response.data do
            table.insert(all_badges, badge)
        end

        if not response.next_page_cursor then
            break
        end

        page_cursor = response.next_page_cursor
    end

    return all_badges
end

local function update_badge_icon(
    api_key: api_key,
    badge_id: asset_id,
    icon_file_path: string
): upload_image_response
    local file_content = fs.readFile(icon_file_path)

    local body =
        form().part { name = 'files', file_name = 'icon.png', content_type = 'image/png', content = file_content }

    local response_body = api.request(
        api_key,
        `legacy-publish/v1/badges/{badge_id}/icon`,
        'POST',
        `multipart/form-data; boundary={body.boundary}`,
        body.multipart()
    )

    return serde.decode('json', response_body)
end

-- end
return table.freeze {
    create_badge = create_badge,
    update_badge = update_badge,
    get_create_badge_free_quota = get_create_badge_free_quota,
    list_badges = list_badges,
    get_all_badges = get_all_badges,
    update_badge_icon = update_badge_icon,
}