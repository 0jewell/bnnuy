-- modules
local serde = require('@lune/serde')
local fs = require('@lune/fs')

local user = require('@lib/api/user')
type cookie = user.cookie

local form = require('@lib/api/form')

-- this
export type asset_id = number

export type create_developer_product_icon_response = {
    imageAssetId: number,
}

export type create_developer_product_response = {
    productId: number,
    name: string,
    description: string,
    shopId: number,
    iconImageAssetId: number,
}

export type get_developer_product_response = {
    id: number,
    name: string,
    description: string,
    shopId: number,
    iconImageAssetId: number,
    displayName: string,
    displayDescription: string,
    priceInRobux: number,
}

export type list_developer_product_response_item = {
    ProductId: number,
    DeveloperProductId: number,
    Name: string,
    Description: string,
    IconImageAssetId: number,
    displayName: string,
    displayDescription: string,
    PriceInRobux: number,
}

export type list_developer_products_response = {
    DeveloperProducts: { list_developer_product_response_item },
    FinalPage: boolean,
    PageSize: number,
}

local function create_developer_product_icon(
    cookie: cookie,
    developer_product_id: asset_id,
    icon_file_path: string
): create_developer_product_icon_response
    local file_content = fs.readFile(icon_file_path)

    local body =
        form().part { name = 'imageFile', file_name = 'icon.png', content_type = 'image/png', content = file_content }

    local response_body = user.request(
        cookie,
        `developer-products/v1/developer-products/{developer_product_id}/image`,
        'POST',
        `multipart/form-data; boundary={body.boundary}`,
        body.multipart()
    )

    return serde.decode('json', response_body)
end

local function create_developer_product(
    cookie: cookie,
    experience_id: asset_id,
    name: string,
    price: number,
    description: string
): create_developer_product_response
    local path =
        `developer-products/v1/universes/{experience_id}/developerproducts?name={name}&priceInRobux={price}&description={description}`

    local response_body = user.request(cookie, path, 'POST', 'application/json', '')

    return serde.decode('json', response_body)
end

local function list_developer_products(
    cookie: cookie,
    experience_id: asset_id,
    page: number
): list_developer_products_response
    local path = `developer-products/v1/developer-products/list?universeId={experience_id}&page={page}`

    local response_body = user.request(cookie, path, 'GET', 'application/json', '')

    return serde.decode('json', response_body)
end

local function get_all_developer_products(
    cookie: cookie,
    experience_id: asset_id
): { list_developer_product_response_item }
    local all_products = {}
    local page = 1

    while true do
        local response = list_developer_products(cookie, experience_id, page)

        for _, product in response.DeveloperProducts do
            table.insert(all_products, product)
        end

        if response.FinalPage then
            break
        end

        page += 1
    end

    return all_products
end

local function get_developer_product(
    cookie: cookie,
    developer_product_id: asset_id
): get_developer_product_response
    local response_body = user.request(
        cookie,
        `developer-products/v1/developer-products/{developer_product_id}`,
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
    description: string
): ()
    user.request(
        cookie,
        `developer-products/v1/universes/{experience_id}/developerproducts/{product_id}/update`,
        'POST',
        'application/json',
        serde.encode('json', {
            Name = name,
            PriceInRobux = price,
            Description = description,
        })
    )
end

return table.freeze {
    create_developer_product_icon = create_developer_product_icon,
    create_developer_product = create_developer_product,
    list_developer_products = list_developer_products,
    get_all_developer_products = get_all_developer_products,
    get_developer_product = get_developer_product,
    update_developer_product = update_developer_product,
}