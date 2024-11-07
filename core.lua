
local _, ADDONSELF = ...

local qrcode = ADDONSELF.qrcode

local BLOCK_SIZE = 10

local function CreateQRTip(qrsize)
    local f = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")

    local function CreateBlock(idx)
        local t = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate")

        t:SetWidth(BLOCK_SIZE)
        t:SetHeight(BLOCK_SIZE)
        t.texture = t:CreateTexture(nil, "OVERLAY")
        t.texture:SetAllPoints(t)

        local x = (idx % qrsize) * BLOCK_SIZE
        local y = (math.floor(idx / qrsize)) * BLOCK_SIZE

        t:SetPoint("TOPLEFT", f, x, -y);

        return t
    end
    
    do
        f:SetFrameStrata("BACKGROUND")
        f:SetWidth(qrsize * BLOCK_SIZE)
        f:SetHeight(qrsize * BLOCK_SIZE)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:SetPoint("CENTER", 0, 0)
        f:RegisterForDrag("LeftButton") 
        f:SetScript("OnDragStart", function(self) self:StartMoving() end)
        f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    end

    f.boxes = {}

    f.SetBlack = function(idx)
        f.boxes[idx].texture:SetColorTexture(0, 0, 0)
    end

    f.SetWhite = function(idx)
        f.boxes[idx].texture:SetColorTexture(1, 1, 1)
    end

    for i = 1, qrsize * qrsize do
        tinsert(f.boxes, CreateBlock(i - 1))
    end

    return f
end


SlashCmdList["QRCODE"] = function(msg, editbox)
    local ok, tab_or_message = qrcode(msg, 4)
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
