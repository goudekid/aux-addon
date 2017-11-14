module 'aux.core.history'

include 'T'
include 'aux'

local persistence = require 'aux.util.persistence'

local history_schema = {'tuple', '#', {next_push='number'}, {daily_min_buyout='number'}, {data_points={'list', ';', {'tuple', '@', {value='number'}, {time='number'}}}}}

local value_cache = {}

function LOAD2()
	data = faction_data'history'
end

do
	local cache = 0
	function get_next_push()
		if time() > cache then
			local date = date('*t')
			date.hour, date.min, date.sec = 24, 0, 0
			cache = time(date)
		end
		return cache
	end
end

function get_new_record()
	return temp-O('next_push', next_push, 'data_points', T)
end

function read_record(item_key)
	local record = data[item_key] and persistence.read(history_schema, data[item_key]) or new_record
	if record.next_push <= time() then
		push_record(record)
		write_record(item_key, record)
	end
	return record
end

function write_record(item_key, record)
	data[item_key] = persistence.write(history_schema, record)
	if value_cache[item_key] then
		release(value_cache[item_key])
		value_cache[item_key] = nil
	end
end

function M.process_auction(auction_record)
	local item_record = read_record(auction_record.item_key)
	local unit_buyout_price = ceil(auction_record.buyout_price / auction_record.aux_quantity)
	if unit_buyout_price > 0 and unit_buyout_price < (item_record.daily_min_buyout or huge) then
		item_record.daily_min_buyout = unit_buyout_price
		write_record(auction_record.item_key, item_record)
	end
end

function M.data_points(item_key)
	return read_record(item_key).data_points
end

function M.value(item_key)
	if not value_cache[item_key] or value_cache[item_key].next_push <= time() then
		local item_record, value
		item_record = read_record(item_key)
		if getn(item_record.data_points) > 0 then
			local total_weight, weighted_values = 0, temp-T
			for _, data_point in item_record.data_points do
				local weight = .99 ^ round((item_record.data_points[1].time - data_point.time) / (60 * 60 * 24))
				total_weight = total_weight + weight
				tinsert(weighted_values, O('value', data_point.value, 'weight', weight))
			end
			for _, weighted_value in weighted_values do
				weighted_value.weight = weighted_value.weight / total_weight
			end
			value = weighted_median(weighted_values)
		else
			value = item_record.daily_min_buyout
		end
		value_cache[item_key] = O('value', value, 'next_push', item_record.next_push)
	end
	return value_cache[item_key].value
end

function M.market_value(item_key)
	return read_record(item_key).daily_min_buyout
end

function weighted_median(list)
	sort(list, function(a,b) return a.value < b.value end)
	local weight = 0
	for i = 1, getn(list) do
		weight = weight + list[i].weight
		if weight >= .5 then
			return list[i].value
		end
	end
end

function push_record(item_record)
	if item_record.daily_min_buyout then
		tinsert(item_record.data_points, 1, O('value', item_record.daily_min_buyout, 'time', item_record.next_push))
		while getn(item_record.data_points) > 11 do
			release(item_record.data_points[getn(item_record.data_points)])
			tremove(item_record.data_points)
		end
	end
	item_record.next_push, item_record.daily_min_buyout = next_push, nil
end