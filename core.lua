
local _, ADDONSELF = ...

local qrcode = ADDONSELF.qrcode

local BLOCK_SIZE = 2
local PLAYER = "player";
local CONCATENATION_CHARACTER = "$";

local function CreateQRTip(qrsize)
    local mainFrame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")

    local function CreateBlock(idx)
        local blockFrame = CreateFrame("Frame", nil, mainFrame, BackdropTemplateMixin and "BackdropTemplate")
        blockFrame:SetWidth(BLOCK_SIZE)
        blockFrame:SetHeight(BLOCK_SIZE)
        blockFrame.texture = blockFrame:CreateTexture(nil, "OVERLAY")
        blockFrame.texture:SetAllPoints(blockFrame)
        local x = (idx % qrsize) * BLOCK_SIZE
        local y = (math.floor(idx / qrsize)) * BLOCK_SIZE
        blockFrame:SetPoint("TOPLEFT", mainFrame, x, -y);
        return blockFrame
    end

    do
        mainFrame:SetFrameStrata("BACKGROUND")
        mainFrame:SetWidth(qrsize * BLOCK_SIZE)
        mainFrame:SetHeight(qrsize * BLOCK_SIZE)
        mainFrame:SetMovable(true)
        mainFrame:EnableMouse(true)
        mainFrame:SetPoint("CENTER", 0, 0)
        mainFrame:RegisterForDrag("LeftButton") 
        mainFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        mainFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    end

    mainFrame.boxes = {}

    mainFrame.SetBlack = function(idx)
        mainFrame.boxes[idx].texture:SetColorTexture(0, 0, 0)
    end

    mainFrame.SetWhite = function(idx)
        mainFrame.boxes[idx].texture:SetColorTexture(1, 1, 1)
    end

    for i = 1, qrsize * qrsize do
        tinsert(mainFrame.boxes, CreateBlock(i - 1))
    end

    return mainFrame
end

local function ConcatenateStatusValue(status, value)
    return status .. CONCATENATION_CHARACTER .. value
end

local function GetCharacterStatus() 
    -- TODO: Figure out encoding of character name (ideally we want only uppercase letters for smaller QR codes)
    -- Name
    local characterStatus = UnitName(PLAYER)
    -- CLASS
    characterStatus = ConcatenateStatusValue(characterStatus, UnitClass(PLAYER))
    -- RACE
    characterStatus = ConcatenateStatusValue(characterStatus, UnitRace(PLAYER))
    -- LEVEL
    characterStatus = ConcatenateStatusValue(characterStatus, UnitLevel(PLAYER))
    -- TALENTS
    local wowheadTalentString = "";
    local tabBuffer = "";
    local numTabs = GetNumTalentTabs();
    for tabIndex = 1, numTabs do
        local tabActive = false;
        local numTalents = GetNumTalents(tabIndex);
        local talentTree = {};
        local maxTier = 0;
        local maxColumn = 0;
        for talent = 1, numTalents do
            local nameTalent, icon, tier, column, currRank, maxRank = GetTalentInfo(tabIndex, talent);
            if talentTree[tier] == nil then
                talentTree[tier] = {};
            end
            talentTree[tier][column] = currRank;
            if tier > maxTier then
                maxTier = tier;
            end
            if column > maxColumn then
                maxColumn = column;
            end
        end
        local tierBuffer = "";
        for tier = 1, maxTier do
            for column = 1, maxColumn do
                if talentTree[tier][column] ~= nil then
                    tierBuffer = tierBuffer..talentTree[tier][column];
                    if talentTree[tier][column] ~= 0 then
                        tabBuffer = tabBuffer..tierBuffer;
                        tierBuffer = "";
                        tabActive = true;
                    end
                end
            end
        end
        if tabIndex < numTabs then
            tabBuffer = tabBuffer.."-";
        end
        if tabActive then
            wowheadTalentString = wowheadTalentString..tabBuffer;
            tabBuffer = "";
        end
    end
    characterStatus = ConcatenateStatusValue(characterStatus, wowheadTalentString)
    -- TODO: EQUIPMENT
    characterStatus = ConcatenateStatusValue(characterStatus, "NYI")
    -- CURRENT HP
    characterStatus = ConcatenateStatusValue(characterStatus, UnitHealth(PLAYER))
    -- MAX HP
    characterStatus = ConcatenateStatusValue(characterStatus, UnitHealthMax(PLAYER))
    -- CURRENT MANA/ENERGY/RAGE
    characterStatus = ConcatenateStatusValue(characterStatus, UnitPower(PLAYER))
    -- MAX MANA/ENERGY/RAGE
    characterStatus = ConcatenateStatusValue(characterStatus, UnitPowerMax(PLAYER))
    -- GOLD
    characterStatus = ConcatenateStatusValue(characterStatus, GetMoney())
    
    return characterStatus
end


SlashCmdList["QRCODE"] = function(cmdParam, editbox)
    local characterStatus = GetCharacterStatus()
    DEFAULT_CHAT_FRAME:AddMessage(characterStatus);
    local ok, tab_or_message = qrcode(characterStatus, 4)
    if not ok then
        print(tab_or_message)
    else
        local tab = tab_or_message
        local size = #tab

        local f = CreateQRTip(size)
        f:Show()

        for x = 1, #tab do
            for y = 1, #tab do

                if tab[x][y] > 0 then
                    f.SetBlack((y - 1) * size + x - 1 + 1)
                else
                    f.SetWhite((y - 1) * size + x - 1 + 1)
                end
            end
        end
    end

end
SLASH_QRCODE1 = "/QRCODE"
