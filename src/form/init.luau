local function add_form_field(
    parts: { string },
    boundary: string,
    name: string,
    value: string
)
    table.insert(parts, '--' .. boundary .. '\r\n')
    table.insert(parts, `content-disposition: form-data; name='{name}'\r\n\r\n`)
    table.insert(parts, value .. '\r\n')
end

local function add_form_file(
    parts: {string},
    boundary: string,
    name: string,
    filename: string,
    content_type: string,
    content: string
)
    table.insert(parts, '--' .. boundary .. '\r\n')
    table.insert(parts, `content-disposition: form-data; name='{name}'; filename='{filename}'\r\n`)
    table.insert(parts, `content-type: {content_type}\r\n\r\n`)
    table.insert(parts, content .. '\r\n')
end

local function build_multipart_body(
    parts: { string },
    boundary: string
): string
    table.insert(parts, '--' .. boundary .. '--\r\n')
    return table.concat(parts)
end

return table.freeze {
    add_form_field = add_form_field,
    add_form_file = add_form_file,
    build_multipart_body = build_multipart_body,
}