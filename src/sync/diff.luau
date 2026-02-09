-- from: https://gist.github.com/ernisto/9222aeb5f065b06c191ac5a619c639e7
-- modules
local REMOVE = table.freeze {}
local NO_CHANGE = nil

-- patch {...} with {} = nil
-- patch  nil  with {} = {}
local function is_remove(old, diff)
	return old ~= nil and type(diff) == 'table' and next(diff) == nil
end

local function clone_snapshot<T>(target: T)
	if type(target) ~= 'table' then return target end
	local out = table.clone(target)
	for k, v in target do
		out[k] = clone_snapshot(v)
	end
	return table.freeze(out :: any) :: any
end

local function diff_from<T>(old: T, new: T): T
	if new == old then return NO_CHANGE :: any end
	if new == nil then return REMOVE :: any end
	if type(old) ~= 'table' or type(new) ~= 'table' then return new end

	local diff = {}
	local removes = table.clone(old)

	for key, new_nalue in new do
		diff[key] = diff_from(old[key], new_nalue)
		removes[key] = nil
	end
	for key in removes do
		diff[key] = REMOVE
	end

	return if next(diff) == nil then NO_CHANGE :: any else diff
end

local function apply_diff<T>(old: T, diff: T): T?
	if diff == nil then return old end
	if old == nil then return diff end
	if is_remove(old, diff :: any) then return nil end
	if type(diff) ~= 'table' or type(old) ~= 'table' then return diff end

	for key, new in diff do
		local new_value = apply_diff(old[key], new)
		if new_value ~= old[key] then old[key] = new_value end	-- readonly caution
	end
	return old
end

local function clone_apply_diff<T>(old: T, diff: T): T?
	if diff == nil then return old end
	if old == nil then return diff end
	if type(diff) ~= 'table' or type(old) ~= 'table' then return diff end

	local out = table.clone(old)
	for key, new in diff do
		out[key] = clone_apply_diff(old[key], new)
	end
	return out :: any
end

-- end
return table.freeze {
	apply = apply_diff,
	clone_apply = clone_apply_diff,
	clone_snapshot = clone_snapshot,
	from = diff_from
}