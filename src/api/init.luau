-- modules
local net = require('@lune/net')

-- this
export type api_key = string
export type json = string

-- this
local API_ENDPOINT = 'https://apis.roblox.com/'

local function request(
    api_key: api_key,
    path: string,
    method: net.HttpMethod,
    content_type: string,
    data: string | buffer
): json
    local response = net.request {
        url = API_ENDPOINT .. path,
        method = method,
        body = data,
        headers = {
            ['Content-Type'] = content_type,
            ['x-api-key'] = api_key,
        }
    }

    assert(
        response.ok and (response.statusCode == 200 or response.statusCode == 204),
        `HTTP [{response.statusCode}]: {response.statusMessage}`
    )
    return response.body
end

-- end
return table.freeze { request = request }