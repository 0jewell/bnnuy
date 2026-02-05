-- modules
local net = require('@lune/net')

-- this
-- net.FetchParams
export type request_config = {
    url: string,
    method: string,
    body: string?,
    headers: { [string]: string }?,
}

export type api_key = string

-- this
local API_ENDPOINT = 'https://apis.roblox.com/'

local function request(
    api_key: api_key,
    path: string,
    method: net.HttpMethod,
    content_type: string,
    data: string | buffer
): string
    local response = net.request {
        url = API_ENDPOINT .. path,
        method = method,
        body = data,
        headers = {
            ['Content-Type'] = content_type,
            ['x-api-key'] = api_key,
        },
    }

    return response.body
end

return table.freeze { request = request }
