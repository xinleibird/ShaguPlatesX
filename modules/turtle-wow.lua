-- skip module initialization on every other client than turtle-wow
if not TargetHPText or not TargetHPPercText then return end

ShaguPlatesX:RegisterModule("turtle-wow", "vanilla", function ()
  -- TODO: Implement debuff refresh special cases via UNIT_CASTEVENT:
  -- 1. Paladin: Refresh judgement debuffs when Holy Strike lands
  -- 2. Warlock: Reduce Immolate duration by 3s after Conflagrate lands
  -- See todo.md for details

  -- turtle wow totemic recall clear totem indicators
  local _, class = UnitClass("player")
  if libtotem and class == "SHAMAN" then
    local trecall = CreateFrame("Frame", "pfTotemsRecall", UIParent)
    trecall:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
    trecall:SetScript("OnEvent", function()
      if arg1 and string.find(arg1, T["You gain (.+) Mana from Totemic Recall"]) then
        for i = 1, 4 do libtotem:Clean(i) end
      end
    end)
  end

  local delay = CreateFrame("Frame")
  delay:SetScript("OnUpdate", function()
    this:Hide()

    -- correct positions of new game menu layout
    if GameMenuButtonShop and (GameMenuButtonSHAGUPLATES or GameMenuButtonSHAGUPLATESAddOns) then
      -- calculate new offset for the shop button
      local offset = 0
      local offset = GameMenuButtonSHAGUPLATES and offset + 22 or offset
      local offset = GameMenuButtonSHAGUPLATESAddOns and offset + 22 or offset
      local offset = offset > 0 and offset + 22 or offset

      -- move ShaguPlates and addons to top position
      GameMenuButtonShop:ClearAllPoints()
      GameMenuButtonShop:SetPoint("TOP", 0, -offset)

      -- restore turtle wow's custom menu layout
      GameMenuButtonOptions:ClearAllPoints()
      GameMenuButtonOptions:SetPoint("TOP", GameMenuButtonShop, "BOTTOM", 0, -16)

      -- apply ShaguPlates skin to the new shop button
      if ShaguPlatesX.skin["Game Menu"] and ShaguPlatesX_config["disabled"]["skin_Game Menu"] ~= "1" then
        local font = GameMenuButtonShop:GetFontString()
        font:SetTextColor(1,1,1,1)
        SkinButton(GameMenuButtonShop)
      end
    end

    -- add druids tree of life and fast travel form to autoshift
    if ShaguPlatesX.autoshift then
      table.insert(ShaguPlatesX.autoshift.shapeshifts, "ability_druid_treeoflife")
      table.insert(ShaguPlatesX.autoshift.shapeshifts, "ability_druid_stagform")
    end

    -- apply chat styles to hardcore chat
    if ShaguPlatesX.chat and ShaguPlatesX.chat.left then
      -- read and parse chat bracket settings
      local left = "|r" .. string.sub(C.chat.text.bracket, 1, 1)
      local right = string.sub(C.chat.text.bracket, 2, 2) .. "|r"
      local default = " " .. "%s" .. "|r:" .. "\32"
      _G.CHAT_HARDCORE_GET = left .. "H" .. right .. default
    end

    -- disable some new spells from tracking frame
    if ShaguPlatesX.tracking then
      ShaguPlatesX.tracking.invalidSpells["Earthshaker Slam"] = true

      -- reload spells and menu
      ShaguPlatesX.tracking:RefreshSpells()
      ShaguPlatesX.tracking:RefreshMenu()
    end

    -- disable turtle wow's map window implementation
    if ShaguPlatesX.map and not Cartographer and not METAMAP_TITLE then
      _G.WorldMapFrame_Maximize()
      ShaguPlatesX.map.loader:GetScript("OnEvent")()

      _G.WorldMapFrame_Minimize = function() return end
      _G.WorldMapFrame_Maximize = function() return end

      _G.WorldMapFrameMaximizeButton.Show = function() return end
      _G.WorldMapFrameMaximizeButton:Hide()

      _G.WorldMapFrameMinimizeButton.Show = function() return end
      _G.WorldMapFrameMinimizeButton:Hide()

      WorldMapFrameTitle.Show = function() return end
      WorldMapFrameTitle:Hide()
    end

    if ShaguPlatesX.panel and pfPanelWidgetClock then
      pfPanelWidgetClock.Tooltip = function()
        GameTooltip:ClearLines()
        GameTooltip_SetDefaultAnchor(GameTooltip, this)
        local servertime, zonetime, time
        local zh, zm = GetGameTime()
        local sh, sm = zh, zm

        -- convert custom zonetime to servertime
        SetMapToCurrentZone()
        if GetCurrentMapContinent() == 1 then
          sh = sh + 12
          sh = sh >= 24 and sh - 24 or sh
        end

        -- perform am/pm calculations
        if C.global.twentyfour == "0" then
          local zn, sn = " AM", " AM"

          if zh > 12 then
            zh = zh - 12
            zn = " PM"
          end

          if sh > 12 then
            sh = sh - 12
            sn = " PM"
          end

          time = date("%I:%M %p")
          servertime = string.format("%.2d:%.2d %s", sh, sm, sn)
          zonetime = string.format("%.2d:%.2d %s", zh, zm, zn)
        else
          time = date("%H:%M")
          servertime = string.format("%.2d:%.2d", sh, sm)
          zonetime = string.format("%.2d:%.2d", zh, zm)
        end

        -- create the tooltip
        GameTooltip:AddLine("|cff555555" .. T["Time"])
        GameTooltip:AddDoubleLine(T["Localtime"],  "|cffffffff" .. time)
        GameTooltip:AddDoubleLine(T["Servertime"], "|cffffffff".. servertime)
        GameTooltip:AddDoubleLine(T["Zonetime"], "|cffffffff".. zonetime)
        GameTooltip:AddLine(" ")
        if TimeManagerFrame then
          GameTooltip:AddDoubleLine(T["Left Click"], "|cffffffff" .. T["Show/Hide TimeManager"])
        else
          GameTooltip:AddDoubleLine(T["Left Click"], "|cffffffff" .. T["Show/Hide Timer"])
          GameTooltip:AddDoubleLine(T["Right Click"], "|cffffffff" .. T["Reset Timer"])
        end
        GameTooltip:Show()
      end
    end

    -- skin title dropdown menu
    -- taken from: https://github.com/doorknob6/ShaguPlates-turtle/blob/master/skins/turtle/character.lua
    if TWTitles and ShaguPlatesX.skin["Character"] and ShaguPlatesX_config["disabled"]["skin_Character"] ~= "1" then
      CharacterLevelText:SetPoint("TOP", CharacterNameText, "BOTTOM", 0, -2)
      SkinDropDown(TWTitles)
      TWTitles:SetPoint("TOP", CharacterGuildText, "BOTTOM", 0, -2)
      TWTitlesText:SetPoint("LEFT", TWTitles.backdrop, "LEFT", 6, 2)
      CharacterResistanceFrame:SetPoint("TOP", TWTitles, "BOTTOM", 0, 0)
    end
  end)

  -- add skin to twow's talent inspect frame
  -- 2026-08-23 整块停用：pfUI 已在 skins/blizzard/inspect.lua 和 modules/turtle-wow.lua
  -- 里完整美化检视天赋框，此处重复处理（TWTalentFrameTab1 锚点写法还不一样）导致错位
  --[[
  if not (ShaguPlatesX_config["disabled"] and ShaguPlatesX_config["disabled"]["skin_Inspect"]  == "1") then
    local initialized = false

    HookAddonOrVariable("Blizzard_InspectUI", function()
      hooksecurefunc("InspectFrame_Show", function()
        -- break if theres nothing left to do
        if initialized then return end

        -- adjust ui positions
        SkinTab(InspectFrameTab3)
        InspectFrameTab3:ClearAllPoints()
        InspectFrameTab3:SetPoint("LEFT", InspectFrameTab2, "RIGHT", GetBorderSize()*2 + 1, 0)
        TWTalentFrameTab1:SetPoint("TOPLEFT", TWTalentFrameScrollFrame, "TOPLEFT", 2, TWTalentFrameTab1:GetHeight() + 4)

        -- reload text position
        InspectFrameTab3:Hide()
        InspectFrameTab3:Show()

        -- skin inspect window elements
        StripTextures(InspectTalentsFrame)
        StripTextures(TWTalentFrameScrollFrame)
        SkinScrollbar(TWTalentFrameScrollFrameScrollBar)
        for i = 1, 3 do
          SkinTab(_G["TWTalentFrameTab"..i])
        end

        -- skin each talent button
        local i = 1
        while true do
          local talent = _G["TWTalentFrameTalent" .. i]
          if not talent then break end

          StripTextures(talent)
          SkinButton(talent, nil, nil, nil, _G["TWTalentFrameTalent" .. i .. "IconTexture"])

          local rank = _G["TWTalentFrameTalent" .. i .. "Rank"]
          if rank then
            rank:SetFont(ShaguPlatesX.font_default, C.global.font_size, "OUTLINE")
          end

          i = i + 1
        end

        -- only run once
        initialized = true
      end, true)
    end)
  end
  --]]

  -- rearrange twow's profession window additions
  HookAddonOrVariable("Blizzard_TradeSkillUI", function()
    if TradeSkillSkillCheckButton and ShaguPlatesX.skin["Profession"] and ShaguPlatesX_config["disabled"]["skin_Profession"] ~= "1" then
      SkinCheckbox(TradeSkillSkillCheckButton)
      TradeSkillSkillCheckButton:SetWidth(24)
      TradeSkillSkillCheckButton:SetHeight(24)

      SkinCheckbox(TradeSkillMatsCheckButton)
      TradeSkillMatsCheckButton:SetWidth(24)
      TradeSkillMatsCheckButton:SetHeight(24)

      TradeSkillSearchBox:DisableDrawLayer("BACKGROUND")
      CreateBackdrop(TradeSkillSearchBox, nil, nil, 1)

      TradeSkillSkillCheckButton:SetPoint("TOPLEFT", 500, -2)
      TradeSkillMatsCheckButton:SetPoint("TOPLEFT", 400, -2)

      TradeSkillSearchBox:ClearAllPoints()
      TradeSkillSearchBox:SetPoint("TOP", TradeSkillFrame, "BOTTOM", 0, -8)
    end
  end)
end)
