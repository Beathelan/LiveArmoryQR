
local _, ADDONSELF = ...

local qrcode = ADDONSELF.qrcode

local BLOCK_SIZE = 2
local PLAYER = "player";
local CHAR_FIELD_SEPARATOR = "$";
local CHAR_VALUE_SEPARATOR = "-";
local CHAR_PADDING = "%";
local REPAINT_CD_SEC = 0.250;


local MIN_MESSAGE_SIZE = 155;
local EQUIPMENT_SLOTS = { "HEADSLOT", "NECKSLOT", "SHOULDERSLOT", "BACKSLOT", "CHESTSLOT", "SHIRTSLOT", "TABARDSLOT", "WRISTSLOT", "HANDSSLOT", "WAISTSLOT", "LEGSSLOT", "FEETSLOT", "FINGER0SLOT", "FINGER1SLOT", "TRINKET0SLOT", "TRINKET1SLOT", "MAINHANDSLOT", "SECONDARYHANDSLOT", "RANGEDSLOT"};
local BASE_32_DIGITS = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V"};
local CHARACTER_RACES = { NONE = 0, HUMAN = 1, NIGHTELF = 2, DWARF = 3, GNOME = 4, ORC = 5, TROLL = 6, SCOURGE = 7, TAUREN = 8 };
local CHARACTER_CLASSES = { NONE = 0, WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 6, MAGE = 7, WARLOCK = 8, DRUID = 9 };

local EVENT_PLAYER_ENTERING_WORLD = "PLAYER_ENTERING_WORLD";
local EVENT_CHARACTER_POINTS_CHANGED = "CHARACTER_POINTS_CHANGED";
local EVENT_PLAYER_EQUIPMENT_CHANGED = "PLAYER_EQUIPMENT_CHANGED";
local EVENT_PLAYER_LEVEL_UP = "PLAYER_LEVEL_UP";
local EVENT_PLAYER_MONEY = "PLAYER_MONEY";
local EVENT_UNIT_HEALTH = "UNIT_HEALTH";
local EVENT_UNIT_MAXHEALTH = "UNIT_MAXHEALTH";
local EVENT_UNIT_POWER_UPDATE = "UNIT_POWER_UPDATE";
local EVENT_UNIT_MAXPOWER = "UNIT_MAXPOWER";

local EVENTS_WITH_UNIT_ID = { UNIT_HEALTH = true, UNIT_MAXHEALTH = true, UNIT_POWER_UPDATE = true, UNIT_MAXPOWER = true };

local mainFrame;
local debugMode = false;
local repaintCdRemainingSec = 0;

local repaint = 0;
local lastMessage = nil;
local playerEnteredWorld = false;

local function CreateQRTip(qrsize, containerFrame)
    if containerFrame.boxes ~= nil then
        return mainFrame;
    end

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
        containerFrame:SetFrameStrata("BACKGROUND")
        containerFrame:SetWidth(qrsize * BLOCK_SIZE)
        containerFrame:SetHeight(qrsize * BLOCK_SIZE)
        containerFrame:SetMovable(true)
        containerFrame:EnableMouse(true)
        containerFrame:SetPoint("TOPLEFT", 0, 0)
        containerFrame:RegisterForDrag("LeftButton") 
        containerFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        containerFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    end

    containerFrame.boxes = {}

    containerFrame.SetBlack = function(idx)
        containerFrame.boxes[idx].texture:SetColorTexture(0, 0, 0)
    end

    containerFrame.SetWhite = function(idx)
        containerFrame.boxes[idx].texture:SetColorTexture(1, 1, 1)
    end

    for i = 1, qrsize * qrsize do
        tinsert(containerFrame.boxes, CreateBlock(i - 1))
    end

    return containerFrame
end

local function ConcatenateStatusValue(status, value)
    if string.len(status) == 0 then
        return "" .. value;
    else 
        return status .. CHAR_FIELD_SEPARATOR .. value
    end
end

local function IntToBase32String(integer) 
    if integer == nil or integer == 0 then
        return "0";
    end
    local base32String = "";
    local divisionResult = integer;
    while divisionResult > 0 do
        local modulo = divisionResult % 32;
        local digit = BASE_32_DIGITS[modulo + 1];
        base32String = digit..base32String;
        divisionResult = math.floor(divisionResult / 32);
    end
    return base32String;
end

local function GetCharacterTalentsInWowheadFormat()
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
            tabBuffer = tabBuffer..CHAR_VALUE_SEPARATOR;
        end
        if tabActive then
            wowheadTalentString = wowheadTalentString..tabBuffer;
            tabBuffer = "";
        end
    end
    return wowheadTalentString;
end

local function GetCharacterEquipment()
    local characterEquipment = "";
    for index, inventorySlot in ipairs(EQUIPMENT_SLOTS) do
        if index > 1 then
            characterEquipment = characterEquipment..CHAR_VALUE_SEPARATOR;
        end
        local slotId, _ = GetInventorySlotInfo(inventorySlot);
        local equippedItemId = GetInventoryItemID(PLAYER, slotId);
        if equippedItemId ~= nil then
            local itemIdBase32 = IntToBase32String(equippedItemId);
            characterEquipment = characterEquipment..itemIdBase32;
        end
    end
    return characterEquipment;
end


