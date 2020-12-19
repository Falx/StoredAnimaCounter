local addonName, addonTable = ...;
local StoredAnimaCounter = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceBucket-3.0", "AceEvent-3.0")

local _G = _G
local BreakUpLargeNumbers = BreakUpLargeNumbers
local AceDB = LibStub("AceDB-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")

local ldbObject = LDB:NewDataObject("Stored Anima", {
    type = "data source",
    text = "-",
    value = 0,
    label = "Stored Anima"
})

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

local tooltip = nil
local bucketListener = nil
local worldListener = nil
local currListener = nil
local configIsVerbose = false
local configFormat = Format.stored
local configBreakLargeNumbers = true

local defaults = {
    profile = {
        format = Format.stored,
        verbose = false,
        breakLargeNumbers = true
    }
}

-- Lifecycle functions

function StoredAnimaCounter:OnInitialize()
    print("Addon " .. addonName .. " Loaded!")
    StoredAnimaCounter:SetupDB()
    StoredAnimaCounter:SetupConfig()
end

function StoredAnimaCounter:OnEnable()
    if worldListener == nil then
        worldListener = self:RegisterEvent("PLAYER_ENTERING_WORLD", "ScanForStoredAnima")
    end

    if currListener == nil then
        currListener = self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "ScanForStoredAnima") -- When spending anima on the anima conductor\
    end

    if bucketListener == nil then
        bucketListener = self:RegisterBucketEvent("BAG_UPDATE", 0.2, "ScanForStoredAnima")
    end

    StoredAnimaCounter:RefreshConfig()
end

function StoredAnimaCounter:OnDisable()
    if worldListener then
        self:UnregisterEvent(worldListener)
        worldListener = nil
    end

    if currListener then
        self:UnregisterEvent(currListener)
        currListener = nil
    end

    if bucketListener then
        self:UnregisterBucket(bucketListener)
        bucketListener = nil
    end
end

function StoredAnimaCounter:SetupDB()
    self.db = AceDB:New("StoredAnimaCounterDB", defaults)
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
end

-- Config functions
function StoredAnimaCounter:SetupConfig()
    local options = {
        name = addonName,
        handler = StoredAnimaCounter,
        type = "group",
        childGroups = "tree",
        args = {
            config = {
                name = "Configuration",
                desc = "Opens the SAC Configuration panel",
                type = "execute",
                func = "OpenConfigPanel",
                guiHidden = true
            },
            general = {
                name = "General",
                type = "group",
                handler = StoredAnimaCounter,
                args = {
                    headerFormat = {
                        name = "Formatting",
                        type = "header",
                        order = 1
                    },
                    format = {
                        name = "Choose output format",
                        type = "select",
                        values = FormatLabels,
                        set = "SetFormat",
                        get = "GetFormat",
                        width = "full",
                        order = 2
                    },
                    formatDesc = {
                        name = "\nChoose a format to adapt how the value of Stored Anima is displayed. There are several options: \n    stored = 100\n    stored_plus_pool = 100 (4900)\n    pool_plus_stored = 4900 (100)\n    sum_only = 5000\n    sum_plus_stored = 5000 (100)\n    stored_plus_sum = 100 (5000)\n    pool_plus_sum = 4900 (5000)",
                        type = "description",
                        order = 3
                    },
                    largeNumbers = {
                        name = "Break down large numbers",
                        desc = "Type large number using separators",
                        type = "toggle",
                        set = "SetBreakLargeNumbers",
                        get = "GetBreakLargeNumbers",
                        order = 4
                    },
                    headerVerbose = {
                        name = "Extra toggles",
                        type = "header",
                        order = 5
                    },
                    verbose = {
                        name = "Enable chat output",
                        desc = "Toggle verbose output in chat",
                        type = "toggle",
                        set = "SetVerbose",
                        get = "GetVerbose",
                        order = 6
                    }
                }
            }
        }
    }
    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)

    AceConfig:RegisterOptionsTable(addonName, options, {"storedanimacounter", "sac"})
    AceConfigDialog:AddToBlizOptions(addonName)
end

function StoredAnimaCounter:RefreshConfig()
    configIsVerbose = self.db.profile.verbose
    configFormat = self.db.profile.format
    configBreakLargeNumbers = self.db.profile.breakLargeNumbers
    StoredAnimaCounter:ScanForStoredAnima()
end

function StoredAnimaCounter:OpenConfigPanel(info)
    InterfaceOptionsFrame_OpenToCategory(addonName)
    InterfaceOptionsFrame_OpenToCategory(addonName)
end

function StoredAnimaCounter:SetVerbose(info, toggle)
    configIsVerbose = toggle
    self.db.profile.verbose = toggle
