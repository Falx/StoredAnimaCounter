local addonName, addonTable = ...;
local StoredAnimaCounter = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceBucket-3.0", "AceEvent-3.0")

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
local configIsVerbose = false
local configFormat = Format.stored

local defaults = {
    profile = {
        format = Format.stored,
        verbose = false
    }
}

-- Lifecycle functions

function StoredAnimaCounter:OnInitialize()
    print("Addon " .. addonName .. " Loaded!")
    StoredAnimaCounter:SetupDB()
    StoredAnimaCounter:SetupConfig()
end

function StoredAnimaCounter:OnEnable()
    -- StoredAnimaCounter:RegisterEvent("PLAYER_LOGIN", "ScanForStoredAnima")
    self.ScanForStoredAnima()
    if bucketListener == nil then
        bucketListener = StoredAnimaCounter:RegisterBucketEvent("BAG_UPDATE", 0.2, "ScanForStoredAnima")
    end
    StoredAnimaCounter:RefreshConfig()
end

function StoredAnimaCounter:OnDisable()
    if bucketListener then
        StoredAnimaCounter:UnregisterBucket(bucketListener)
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
                    headerVerbose = {
                        name = "Extra toggles",
                        type = "header",
                        order = 4
                    },
                    verbose = {
                        name = "Enable chat output",
                        desc = "Toggle verbose output in chat",
                        type = "toggle",
                        set = "SetVerbose",
                        get = "GetVerbose",
                        order = 5
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
    StoredAnimaCounter:ScanForStoredAnima()
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
    StoredAnimaCounter:outputValue(ldbObject.value)
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
    local pool = GetReservoirAnima()
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
    local animaCount = 0;
    if itemId ~= nil then
        local itemLink = select(2, GetItemInfo(itemId))
        local itemClassID, itemSubClassID = select(12, GetItemInfo(itemId))
        tooltip = tooltip or StoredAnimaCounter:ttCreate()
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
                animaCount = tonumber(num or "")
            end
        end

        if isAnima and (animaCount > 0) then
            totalAnima = (itemCount or 1) * animaCount
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

function GetReservoirAnima()
    local currencyID = C_CovenantSanctumUI.GetAnimaInfo()
    return C_CurrencyInfo.GetCurrencyInfo(currencyID).quantity
end

local NORMAL_FONT_COLOR = {1.0, 0.82, 0.0}

function ldbObject:OnTooltipShow()
    self:AddLine("|cFF2C94FEStored Anima|r")
    self:AddLine("An overview of anima stored in your bags, but not yet added to your covenant's reservoir.", 1.0, 0.82,
        0.0, 1)
    self:AddLine("\n")
    self:AddDoubleLine("Stored:", "|cFFFFFFFF" .. ldbObject.value .. "|r")
    self:AddDoubleLine("Reservoir:", "|cFFFFFFFF" .. GetReservoirAnima() .. "|r")
    self:AddDoubleLine("Total:", "|cFFFFFFFF" .. ldbObject.value + GetReservoirAnima() .. "|r")
end
