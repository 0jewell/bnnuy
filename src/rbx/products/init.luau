-- modules
local serde = require('@lune/serde')
local fs = require('@lune/fs')

local user = require('@lib/api/user')
type cookie = user.cookie

local form = require('@lib/api/form')

-- this
export type asset_id = number

export type create_developer_product_response = {
    productId: number,
    name: string,
    description: string,
    iconImageAssetId: number?,
    universeId: number,
    isForSale: boolean,
    priceInformation: {
        defaultPriceInRobux: number?,
        enabledFeatures: { string }?,
    }?,
}

export type get_developer_product_response = {
    productId: number,
    name: string,
    description: string,
    iconImageAssetId: number?,
    universeId: number,
    isForSale: boolean,
    priceInformation: {
        defaultPriceInRobux: number?,
        enabledFeatures: { string }?,
    }?,
}

export type list_developer_product_response_item = {
    productId: number,
    name: string,
    description: string,
    iconImageAssetId: number?,
    universeId: number,
    isForSale: boolean,
    priceInformation: {
        defaultPriceInRobux: number?,
        enabledFeatures: { string }?,
    }?,
}

export type list_developer_products_response = {
    developerProducts: { list_developer_product_response_item },
    nextPageToken: string?,
}

local function create_developer_product(
    cookie: cookie,
    experience_id: asset_id,
    name: string,
    price: number,
    description: string,
    icon_file_path: string?
): create_developer_product_response
    local body = form()
        .text('name', name)
        .text('description', description)
        .text('isForSale', 'true')
        .text('price', tostring(price))

    if icon_file_path then
        local file_content = fs.readFile(icon_file_path)
        body.part { name = 'imageFile', file_name = 'icon.png', content_type = 'image/png', content = file_content }
    end

    local response_body = user.request(
        cookie,
        `developer-products/v2/universes/{experience_id}/developer-products`,
        'POST',
        `multipart/form-data; boundary={body.boundary}`,
        body.multipart()
    )

    return serde.decode('json', response_body)
end

local function list_developer_products(
    cookie: cookie,
    experience_id: asset_id,
    page_token: string?
): list_developer_products_response
    local v2_path = `developer-products/v2/universes/{experience_id}/developer-products/creator`
    if page_token then
        v2_path = v2_path .. `?pageToken={page_token}`
    end

    local response_body = user.request(cookie, v2_path, 'GET', 'application/json', '')
    return serde.decode('json', response_body)
end

local function get_all_developer_products(
    cookie: cookie,
    experience_id: asset_id
): { list_developer_product_response_item }
    local all_products = {}
    local page_token: string? = nil

    while true do
        local response = list_developer_products(cookie, experience_id, page_token)
        local items = response.developerProducts

        for _, product in items do
            table.insert(all_products, product)
        end

        if not response.nextPageToken then
            break
        end

        page_token = response.nextPageToken
    end

    return all_products
end

local function get_developer_product(
    cookie: cookie,
    experience_id: asset_id,
    developer_product_id: asset_id
): get_developer_product_response
    local response_body = user.request(
        cookie,
        `developer-products/v2/universes/{experience_id}/developer-products/{developer_product_id}/creator`,
        'GET',
        'application/json',
        ''
    )

    return serde.decode('json', response_body)
end

local function update_developer_product(
    cookie: cookie,
    experience_id: asset_id,
    product_id: asset_id,
    name: string,
    price: number,
    description: string,
    icon_file_path: string?
): ()
    local body = form()
        .text('name', name)
        .text('description', description)
        .text('isForSale', 'true')
        .text('price', tostring(price))

    if icon_file_path then
        local file_content = fs.readFile(icon_file_path)
        body.part { name = 'imageFile', file_name = 'icon.png', content_type = 'image/png', content = file_content }
    end

    user.request(
        cookie,
        `developer-products/v2/universes/{experience_id}/developer-products/{product_id}`,
        'PATCH',
        `multipart/form-data; boundary={body.boundary}`,
        body.multipart()
    )
end

return table.freeze {
    create_developer_product = create_developer_product,
    list_developer_products = list_developer_products,
    get_all_developer_products = get_all_developer_products,
    get_developer_product = get_developer_product,
    update_developer_product = update_developer_product
}
