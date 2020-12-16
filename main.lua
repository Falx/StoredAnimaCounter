local StoredAnimaCounter = LibStub("AceAddon-3.0"):NewAddon("StoredAnimaCounter", "AceBucket-3.0")
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local ldbObject = ldb:NewDataObject("Stored Anima", {
    type = "data source",
    text = "-",
    value = 0,
    label = "Stored Anima"
})
local bucketListener = nil

function StoredAnimaCounter:OnInitialize()
    print("Addon StoredAnimaCounter Loaded!")
    StoredAnimaCounter:SetupEventListeners()
end

function StoredAnimaCounter:OnEnable()
    if bucketListener ~= nil then
        StoredAnimaCounter:SetupEventListeners()
    end
end

function StoredAnimaCounter:OnDisable()
    if bucketListener then
        StoredAnimaCounter:UnregisterBucket(bucketListener)
        bucketListener = nil
    end
end

function StoredAnimaCounter:SetupEventListeners()
    bucketListener = StoredAnimaCounter:RegisterBucketEvent("BAG_UPDATE", 0.2, "ScanForStoredAnima")
end

function StoredAnimaCounter:ScanForStoredAnima()
    print("Scanning:")
    local total = 0
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            total = total + (StoredAnimaCounter:doForItemInBag(bag, slot))
        end
    end
    print(">> Total stored anima: " .. total)
    ldbObject.value = total
    ldbObject.text = string.format("%d", total)
end

function StoredAnimaCounter:ttCreate()
    local tip, tipText = CreateFrame("GameTooltip"), {}
    for i = 1, 6 do
        local tipLeft, tipRight = tip:CreateFontString(), tip:CreateFontString()
        tipLeft:SetFontObject(GameFontNormal)
        tipRight:SetFontObject(GameFontNormal)
        tip:AddFontStrings(tipLeft, tipRight)
        tipText[i] = tipLeft
    end
    tip.tipText = tipText
    return tip
end

function StoredAnimaCounter:doForItemInBag(bag, slot)
    local itemId = GetContainerItemID(bag, slot)
    local _, itemCount = GetContainerItemInfo(bag, slot)
    local totalAnima = 0
    if itemId ~= nil then
        local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
            itemEquipLoc, itemTexture, sellPrice, itemClassID, itemSubClassID, bindType, expacID, setID,
            isCraftingReagent = GetItemInfo(itemId)
        local tooltip = tooltip or StoredAnimaCounter:ttCreate()
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
        tooltip:ClearLines()
        tooltip:SetBagItem(bag, slot)


        local isAnima = false
        for j=1,#tooltip.tipText do
            local t = tooltip.tipText[j]:GetText()
            -- Anima isn't matching the tooltip text properly, so have to search on substring
            if t and itemClassID == LE_ITEM_CLASS_MISCELLANEOUS and itemSubClassID == LE_ITEM_MISCELLANEOUS_OTHER and
                t:find(ANIMA .. "|r$") then
                isAnima = true
            elseif t and isAnima and t:find("^Use") then
                local num = t:match("%d+")
                isAnima = tonumber(num or "")
            end
        end

        if isAnima then
            totalAnima = (itemCount or 1) * isAnima
            print("Anima present: " .. totalAnima .. " on " .. itemLink)
        end
        tooltip:Hide()        
    end
    return totalAnima
end


function ldbObject:OnTooltipShow()
    self:AddLine("Stored Anima")
end
