-- modules
local serde = require('@lune/serde')
local fs = require('@lune/fs')

local api = require('../api')
type api_key = api.api_key

local form = require('../form')

-- this
export type asset_id = number
export type creator_type = number

export type create_badge_response = {
	id: number,
	name: string,
	description: string,
	display_name: string,
	display_description: string,
	enabled: boolean,
	icon_image_id: number,
	display_icon_image_id: number,
	awarder: {
		id: number,
		type: number,
		name: string
	},
	statistics: {
		past_day_awarded_count: number,
		awarded_count: number,
		win_rate_percentage: number
	},
	created: string,
	updated: string
}

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
    local boundary = '----LuneBoundary' .. tostring(os.time())
    local parts = {}

    form.add_form_file(parts, boundary, 'files', 'icon.png', 'image/png', file_content)
    form.add_form_field(parts, boundary, 'name', name)
    form.add_form_field(parts, boundary, 'description', description)
    form.add_form_field(parts, boundary, 'paymentSourceType', tostring(payment_source_type))
    form.add_form_field(parts, boundary, 'expectedCost', tostring(expected_cost))

    if is_active ~= nil then
        form.add_form_field(parts, boundary, 'isActive', tostring(is_active))
    end

    local body = form.build_multipart_body(parts, boundary)

    local response_body = api.request(
        api_key,
        `legacy-badges/v1/universes/{experience_id}/badges`,
        'POST',
        `multipart/form-data; boundary={boundary}`,
        body
    )

    return serde.decode('json', response_body)
end

return table.freeze {
    create_badge = create_badge
}