local fs = require('@lune/fs')
local serde = require('@lune/serde')

local INDENT = '  '

local function is_array(value: { [any]: any }): (boolean, number)
    local count = 0

    for key in value do
        if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then
            return false, 0
        end

        count += 1
    end

    if count == 0 then
        return false, 0
    end

    for index = 1, count do
        if value[index] == nil then
            return false, 0
        end
    end

    return true, count
end

local function sorted_keys(value: { [any]: any }): { string }
    local keys = {}

    for key in value do
        table.insert(keys, tostring(key))
    end

    table.sort(keys)
    return keys
end

local function quote_yaml(text: string): string
    return "'" .. string.gsub(text, "'", "''") .. "'"
end

local function is_plain_scalar(text: string): boolean
    if text == '' then
        return false
    end

    if string.match(text, '^[-]') then
        return false
    end

    local forbidden_chars = { ':', '#', '[', ']', '{', '}', ',', '&', '*', '!', '|', '>', '%', '@', '`', '"' }
    for _, char in forbidden_chars do
        if string.find(text, char, 1, true) then
            return false
        end
    end

    return string.match(text, '^[%w%._/%-]+$') ~= nil
end

local function scalar_to_yaml(value: any): string
    local value_type = type(value)

    if value_type == 'string' then
        if is_plain_scalar(value) then
            return value
        end

        return quote_yaml(value)
    end

    if value_type == 'number' then
        return tostring(value)
    end

    if value_type == 'boolean' then
        return if value then 'true' else 'false'
    end

    if value == nil then
        return 'null'
    end

    return quote_yaml(tostring(value))
end

local function push_line(lines: { string }, level: number, text: string)
    table.insert(lines, string.rep(INDENT, level) .. text)
end

local function write_value(lines: { string }, value: any, level: number)
    local value_type = type(value)

    if value_type ~= 'table' then
        push_line(lines, level, scalar_to_yaml(value))
        return
    end

    if next(value) == nil then
        push_line(lines, level, '{}')
        return
    end

    local as_array, array_size = is_array(value)

    if as_array then
        for index = 1, array_size do
            local item = value[index]

            if type(item) == 'table' and next(item) ~= nil then
                push_line(lines, level, '-')
                write_value(lines, item, level + 1)
            else
                local serialized = if type(item) == 'table' then '{}' else scalar_to_yaml(item)
                push_line(lines, level, '- ' .. serialized)
            end
        end

        return
    end

    local previous_was_table = false
    local first = true

    for _, key in sorted_keys(value) do
        local item = value[key]
        local serialized_key = if is_plain_scalar(key) then key else quote_yaml(key)
        local current_is_table = type(item) == 'table' and next(item) ~= nil

        if not first and previous_was_table and current_is_table then
            table.insert(lines, '')
        end

        if current_is_table then
            push_line(lines, level, serialized_key .. ':')
            write_value(lines, item, level + 1)
        else
            local serialized = if type(item) == 'table' then '{}' else scalar_to_yaml(item)
            push_line(lines, level, serialized_key .. ': ' .. serialized)
        end

        previous_was_table = current_is_table
        first = false
    end
end

local function parse_yaml(content: string): any
    return serde.decode('yaml', content)
end

local function stringify_yaml(value: any): string
    local lines = {}

    if type(value) == 'table' and next(value) ~= nil then
        write_value(lines, value, 0)
        return table.concat(lines, '\n') .. '\n'
    end

    write_value(lines, value, 0)
    return table.concat(lines, '\n') .. '\n'
end

local function read_file(path: string): any
    return parse_yaml(fs.readFile(path))
end

local function write_file(path: string, value: any)
    fs.writeFile(path, stringify_yaml(value))
end

local function clean_file(path: string)
    if not fs.isFile(path) then
        return
    end

    local parsed = read_file(path)
    write_file(path, parsed)
end

local function clean_files(paths: { string })
    local seen = {}

    for _, path in paths do
        if not seen[path] then
            seen[path] = true
            clean_file(path)
        end
    end
end

return table.freeze {
    parse = parse_yaml,
    stringify = stringify_yaml,
    read_file = read_file,
    write_file = write_file,
    clean_file = clean_file,
    clean_files = clean_files
}