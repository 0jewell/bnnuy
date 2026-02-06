-- modules
local roblox = require('@lune/roblox')
local net = require('@lune/net')

-- types
export type cookie = string

-- this
local function get_cookie(cookie: string?): cookie
    if cookie then
        return cookie
    end

    local local_cookie = roblox.getAuthCookie()
    assert(local_cookie, 'failed to get auth cookie')

    return local_cookie
end

local API_ENDPOINT = 'https://apis.roblox.com/'

local function request(
    cookie: cookie,
    path: string,
    method: net.HttpMethod,
    content_type: string,
    data: string | buffer
): string
    local headers = {
        ['Content-Type'] = content_type,
        ['Cookie'] = cookie
    }

    local response = net.request {
        url = API_ENDPOINT .. path,
        method = method,
        body = data,
        headers = headers,
    }

    if response.statusCode == 403 and response.headers['x-csrf-token'] then
        headers['x-csrf-token'] = response.headers['x-csrf-token']

        response = net.request {
            url = API_ENDPOINT .. path,
            method = method,
            body = data,
            headers = headers,
        }
    end

    assert(response.ok and response.statusCode == 200, `HTTP [{response.statusCode}]: {response.statusMessage}\n{response.body}`)
    return response.body
end

return table.freeze {
    request = request,
    get_cookie = get_cookie,
}
