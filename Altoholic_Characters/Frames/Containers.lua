local addonName = "Altoholic"
local addon = _G[addonName]
local colors = addon.Colors

local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

local OPTION_VIEW_BAGS = "UI.Tabs.Characters.ViewBags"
local OPTION_VIEW_BANK = "UI.Tabs.Characters.ViewBank"
local OPTION_VIEW_VOID_STORAGE = "UI.Tabs.Characters.ViewVoidStorage"
local OPTION_VIEW_REAGENT_BANK = "UI.Tabs.Characters.ViewReagentBank"
local OPTION_VIEW_BAGS_RARITY = "UI.Tabs.Characters.ViewBagsRarity"
local OPTION_VIEW_BAGS_ALLINONE = "UI.Tabs.Characters.ViewBagsAllInOne"

addon:Controller("AltoholicUI.TabCharacters.Containers", { "AltoholicUI.Options", function(Options)

	-- https://wowpedia.fandom.com/wiki/BagID
	local FIRST_BAG = 0
	local LAST_BAG = 5
	local FIRST_BANK_BAG = 6
	local LAST_BANK_BAG = 12
	
	local item_OnEnter
	
	local function bag_OnEnter(self)
		local id = self:GetID()
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		if id == 0 then
			GameTooltip:AddLine(BACKPACK_TOOLTIP, 1, 1, 1)
			GameTooltip:AddLine(format(CONTAINER_SLOTS, 16, BAGSLOT), 1, 1, 1)
		elseif id == 100 then
			GameTooltip:AddLine(L["Bank"], 0.5, 0.5, 1)
			GameTooltip:AddLine(format("%d %s", 28, L["slots"]), 1, 1, 1)
		elseif id >= 201 and id <= 202 then
			GameTooltip:AddLine(VOID_STORAGE, 0.5, 0.5, 1)
		elseif id == 300 then
			GameTooltip:AddLine(REAGENT_BANK, 0.5, 0.5, 1)
		else
			local character = AltoholicFrame.TabCharacters:GetCharacter()
			local _, link = DataStore:GetContainerInfo(character, id)
			GameTooltip:SetHyperlink(link)
			if (id >= FIRST_BANK_BAG) and (id <= LAST_BANK_BAG) then
				GameTooltip:AddLine(L["Bank bag"], 0, 1, 0)
			end
		end
		GameTooltip:Show() 
	end

	local bagIndices

	local function UpdateBagIndices(bag, size)
		-- the BagIndices table will be used by self:Containers_Update to determine which part of a bag should be displayed on a given line
		-- ex: [1] = bagID = 0, from 1, to 12
		-- ex: [2] = bagID = 0, from 13, to 16

		local lowerLimit = 1

		while size > 0 do					-- as long as there are slots to process ..
			table.insert(bagIndices, { bagID = bag, from = lowerLimit} )
		
			if size <= 12 then			-- no more lines ? leave
				return
			else
				size = size - 12			-- .. or adjust counters
				lowerLimit = lowerLimit + 12
			end
		end
	end

	local function OnBagUpdate(bag)
		-- 2021/07/09 to be uncommented later
		-- addon:RefreshTooltip()

		-- if DataStore:IsMailBoxOpen() and AltoholicFrameMail:IsVisible() then	
			-- if a bag is updated while the mailbox is opened, this means an attachment has been taken.
			-- addon.Mail:BuildView()
			-- addon.Mail:Update()
		-- end
	end
	
	local containerList			-- Used by the All-in-one view
	
	return {
		OnBind = function(frame)
			local parent = AltoholicFrame.TabCharacters
			
			frame:SetParent(parent)
			frame:SetPoint("TOPLEFT", parent.Background, "TOPLEFT", 0, 0)
			frame:SetPoint("BOTTOMRIGHT", parent.Background, "BOTTOMRIGHT", 26, 0)
			parent:RegisterPanel("Containers", frame)
			
			-- 25/05/2021 : this line should probably be moved, and the method as well
			addon:RegisterEvent("BAG_UPDATE", OnBagUpdate)
			
			-- save a reference to the 'OnEnter' script used on the items, because it might be overriden
			item_OnEnter = frame.Entry1.Item1:GetScript("OnEnter")
			
			-- Handle resize
			frame:SetScript("OnSizeChanged", function(self, width, height)
				if not frame:IsVisible() then return end
			
				frame:PreUpdate()
				frame:Update(true)
			end)
		end,
		
		PreUpdate = function(frame)
			-- There is no Update(), it points to UpdateSpread or UpdateAllInOne
			if Options.Get(OPTION_VIEW_BAGS_ALLINONE) then
				frame.Update = frame.UpdateAllInOne
			else
				frame.Update = frame.UpdateSpread
				frame:UpdateCache()
				frame.ScrollFrame:SetOffset(0)
			end
		end,
		
		UpdateSpread = function(frame, isResizing)
			local rarity = Options.Get(OPTION_VIEW_BAGS_RARITY)
			local scrollFrame = frame.ScrollFrame
			local numRows = scrollFrame.numRows
			
			if #bagIndices == 0 then
				for rowIndex = 1, numRows do
					local rowFrame = scrollFrame:GetRow(rowIndex) 
					rowFrame:Hide()
				end
				
				scrollFrame:Update(numRows)
				return
			end
			
			local parent = frame:GetParent()
			local character = parent:GetCharacter()
			local offset = scrollFrame:GetOffset()
			
			local maxDisplayedRows = math.floor(scrollFrame:GetHeight() / scrollFrame.rowHeight)
			
			if not isResizing then
				parent:SetStatus(format("%s|r / %s%s", DataStore:GetColoredCharacterName(character), colors.white, L["Containers"]))
			end
			
			local itemButton
			
			for rowIndex = 1, numRows do
				local rowFrame = scrollFrame:GetRow(rowIndex)
				
				local line = rowIndex + offset
				
				if line <= #bagIndices and (rowIndex <= maxDisplayedRows) then	-- if the line is visible
					if not (isResizing and rowFrame:IsVisible()) then
						local containerID = bagIndices[line].bagID
						local container = DataStore:GetContainer(character, containerID)
						local containerIcon, _, containerSize = DataStore:GetContainerInfo(character, containerID)
						
						-- Column 1 : the bag
						itemButton = rowFrame.Item1
						
						if bagIndices[line].from == 1 then		-- if this is the first line for this bag .. draw bag icon
							itemButton.Icon:SetDesaturated(false)
							
							-- 15/10/2014: note, find a better way for this than this ugly hack
							if containerID == "VoidStorage.Tab1" then
								itemButton:SetID(201)	-- use id 201 for void storage, only required a few lines below
							elseif containerID == "VoidStorage.Tab2" then
								itemButton:SetID(202)	-- use id 202 for void storage, only required a few lines below
							elseif containerID == REAGENTBANK_CONTAINER then
								itemButton:SetID(300)
							else
								itemButton:SetID(containerID)
							end
							
							itemButton.Icon:SetTexture(containerIcon)
							itemButton:SetScript("OnEnter", bag_OnEnter)						
							itemButton.Count:Hide()
							itemButton:Show()
						else
							itemButton:Hide()
						end
						
						-- Column 2 : empty
						itemButton = rowFrame.Item2
						itemButton:Hide()
						itemButton:SetInfo(nil, nil)
						
						-- Columns 3 to 14 : bag content
						for j = 3, 14 do
							itemButton = rowFrame["Item"..j]
							
							local slotID = bagIndices[line].from - 3 + j
							local itemID, itemLink, itemCount, isBattlePet = DataStore:GetSlotInfo(container, slotID)
							
							if (slotID <= containerSize) then 
								itemButton:SetItem(itemID, itemLink, rarity)
								itemButton:SetCount(itemCount)
								if isBattlePet then
									itemButton:SetIcon(itemID)	-- override the icon if one is returned by datastore
								end
								
								local startTime, duration, isEnabled = DataStore:GetContainerCooldownInfo(container, slotID)
								itemButton:SetCooldown(startTime, duration, isEnabled)
								itemButton:SetScript("OnEnter", item_OnEnter)
								itemButton:Show()
							else
								itemButton:Hide()
								itemButton:SetInfo(nil, nil)
								itemButton.startTime = nil
								itemButton.duration = nil
							end
						end
					end		-- end isResizing
					rowFrame:Show()
				else
					rowFrame:Hide()
				end
			end
			
			if #bagIndices < numRows then
				scrollFrame:Update(numRows, maxDisplayedRows)
			else
				scrollFrame:Update(#bagIndices, maxDisplayedRows)
			end	
		end,
		
		UpdateAllInOne = function(frame, isResizing)
			local rarity = Options.Get(OPTION_VIEW_BAGS_RARITY)
			local scrollFrame = frame.ScrollFrame
			local numRows = scrollFrame.numRows
			
			local parent = frame:GetParent()
			local character = parent:GetCharacter()

			-- Set the tab status
			if not isResizing then
				parent:SetStatus(format("%s|r / %s%s|r / %s%s", 
					DataStore:GetColoredCharacterName(character), 
					colors.white, L["Containers"], 
					colors.white, L["All-in-one"]))
			end

			-- Prepare the list of containers to display
			containerList = containerList or {}
			wipe(containerList)

			if Options.Get(OPTION_VIEW_BAGS) then
				for i = FIRST_BAG, LAST_BAG do
					table.insert(containerList, i)
				end
			end
			
			if Options.Get(OPTION_VIEW_BANK) then
				for i = FIRST_BANK_BAG, LAST_BANK_BAG do
					table.insert(containerList, i)
				end
				table.insert(containerList, 100)
			end
			
			if Options.Get(OPTION_VIEW_VOID_STORAGE) then
				table.insert(containerList, "VoidStorage.Tab1")
				table.insert(containerList, "VoidStorage.Tab2")
			end
			
			if Options.Get(OPTION_VIEW_REAGENT_BANK) then
				table.insert(containerList, REAGENTBANK_CONTAINER)
			end
			
			local rowIndex = 1
			local colIndex = 1
			local offset = scrollFrame:GetOffset()
			local numColumns = 14
			local minSlotIndex = offset * numColumns
			local currentSlotIndex = 0		-- this indexes the non-empty slots
			local maxDisplayedRows = math.floor(scrollFrame:GetHeight() / scrollFrame.rowHeight)

			if #containerList > 0 then
				local rowFrame = frame[format("Entry%d", rowIndex)]
				
				for _, containerID in pairs(containerList) do
					local container = DataStore:GetContainer(character, containerID)
					local containerSize = select(3, DataStore:GetContainerInfo(character, containerID))

					for slotID = 1, containerSize do
						local itemID, itemLink, itemCount, isBattlePet = DataStore:GetSlotInfo(container, slotID)

						if itemID then
							currentSlotIndex = currentSlotIndex + 1
							if currentSlotIndex > minSlotIndex and rowIndex <= numRows and rowIndex <= maxDisplayedRows then
								
								local itemButton = rowFrame[format("Item%d", colIndex)]
									
								-- if not (isResizing and itemButton:IsVisible()) then
									itemButton:SetItem(itemID, itemLink, rarity)
									itemButton:SetCount(itemCount)
									if isBattlePet then
										itemButton:SetIcon(itemID)	-- override the icon if one is returned by datastore
									end
									
									local startTime, duration, isEnabled = DataStore:GetContainerCooldownInfo(container, slotID)
									itemButton:SetCooldown(startTime, duration, isEnabled)
									itemButton:Show()
								-- end
									
								colIndex = colIndex + 1
								if colIndex > numColumns then
									colIndex = 1
									rowIndex = rowIndex + 1
									rowFrame = frame[format("Entry%d", rowIndex)]
								end
							end				
						end
					end
				end
			end
				
			while rowIndex <= numRows do
				while colIndex <= numColumns do
					local itemButton = frame[format("Entry%d", rowIndex)][format("Item%d", colIndex)]
					itemButton:Hide()
					itemButton:SetInfo(nil, nil)
					-- itemButton.id = nil
					-- itemButton.link = nil
					itemButton.startTime = nil
					itemButton.duration = nil
					
					colIndex = colIndex + 1
				end
			
				colIndex = 1
				rowIndex = rowIndex + 1
			end
			
			for i = 1, numRows do
				frame[format("Entry%d", i)]:Show()
			end

			scrollFrame:Update(ceil(currentSlotIndex / numColumns))
		end,
	
		UpdateAllInOne__BACKUP_TEST = function(frame)
			local rarity = Options.Get(OPTION_VIEW_BAGS_RARITY)
			local scrollFrame = frame.ScrollFrame
			local numRows = scrollFrame.numRows
			local numColumns = 20
			
			local parent = frame:GetParent()
			local character = parent:GetCharacter()

			parent:SetStatus(format("%s|r / %s%s|r / %s%s", 
				DataStore:GetColoredCharacterName(character), 
				colors.white, L["Containers"], 
				colors.white, L["All-in-one"]))

			local offset = scrollFrame:GetOffset()
			local maxDisplayedRows = math.floor(scrollFrame:GetHeight() / 41)
			local maxDisplayedColumns = math.floor(scrollFrame:GetWidth() / 44)
			
			local minSlotIndex = offset * maxDisplayedColumns
			local currentSlotIndex = 0		-- this indexes the non-empty slots
			local rowIndex = 1
			local colIndex = 1
			
			local containerList = {}

			if Options.Get(OPTION_VIEW_BAGS) then
				for i = FIRST_BAG, LAST_BAG do
					table.insert(containerList, i)
				end
			end
			
			if Options.Get(OPTION_VIEW_BANK) then
				for i = FIRST_BANK_BAG, LAST_BANK_BAG do
					table.insert(containerList, i)
				end
				table.insert(containerList, 100)
			end
			
			if Options.Get(OPTION_VIEW_VOID_STORAGE) then
				table.insert(containerList, "VoidStorage.Tab1")
				table.insert(containerList, "VoidStorage.Tab2")
			end
			
			if Options.Get(OPTION_VIEW_REAGENT_BANK) then
				table.insert(containerList, REAGENTBANK_CONTAINER)
			end
			
			local itemButton
			
			if #containerList > 0 then
				
				for _, containerID in pairs(containerList) do
					local container = DataStore:GetContainer(character, containerID)
					local _, _, containerSize = DataStore:GetContainerInfo(character, containerID)

					for slotID = 1, containerSize do
						local itemID, itemLink, itemCount, isBattlePet = DataStore:GetSlotInfo(container, slotID)

						if itemID then
							currentSlotIndex = currentSlotIndex + 1
							if (currentSlotIndex > minSlotIndex) and (rowIndex <= numRows) and (rowIndex <= maxDisplayedRows) then
								itemButton = frame[format("Entry%d", rowIndex)][format("Item%d", colIndex)]
								itemButton:SetItem(itemID, itemLink, rarity)
								itemButton:SetCount(itemCount)
								if isBattlePet then
									itemButton:SetIcon(itemID)	-- override the icon if one is returned by datastore
								end
								
								local startTime, duration, isEnabled = DataStore:GetContainerCooldownInfo(container, slotID)
								itemButton:SetCooldown(startTime, duration, isEnabled)
								itemButton:SetScript("OnEnter", item_OnEnter)
								itemButton:Show()
								
								colIndex = colIndex + 1
								if colIndex > maxDisplayedColumns then
									colIndex = 1
									rowIndex = rowIndex + 1
								end
							end				
						end
					end
				end
			end
			
			if rowIndex <= maxDisplayedRows then
			
				-- On the last line, if n items only, hide all the remaining ones
				while colIndex <= numColumns do
					local button = frame[format("Entry%d", rowIndex)][format("Item%d", colIndex)]
					button:Hide()
					button:SetInfo(nil, nil)
					
					colIndex = colIndex + 1
				end
			end
			
			-- Loop through all rows
			for i = 1, numRows do
				local row = frame[format("Entry%d", i)]
				local startColumn = 1
				
				-- Show or hide the row
				if i < rowIndex then
					row:Show()
					startColumn = maxDisplayedColumns + 1	-- for columns that are out of bounds on a displayed line
				else
					row:Hide()
				end
				
				for colIndex = startColumn, numColumns do
					local button = row[format("Item%d", colIndex)]
					button:Hide()
					button:SetInfo(nil, nil)
				end
			end
			
			if maxDisplayedColumns ~= 0 then
				scrollFrame:Update(ceil(currentSlotIndex / maxDisplayedColumns))
			end
		end,
		
		UpdateCache = function(frame)
			bagIndices = bagIndices or {}
			wipe(bagIndices)

			local character = frame:GetParent():GetCharacter()
			
			if Options.Get(OPTION_VIEW_BAGS) then
				for bagID = FIRST_BAG, LAST_BAG do
					if DataStore:GetContainer(character, bagID) then
						local _, _, size = DataStore:GetContainerInfo(character, bagID)
						UpdateBagIndices(bagID, size)
					end
				end	
			end
			
			if Options.Get(OPTION_VIEW_BANK) then
				for bagID = FIRST_BANK_BAG, LAST_BANK_BAG do
					if DataStore:GetContainer(character, bagID) then
						local _, _, size = DataStore:GetContainerInfo(character, bagID)
						UpdateBagIndices(bagID, size)
					end
				end
				
				if DataStore:GetContainer(character, 100) then 	-- if bank has been visited, add it
					UpdateBagIndices(100, 28)
				end
			end
			
			if Options.Get(OPTION_VIEW_VOID_STORAGE) then
				UpdateBagIndices("VoidStorage.Tab1", 80)
				UpdateBagIndices("VoidStorage.Tab2", 80)
			end
			
			if Options.Get(OPTION_VIEW_REAGENT_BANK) then
				local _, _, size = DataStore:GetContainerInfo(character, REAGENTBANK_CONTAINER)
				UpdateBagIndices(REAGENTBANK_CONTAINER, size)
			end
		end,
	}
end})