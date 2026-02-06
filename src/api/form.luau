-- types
export type part_settings = {
    name: string,
    file_name: string,
    content_type: string,
    content: string,
}

export type parts = { string }
export type boundary = string

-- this
local function boundary()
    return `----boundary{tostring(os.time())}`
end

local function insert_boundary(parts: parts, boundary: boundary)
    table.insert(parts, '--' .. boundary .. '\r\n')
end

local function insert_value(parts: parts, value: string)
    table.insert(parts, value .. '\r\n')
end

local function form()
    local parts = {}
    local boundary = boundary()
    local self = { boundary = boundary }

    function self.text(name: string, value: string)
        insert_boundary(parts, boundary)
        table.insert(parts, `Content-Disposition: form-data; name="{name}"\r\n\r\n`)
        insert_value(parts, value)

        return self
    end

    function self.part(settings: part_settings)
        insert_boundary(parts, boundary)
        table.insert(parts, `Content-Disposition: form-data; name="{settings.name}"; filename="{settings.file_name}"\r\n`)
        table.insert(parts, `Content-Type: {settings.content_type}\r\n\r\n`)
        insert_value(parts, settings.content)

        return self
    end

    function self.multipart(): string
        table.insert(parts, '--' .. boundary .. '--\r\n')
        return table.concat(parts)
    end

    return self
end

-- end
return form