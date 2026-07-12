GameTooltip:HookScript("OnTooltipSetUnit", function(self)
    local _, unit = self:GetUnit()
    if not unit then return end

    local name = UnitName(unit)
    if not name or name == "Unknown" then return end
    if name == UnitName("player") then return end

    local score = RememberMe_GetScore(name)
    if score and score > 0 then
        self:AddLine("|cff00ff00Remember Me: Familiarity " .. score .. "|r")
        self:Show()
    end
end)
