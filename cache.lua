local private, public = {}, {}
Aux.cache = public

local MIN_ITEM_ID, MAX_ITEM_ID = 1, 30000

aux_items = {}
aux_item_ids = {}
aux_auctionable_items = {}
aux_merchant_buy = {}
aux_merchant_sell = {}

function public.on_load()
	private.scan_wdb()
	Aux.control.event_listener('MERCHANT_SHOW', private.scan_merchant).start()
end

function private.read_item_info(data_string)

end

function public.merchant_info(item_id)
	local unit_price, limited
	if aux_merchant_buy[item_id] then
		local buy_fields = Aux.util.split(aux_merchant_buy[item_id], '#')
		unit_price, limited = tonumber(buy_fields[1]), not not tonumber(buy_fields[2])
	end

	return aux_merchant_sell[item_id], unit_price, limited
end

-- TODO hook GetAuctionSellItemInfo()

function public.item_info(item_id)
	local data_string = aux_items[item_id]
	if data_string then
		local fields = Aux.util.split(data_string, '#')
		return {
			name = fields[2],
			itemstring = 'item:'..item_id..':0:0:0',
			quality = tonumber(fields[3]),
			level = tonumber(fields[4]),
			class = fields[5],
			subclass = fields[6],
			slot = fields[7],
			max_stack = fields[8],
			texture = fields[9],
		}
	end
end

function public.item_id(item_name)
	return aux_item_ids[strlower(item_name)]
end

function private.scan_merchant()
	Aux.util.loop_inventory(function(bag, slot)
		local item_info = Aux.info.container_item(bag, slot)
		if item_info then
			aux_merchant_sell[item_info.item_id] = item_info.tooltip.money / item_info.aux_quantity
		end
	end)

	-- TODO maybe more detail? zone or  local merchant_name = UnitName('npc')
	local merchant_item_count = GetMerchantNumItems()
	for i=1,merchant_item_count do
		local link = GetMerchantItemLink(i)
		if link then
			local item_id = Aux.info.parse_hyperlink(link)
			local _, _, price, count, stock = GetMerchantItemInfo(i)
			local new_unit_price, new_limited = price / count, Aux.persistence.blizzard_boolean(stock >= 0)
			if aux_merchant_buy[item_id] then
				local fields = Aux.util.split(aux_merchant_buy[item_id], '#')
				local old_unit_price, old_limited = tonumber(fields[1]), tonumber(fields[2])

				local unit_price
				if old_limited and not new_limited then
					unit_price = new_unit_price
				elseif new_limited and not old_limited then
					unit_price = old_unit_price
				else
					unit_price = min(old_unit_price, new_unit_price)
				end

				aux_merchant_buy[item_id] = Aux.util.join({
					unit_price,
					tostring(old_limited or new_limited),
				}, '#')
			else
				aux_merchant_buy[item_id] = Aux.util.join({
					new_unit_price,
					tostring(new_limited),
				}, '#')
			end
		end
	end
end

function private.scan_wdb()

	local function helper(item_id)
		local processed = 0
		while processed <= 100 and item_id <= MAX_ITEM_ID do
			local itemstring = 'item:'..item_id
			local name, _, quality, level, class, subclass, max_stack, slot, texture = GetItemInfo(itemstring)
			name = name and strlower(name)
			if name and not aux_item_ids[name] then
				aux_item_ids[name] = item_id
				aux_items[item_id] = Aux.util.join({
					name,
					quality or '',
					level or '',
					class or '',
					subclass or '',
					slot or '',
					max_stack or '',
					texture or ''
				}, '#')
				local tooltip = Aux.info.tooltip(function(tt) tt:SetHyperlink(itemstring) end)
				if Aux.info.auctionable(tooltip, quality) then
					tinsert(aux_auctionable_items, name)
				end
				processed = processed + 1
			end
			item_id = item_id + 1
		end

		if item_id <= MAX_ITEM_ID then
			local t0 = GetTime()
			Aux.control.as_soon_as(function() return GetTime() - t0 > 0.1 end, function()
				return helper(item_id)
			end)
		else
			sort(aux_auctionable_items, function(a, b) return strlen(a) < strlen(b) or (strlen(a) == strlen(b) and a < b) end)
		end
	end

	helper(MIN_ITEM_ID)
end

function public.populate_wdb()

	local function helper(item_id)
		if item_id > MAX_ITEM_ID then
			Aux.log('Cache populated.')
			return
		end

		if not GetItemInfo('item:'..item_id) then
			Aux.log('Fetching item '..item_id..'.')
			AuxTooltip:SetHyperlink('item:'..item_id)
		end

		Aux.control.on_next_update(function()
			return helper(item_id + 1)
		end)
	end

	helper(MIN_ITEM_ID)
end