local function GetCharacterStatus() 
    local characterStatus = "";

    -- TODO: Figure out encoding of character name (ideally we want only uppercase letters for smaller QR codes)
    -- Name currently removed because it is a major pain to encode and it's typically visible on UI at a glance
    -- local characterStatus = ConcatenateStatusValue(characterStatus, UnitName(PLAYER));
    
    -- CLASS
    local _, englishClass, _ = UnitClass(PLAYER);
    englishClass = string.upper(englishClass);
    local classId = CHARACTER_CLASSES[englishClass];
    if classId == nil then
        classId = 0;
    end
    characterStatus = ConcatenateStatusValue(characterStatus, classId);
    -- RACE
    local _, raceEn, _ = UnitRace(PLAYER);
    raceEn = string.upper(raceEn);
    local raceId = CHARACTER_RACES[raceEn];
    if raceId == nil then
        raceId = 0;
    end
    characterStatus = ConcatenateStatusValue(characterStatus, raceId);
    -- LEVEL
    characterStatus = ConcatenateStatusValue(characterStatus, IntToBase32String(UnitLevel(PLAYER)));
    -- TALENTS
    characterStatus = ConcatenateStatusValue(characterStatus, GetCharacterTalentsInWowheadFormat());
    -- EQUIPMENT
    characterStatus = ConcatenateStatusValue(characterStatus, GetCharacterEquipment());
    -- CURRENT HP
    characterStatus = ConcatenateStatusValue(characterStatus, IntToBase32String(UnitHealth(PLAYER)));
    -- MAX HP
    characterStatus = ConcatenateStatusValue(characterStatus, IntToBase32String(UnitHealthMax(PLAYER)));
    -- CURRENT MANA/ENERGY/RAGE
    characterStatus = ConcatenateStatusValue(characterStatus, IntToBase32String(UnitPower(PLAYER)));
    -- MAX MANA/ENERGY/RAGE
    characterStatus = ConcatenateStatusValue(characterStatus, IntToBase32String(UnitPowerMax(PLAYER)));
    -- GOLD
    characterStatus = ConcatenateStatusValue(characterStatus, IntToBase32String(GetMoney()));
    
    return characterStatus;
end

local function PadMessageToMinLength(message, minLength, paddingChar) 
    if message == nil then
        return message;
    end
    local messageLength = string.len(message);
    if messageLength < minLength then
        local paddedMessage = message;
        for i = 1, minLength - messageLength do
            paddedMessage = paddedMessage..paddingChar;
        end
        return paddedMessage;
    else 
        return message;
    end
end

local function RefreshQRCode() 
    local characterStatus = GetCharacterStatus();
    local message = PadMessageToMinLength(characterStatus, MIN_MESSAGE_SIZE, CHAR_PADDING);
    if message == lastMessage then
        -- Skip painting 
        return;
    end
    lastMessage = message;
    repaint = repaint + 1;
    if debugMode then
        DEFAULT_CHAT_FRAME:AddMessage(repaint);
    end
    
    local ok, qrcodeOrErrorMessage = qrcode(message, 1)
    if not ok then
        print(qrcodeOrErrorMessage)
    else
        local tab = qrcodeOrErrorMessage
        local size = #tab

        local f = CreateQRTip(size, mainFrame)
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

local function OnUpdateHandler(self, elapsed)
    repaintCdRemainingSec = repaintCdRemainingSec - elapsed;
    if repaintCdRemainingSec <= 0 then
        RefreshQRCode();
        repaintCdRemainingSec = repaintCdRemainingSec + REPAINT_CD_SEC;
    end
end

mainFrame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate");
mainFrame:SetScript("OnUpdate", OnUpdateHandler);

--mainFrame:RegisterEvent(EVENT_CHARACTER_POINTS_CHANGED);
--mainFrame:RegisterEvent(EVENT_PLAYER_EQUIPMENT_CHANGED);
--mainFrame:RegisterEvent(EVENT_PLAYER_LEVEL_UP);
--mainFrame:RegisterEvent(EVENT_PLAYER_MONEY);
--mainFrame:RegisterEvent(EVENT_UNIT_HEALTH);
--mainFrame:RegisterEvent(EVENT_UNIT_MAXHEALTH);
--mainFrame:RegisterEvent(EVENT_UNIT_POWER_UPDATE);
--mainFrame:RegisterEvent(EVENT_UNIT_MAXPOWER);



local function EventHandler(self, event, ...)
    --if EVENTS_WITH_UNIT_ID[event] == true then
    --    local unitId = ...;
    --    if unitId ~= PLAYER then
            -- Ignore this event if it doesn't pertain to the player
    --        return;
    --    end
    -- end
    --RefreshQRCode();
    --mainFrame:SetScript("OnUpdate", OnUpdateHandler);
end

mainFrame:SetScript("OnEvent", EventHandler);
mainFrame:RegisterEvent(EVENT_PLAYER_ENTERING_WORLD);

SlashCmdList["QRCODE"] = function(cmdParam, editbox)
    if cmdParam == "debug" then
        debugMode = not debugMode;
        DEFAULT_CHAT_FRAME:AddMessage("wow-qrcode debug mode set to "..tostring(debugMode));
    else 
        RefreshQRCode();
    end
end

SLASH_QRCODE1 = "/QRCODE"