end

function StoredAnimaCounter:GetVerbose(info)
    return configIsVerbose
end

function StoredAnimaCounter:SetFormat(info, toggle)
    configFormat = toggle
    self.db.profile.format = toggle
    StoredAnimaCounter:outputValue(ldbObject.value)
end

function StoredAnimaCounter:GetFormat(info)
    return configFormat
end

function StoredAnimaCounter:SetBreakLargeNumbers(info, toggle)
    configBreakLargeNumbers = toggle
    self.db.profile.breakLargeNumbers = toggle
    StoredAnimaCounter:outputValue(ldbObject.value)
end

function StoredAnimaCounter:GetBreakLargeNumbers(info)
    return configBreakLargeNumbers
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

function StoredAnimaCounter:outputValue(storedAnima)
    local stored, pool, sum 
    if configBreakLargeNumbers then 
        stored = BreakUpLargeNumbers(storedAnima)
        pool = BreakUpLargeNumbers(GetReservoirAnima())
        sum = BreakUpLargeNumbers(GetReservoirAnima() + storedAnima)
    else 
        stored = storedAnima
        pool = GetReservoirAnima()
        sum = GetReservoirAnima() + storedAnima
    end

    vprint(">> Total stored anima: " .. stored)
    if configFormat == Format.stored then
        ldbObject.value = stored
        ldbObject.text = string.format("%s", stored)
    elseif configFormat == Format.stored_plus_pool then
        ldbObject.value = stored
        ldbObject.text = string.format("%s (%s)", stored, pool)
    elseif configFormat == Format.pool_plus_stored then
        ldbObject.value = stored
        ldbObject.text = string.format("%s (%s)", pool, stored)
    elseif configFormat == Format.sum_only then
        ldbObject.value = stored
        ldbObject.text = string.format("%s", sum)
    elseif configFormat == Format.sum_plus_stored then
        ldbObject.value = stored
        ldbObject.text = string.format("%s (%s)", sum, stored)
    elseif configFormat == Format.stored_plus_sum then
        ldbObject.value = stored
        ldbObject.text = string.format("%s (%s)", stored, sum)
    elseif configFormat == Format.pool_plus_sum then
        ldbObject.value = stored
        ldbObject.text = string.format("%s (%s)", pool, sum)
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
        local itemLink = select(2, GetItemInfo(itemId))
        tooltip = tooltip or StoredAnimaCounter:ttCreate()
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
        tooltip:ClearLines()
        tooltip:SetBagItem(bag, slot)

        if C_Item.IsAnimaItemByID(itemId) then
            local animaCount = 0;
            for j = 2, #tooltip.tipText do
                local t = tooltip.tipText[j]:GetText()
                -- Anima isn't matching the tooltip text properly, so have to search on substring
                if t and t:find("^Use") then
                    local num = t:match("%d+")
                    animaCount = tonumber(num or "")
                    break
                end
            end

            if (animaCount > 0) then
                totalAnima = (itemCount or 1) * animaCount
                vprint("Anima present: " .. totalAnima .. " on " .. itemLink)
            end
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

function GetReservoirAnima()
    local currencyID = C_CovenantSanctumUI.GetAnimaInfo()
    return C_CurrencyInfo.GetCurrencyInfo(currencyID).quantity
end

local NORMAL_FONT_COLOR = {1.0, 0.82, 0.0}

function ldbObject:OnTooltipShow()
    local stored, pool, sum 
    if configBreakLargeNumbers then 
        stored = BreakUpLargeNumbers(ldbObject.value)
        pool = BreakUpLargeNumbers(GetReservoirAnima())
        sum = BreakUpLargeNumbers(GetReservoirAnima() + ldbObject.value)
    else 
        stored = ldbObject.value
        pool = GetReservoirAnima()
        sum = GetReservoirAnima() + ldbObject.value
    end

    self:AddLine("|cFF2C94FEStored Anima|r")
    self:AddLine("An overview of anima stored in your bags, but not yet added to your covenant's reservoir.", 1.0, 0.82,
        0.0, 1)
    self:AddLine("\n")
    self:AddDoubleLine("Stored:", "|cFFFFFFFF" .. stored .. "|r")
    self:AddDoubleLine("Reservoir:", "|cFFFFFFFF" .. pool .. "|r")
    self:AddDoubleLine("Total:", "|cFFFFFFFF" .. sum .. "|r")
end

function ldbObject:OnClick(button)
    if "RightButton" == button then
        StoredAnimaCounter:OpenConfigPanel()
    elseif "LeftButton" == button then
        _G.ToggleCharacter('TokenFrame')
    end
end


