module 'aux.custom.timer'



local timeSinceStart = 0

local function onUpdate(self,elapsed)
    timeSinceStart = timeSinceStart + elapsed
    if timeSinceStart >= 2 then
        DEFAULT_CHAT_FRAME:AddMessage("ping!")
        timeSinceStart = 0
    end
end

function M.set(timeAsInt) -- 1 is 30m, 2 is 2h, 3 is 8h, 4 is 24h
	if timeAsInt == 1
	onUpdate()
	elseif timeAsInt == 2
	--stuff
	elseif timeAsInt == 3
	--stuff
	elseif timeAsInt == 4
	--stuff
	end
end