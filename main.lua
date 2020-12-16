local StoredAnimaCounter = LibStub("AceAddon-3.0"):NewAddon("StoredAnimaCounter", "AceBucket-3.0")
local AceDB = LibStub("AceDB-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local ldbObject = ldb:NewDataObject("Stored Anima", {
    type = "data source",
    text = "-",
    value = 0,
    label = "Stored Anima"
})
local bucketListener = nil

local STORED_ONLY = 1

local Format = {
    stored = 1,
    stored_plus_pool = 2,
    pool_plus_stored = 3,
    sum_only = 4,
    sum_plus_stored = 5,
    stored_plus_sum = 6,
    pool_plus_sum = 7

}

local FormatLabels = {"stored_only", "stored_plus_pool", "pool_plus_stored", "sum_only", "sum_plus_stored",
                      "stored_plus_sum", "pool_plus_sum"}

local configIsVerbose = false
local configFormat = Format.stored
local addonName = "Stored Anima Counter"

local defaults = {
    profile = {
        format = Format.stored,
        verbose = false
    }
}

-- Lifecycle functions

function StoredAnimaCounter:OnInitialize()
    print("Addon StoredAnimaCounter Loaded!")
    StoredAnimaCounter:SetupEventListeners()
    StoredAnimaCounter:SetupDB()
    StoredAnimaCounter:SetupConfig()
    StoredAnimaCounter:RefreshConfig()
end

function StoredAnimaCounter:OnEnable()
    if bucketListener ~= nil then
        StoredAnimaCounter:SetupEventListeners()
    end
    StoredAnimaCounter:RefreshConfig()
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

-- DB functions

function StoredAnimaCounter:SetupDB()
    self.db = AceDB:New("StoredAnimaCounterDB", defaults)
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
end

function StoredAnimaCounter:RefreshConfig()
    print('called')
    configIsVerbose = self.db.profile.verbose
    configFormat = self.db.profile.format
    StoredAnimaCounter:ScanForStoredAnima()
end

-- Config functions
function StoredAnimaCounter:SetupConfig()
    local options = {
        name = addonName,
        handler = StoredAnimaCounter,
        type = "group",
        args = {
            config = {
                name = "Configuration",
                desc = "Opens the SAC Configuration panel",
                type = "execute",
                func = "OpenConfigPanel"
            },
            verbose = {
                name = "Toggle chat output",
                desc = "Toggles verbose output in chat",
                type = "toggle",
                set = "SetVerbose",
                get = "GetVerbose"
            },
            format = {
                name = "Choose output format",
                type = "select",
                values = FormatLabels,
                set = "SetFormat",
                get = "GetFormat"
            }
        }
    }
    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    AceConfig:RegisterOptionsTable(addonName, options, {"storedanimacounter", "sac"})
    configPath = AceConfigDialog:AddToBlizOptions(addonName)
end

function StoredAnimaCounter:OpenConfigPanel(info)
    InterfaceOptionsFrame_OpenToCategory(addonName)
    InterfaceOptionsFrame_OpenToCategory(addonName)
end

function StoredAnimaCounter:SetVerbose(info, toggle)
    configIsVerbose = toggle
    self.db.profile.verbose = configIsVerbose
end

function StoredAnimaCounter:GetVerbose(info)
    return configIsVerbose
end

function StoredAnimaCounter:SetFormat(info, toggle)
    configFormat = toggle
    self.db.profile.format = configFormat
    StoredAnimaCounter:ScanForStoredAnima(ldbObject.value)
end

function StoredAnimaCounter:GetFormat(info)
    return configFormat
end

-- Anima functions

function StoredAnimaCounter:ScanForStoredAnima()
    vprint("Scanning:")
    local total = 0
    for bag = 0, 4 do
        local slots = GetContainerNumSlots(bag)
        for slot = 1, slots do
            total = total + (StoredAnimaCounter:doForItemInBag(bag, slot))
        end
    end
    StoredAnimaCounter:outputValue(total)
end

function StoredAnimaCounter:outputValue(stored)
    vprint(">> Total stored anima: " .. stored)
    local currencyID = C_CovenantSanctumUI.GetAnimaInfo()
    local pool = C_CurrencyInfo.GetCurrencyInfo(currencyID).quantity
    local sum = pool + stored
    if configFormat == Format.stored then
        ldbObject.value = stored
        ldbObject.text = string.format("%d", stored)
    elseif configFormat == Format.stored_plus_pool then
        ldbObject.value = stored
        ldbObject.text = string.format("%d (%d)", stored, pool)
    elseif configFormat == Format.pool_plus_stored then
        ldbObject.value = stored
        ldbObject.text = string.format("%d (%d)", pool, stored)
    elseif configFormat == Format.sum_only then
        ldbObject.value = stored
        ldbObject.text = string.format("%d", sum)
    elseif configFormat == Format.sum_plus_stored then
        ldbObject.value = stored
        ldbObject.text = string.format("%d (%d)", sum, stored)
    elseif configFormat == Format.stored_plus_sum then
        ldbObject.value = stored
        ldbObject.text = string.format("%d (%d)", stored, sum)
    elseif configFormat == Format.pool_plus_sum then
        ldbObject.value = stored
        ldbObject.text = string.format("%d (%d)", pool, sum)
    end
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
        for j = 1, #tooltip.tipText do
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
            vprint("Anima present: " .. totalAnima .. " on " .. itemLink)
        end
        tooltip:Hide()
    end
    return totalAnima
end

function vprint(val)
    if configIsVerbose then
        print(val)
    end
end

function ldbObject:OnTooltipShow()
    self:AddLine("Stored Anima")
end
