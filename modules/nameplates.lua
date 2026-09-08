ShaguPlatesX:RegisterModule("nameplates", "vanilla", function ()

  -- disable original castbars
  pcall(SetCVar, "ShowVKeyCastbar", 0)

  -- 敌友色板（不透明）
  local unitcolors = {
    ["ENEMY_NPC"] = { .9, .2, .3, 1 },
    ["NEUTRAL_NPC"] = { 1, 1, .3, 1 },
    ["FRIENDLY_NPC"] = { .6, 1, 0, 1 },
    ["ENEMY_PLAYER"] = { .9, .2, .3, 1 },
    ["FRIENDLY_PLAYER"] = { .2, .6, 1, 1 }
  }

  -- 主城名单（按客户端 locale 硬编码 6 大主城）
  local cityZones
  do
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "zhCN" then
      cityZones = {
        ["暴风城"]   = true,
        ["铁炉堡"]   = true,
        ["达纳苏斯"] = true,
        ["奥格瑞玛"] = true,
        ["雷霆崖"]   = true,
        ["幽暗城"]   = true,
      }
    else
      cityZones = {
        ["Stormwind City"] = true,
        ["Ironforge"]      = true,
        ["Darnassus"]      = true,
        ["Orgrimmar"]      = true,
        ["Thunder Bluff"]  = true,
        ["Undercity"]      = true,
      }
    end
  end
  local inCity = false
  local cityChecked = false

  -- 定制职业色板（比暴雪原色柔和）
  local mhtui_classcolors = {
    ["WARRIOR"] = { 0.8392, 0.5882, 0.3098 },
    ["MAGE"]    = { 0.0784, 0.7098, 0.9451 },
    ["ROGUE"]   = { 1.0000, 0.8980, 0.3686 },
    ["DRUID"]   = { 1.0000, 0.4900, 0.0400 },
    ["HUNTER"]  = { 0.6902, 1.0000, 0.1922 },
    ["SHAMAN"]  = { 0.0392, 0.4902, 0.9294 },
    ["PRIEST"]  = { 1.0000, 1.0000, 1.0000 },
    ["WARLOCK"] = { 0.5216, 0.3804, 0.9294 },
    ["PALADIN"] = { 0.9608, 0.5490, 0.7294 },
  }

  local combatstate = {
    -- gets overwritten by user config
    ["NOTHREAT"] = { r = 1, g = 0, b = 0, a = 1 },     -- Red: not targeting you
    ["THREAT"]   = { r = 0, g = 1, b = 0, a = 1 },     -- Green: targeting you (has aggro)
    ["CASTING"]  = { r = .7, g = .2, b = .7, a = 1 },  -- Purple: casting
    ["STUN"]     = { r = 1, g = 1, b = 0, a = .6 },    -- Yellow: stunned/no target
    ["NONE"]     = { r = .2, g = .2, b = .2, a = 1 },
  }

  local elitestrings = {
    ["elite"] = "+",
    ["rareelite"] = "R+",
    ["rare"] = "R",
    ["boss"] = "B",
    ["worldboss"] = "B"
  }

  -- catch all nameplates
  local childs, regions, plate
  local initialized = 0
  local parentcount = 0
  local platecount = 0
  local registry = {}
  local activePlates = {}
  local fastUpdatePlates = {}
  local debuffdurations = C.appearance.cd.debuffs == "1" and true or nil

  -- SuperWoW performance optimization: GUID-based registry for O(1) lookups
  local guidRegistry = {}   -- guid -> plate
  local guidMetaCache = {}  -- guid -> stable unit data
  local castEvents = {}     -- guid -> cast info
  local debuffCache = {}    -- guid -> { [spellID] = { start, duration } }
  local ownDebuffTracker = {} -- guid -> { [spellID] = true }
  local threatMemory = {}   -- guid -> true if mob had player targeted (persists through casts)
  local playerInCombat = false
  
  -- Optimized lookup caches
  local critter_cache = {}
  local nameplate_critter_hash = nil
  local totem_cache = {}
  local name_cache = {}

  -- wipe polyfill
  local wipe = wipe or function(t) for k in pairs(t) do t[k] = nil end end

  -- Throttle constants
  local THROTTLE_INTERVAL = 0.1        -- 100ms slow path for all visible plates
  local PLATE_SCAN_INTERVAL = 0.1      -- 100ms worldframe scan for new plates
  local CACHE_CLEANUP_INTERVAL = 5     -- cleanup runtime caches every 5s
  local CACHE_RETENTION_SECONDS = 15   -- keep hidden GUID data briefly for reuse
  local ICON_BASE_SCALE = 0.75
  -- Cache frequently accessed config values (updated on config change)
  local cfg_showcastbar, cfg_targetcastbar, cfg_notargalpha, cfg_namefightcolor, cfg_showtargetname
  local cfg_spellname, cfg_showhp, cfg_showdebuffs, cfg_selfdebuff, cfg_layoutold, cfg_oldborder
  local cfg_targetzoom, cfg_zoomval, cfg_zoominstant, cfg_width, cfg_heighthealth

  -- store SuperAPI_Castlib original scripts for restore
  local superapi_castlib_stored = false
  local superapi_castlib_onupdate, superapi_castlib_onevent
  local ownDebuffEventsRegistered = nil

  local function HasMinimumNampowerVersion(major, minor, patch)
    if type(GetNampowerVersion) ~= "function" then
      return nil
    end

    local installedMajor, installedMinor, installedPatch = GetNampowerVersion()
    installedMajor = tonumber(installedMajor) or 0
    installedMinor = tonumber(installedMinor) or 0
    installedPatch = tonumber(installedPatch) or 0

    if installedMajor > major then
      return true
    elseif installedMajor == major and installedMinor > minor then
      return true
    elseif installedMajor == major and installedMinor == minor and installedPatch >= patch then
      return true
    end
  end

  local function SupportsOwnDebuffTracking()
    if type(GetUnitField) ~= "function" then
      return nil
    end

    if type(GetNampowerVersion) == "function" and not HasMinimumNampowerVersion(2, 30, 0) then
      return nil
    end

    return true
  end

  local function TrackOwnDebuff(guid, spellID)
    if not guid or not spellID then return end
    if not ownDebuffTracker[guid] then
      ownDebuffTracker[guid] = {}
    end

    ownDebuffTracker[guid][spellID] = true
  end

  local function UntrackOwnDebuff(guid, spellID)
    if not guid or not spellID or not ownDebuffTracker[guid] then return end

    ownDebuffTracker[guid][spellID] = nil
    if not next(ownDebuffTracker[guid]) then
      ownDebuffTracker[guid] = nil
    end
  end

  local function RefreshOwnDebuffDisplay(guid, spellID, removeOnly)
    if not guid or not spellID then return end

    if removeOnly then
      UntrackOwnDebuff(guid, spellID)
    else
      local trackedAlready = ownDebuffTracker[guid] and ownDebuffTracker[guid][spellID]
      TrackOwnDebuff(guid, spellID)
      if debuffdurations and not trackedAlready then
        local spellName = SpellInfo(spellID)
        local duration = spellName and L["debuffs"][spellName] and L["debuffs"][spellName][0] or nil
        if not debuffCache[guid] then debuffCache[guid] = {} end
        debuffCache[guid][spellID] = { start = GetTime(), duration = duration }
      end
    end

    local plate = guidRegistry[guid]
    if plate and plate.nameplate then
      plate.nameplate.debuffUpdate = true
    end
  end

  local function PruneOwnDebuffs(guid)
    if not guid or not ownDebuffTracker[guid] or type(GetUnitField) ~= "function" then return end

    local auras = GetUnitField(guid, "aura")
    if type(auras) ~= "table" then return end

    local active = {}
    for _, auraSpellID in pairs(auras) do
      if auraSpellID and auraSpellID > 0 then
        active[auraSpellID] = true
      end
    end

    for spellID in pairs(ownDebuffTracker[guid]) do
      if not active[spellID] then
        ownDebuffTracker[guid][spellID] = nil
      end
    end

    if not next(ownDebuffTracker[guid]) then
      ownDebuffTracker[guid] = nil
    end
  end

  local function RegisterOwnDebuffEvents(frame)
    if ownDebuffEventsRegistered then return end
    if not SupportsOwnDebuffTracking() then return end

    local added = pcall(frame.RegisterEvent, frame, "DEBUFF_ADDED_SELF")
    local removed = pcall(frame.RegisterEvent, frame, "DEBUFF_REMOVED_SELF")
    local spellgo = pcall(frame.RegisterEvent, frame, "SPELL_GO_SELF")
    local spelldmg = pcall(frame.RegisterEvent, frame, "SPELL_DAMAGE_EVENT_SELF")
    if added or removed or spellgo or spelldmg then
      ownDebuffEventsRegistered = true
    end
  end

  local function CacheConfig()
    cfg_showcastbar = C.nameplates["showcastbar"] == "1"
    cfg_showtargetname = C.nameplates["showtargetname"] == "1"
    cfg_targetcastbar = C.nameplates["targetcastbar"] == "1"

    -- manage SuperAPI_Castlib based on our castbar setting
    if C.global.override_superapi_castlib == "1" and SuperAPI_Castlib then
      if cfg_showcastbar then
        -- store and disable SuperAPI_Castlib
        if not superapi_castlib_stored then
          superapi_castlib_onupdate = SuperAPI_Castlib:GetScript("OnUpdate")
          superapi_castlib_onevent = SuperAPI_Castlib:GetScript("OnEvent")
          superapi_castlib_stored = true
          SuperAPI_Castlib:UnregisterAllEvents()
          SuperAPI_Castlib:SetScript("OnUpdate", nil)
          SuperAPI_Castlib:SetScript("OnEvent", nil)
          SuperAPI_nameplatebars = false
        end
      elseif superapi_castlib_stored then
        -- restore SuperAPI_Castlib
        SuperAPI_Castlib:RegisterEvent("UNIT_CASTEVENT")
        SuperAPI_Castlib:SetScript("OnUpdate", superapi_castlib_onupdate)
        SuperAPI_Castlib:SetScript("OnEvent", superapi_castlib_onevent)
        SuperAPI_nameplatebars = true
        superapi_castlib_stored = false
      end
    end
    cfg_notargalpha = tonumber(C.nameplates.notargalpha) or 0.5
    cfg_namefightcolor = C.nameplates.namefightcolor == "1"
    cfg_spellname = C.nameplates.spellname == "1"
    cfg_layoutold = C.nameplates["layout"] == "old"
    cfg_oldborder = C.nameplates["oldborder"] == "1"
    cfg_showhp = C.nameplates.showhp == "1"
    cfg_showdebuffs = C.nameplates["showdebuffs"] == "1"
    cfg_selfdebuff = C.nameplates.selfdebuff == "1" and ownDebuffEventsRegistered and true or false
    cfg_targetzoom = C.nameplates.targetzoom == "1"
    cfg_zoomval = (tonumber(C.nameplates.targetzoomval) or 0.4) + 1
    cfg_zoominstant = C.nameplates.targetzoominstant == "1"
    cfg_width = tonumber(C.nameplates.width) or 120
    cfg_heighthealth = tonumber(C.nameplates.heighthealth) or 8
  end

  -- cache default border color (默认黑色)
  local er, eg, eb, ea = 0, 0, 0, 1
  -- 选中时的边框颜色（白色）
  local target_er, target_eg, target_eb, target_ea = 1, 1, 1, 1
  -- 旧版边框的默认色（跟随全局边框配置色）
  local border_er, border_eg, border_eb, border_ea = GetStringColor(ShaguPlatesX_config.appearance.border.color)

  local targetGuidCache = setmetatable({}, {
    __index = function(t, k)
      local v = k.."target"
      t[k] = v
      return v
    end
  })

  local nextPlateScan = 0
  local nextSlowUpdate = 0
  local nextCacheCleanup = 0

  local function TouchGuid(guid, now)
    if not guid then return end

    local data = guidMetaCache[guid]
    if not data then
      data = {}
      guidMetaCache[guid] = data
    end

    data.lastSeen = now or GetTime()
    return data
  end

  local function GetGuidMeta(guid, now)
    if not guid then return nil end

    local data = TouchGuid(guid, now)
    if data.player == nil then
      data.player = UnitIsPlayer(guid) and true or false
    end

    if data.class == nil and data.player then
      local _, classToken = UnitClass(guid)
      data.class = classToken or false
    end

    if data.elite == nil then
      data.elite = UnitClassification(guid) or false
    end

    if data.guild == nil then
      local guild = GetGuildInfo(guid)
      data.guild = guild or false
    end

    return data
  end

  local function CleanupUnusedCache(now)
    if now < nextCacheCleanup then return end
    nextCacheCleanup = now + CACHE_CLEANUP_INTERVAL

    local cutoff = now - CACHE_RETENTION_SECONDS
    local function prune(tbl)
      for guid in pairs(tbl) do
        local data = guidMetaCache[guid]
        if not guidRegistry[guid] and (not data or not data.lastSeen or data.lastSeen < cutoff) then
          tbl[guid] = nil
        end
      end
    end

    prune(debuffCache)
    prune(ownDebuffTracker)
    prune(castEvents)
    prune(threatMemory)

    for guid, data in pairs(guidMetaCache) do
      if not guidRegistry[guid] and (not data.lastSeen or data.lastSeen < cutoff) then
        guidMetaCache[guid] = nil
        targetGuidCache[guid] = nil
      end
    end
  end

  local function UpdateIconScale(nameplate)
    if not nameplate or not nameplate.health or not cfg_width or cfg_width <= 0 then return end

    local zoomScale = (nameplate.health:GetWidth() or cfg_width) / cfg_width
    local raidSize = (tonumber(C.nameplates.raidiconsize) or 50) * ICON_BASE_SCALE * zoomScale

    if nameplate.lastRaidIconSize ~= raidSize then
      nameplate.lastRaidIconSize = raidSize
      nameplate.raidicon:SetWidth(raidSize)
      nameplate.raidicon:SetHeight(raidSize)
    end
  end

  local function GetCombatStateColor(guid)
    local target = targetGuidCache[guid]
    local color = false

    if playerInCombat and UnitAffectingCombat(guid) and not UnitCanAssist("player", guid) then
      local isCasting = castEvents[guid] and castEvents[guid].endTime and GetTime() < castEvents[guid].endTime
      local targetingPlayer = UnitIsUnit(target, "player")

      -- Remember if mob targets player, clear only when targeting someone else while NOT casting
      if targetingPlayer then
        threatMemory[guid] = true
      elseif UnitExists(target) and not isCasting then
        threatMemory[guid] = nil
      end

      if C.nameplates.ccombatcasting == "1" and isCasting then
        color = combatstate.CASTING
      elseif C.nameplates.ccombatthreat == "1" and (targetingPlayer or threatMemory[guid]) then
        color = combatstate.THREAT
      elseif C.nameplates.ccombatnothreat == "1" and UnitExists(target) then
        color = combatstate.NOTHREAT
      elseif C.nameplates.ccombatstun == "1" and not UnitExists(target) and not UnitIsPlayer(guid) then
        color = combatstate.STUN
      end
    end

    return color
  end

  local function DoNothing()
    return
  end

  local function IsNamePlate(frame)
    if frame:GetObjectType() ~= NAMEPLATE_FRAMETYPE then return nil end
    local region = frame:GetRegions()

    if not region then return nil end
    if not region.GetObjectType then return nil end
    if not region.GetTexture then return nil end

    if region:GetObjectType() ~= "Texture" then return nil end
    return region:GetTexture() == "Interface\\Tooltips\\Nameplate-Border" or nil
  end

  local function DisableObject(object)
    if not object then return end
    if not object.GetObjectType then return end

    local otype = object:GetObjectType()

    if otype == "Texture" then
      object:SetTexture("")
      object:SetTexCoord(0, 0, 0, 0)
    elseif otype == "FontString" then
      object:SetWidth(0.001)
    elseif otype == "StatusBar" then
      object:SetStatusBarTexture("")
    end
  end

  local function TotemPlate(name)
    if not name then return nil end
    if totem_cache[name] ~= nil then return totem_cache[name] end

    if C.nameplates.totemicons == "1" then
      for totem, icon in pairs(L["totems"]) do
        if string.find(name, totem) then
          totem_cache[name] = icon
          return icon
        end
      end
    end
    
    totem_cache[name] = false
    return nil
  end

  local function HidePlate(unittype, name, fullhp, target)
    -- keep some plates always visible according to config
    if C.nameplates.fullhealth == "1" and not fullhp then return nil end
    if C.nameplates.target == "1" and target then return nil end

    -- return true when something needs to be hidden
    if C.nameplates.enemynpc == "1" and unittype == "ENEMY_NPC" then
      return true
    elseif C.nameplates.enemyplayer == "1" and unittype == "ENEMY_PLAYER" then
      return true
    elseif C.nameplates.neutralnpc == "1" and unittype == "NEUTRAL_NPC" then
      return true
    elseif C.nameplates.friendlynpc == "1" and unittype == "FRIENDLY_NPC" then
      return true
    elseif C.nameplates.friendlyplayer == "1" and unittype == "FRIENDLY_PLAYER" then
      return true
    elseif C.nameplates.critters == "1" and unittype == "NEUTRAL_NPC" then
      if critter_cache[name] ~= nil then return critter_cache[name] end
      
      if not nameplate_critter_hash then
        nameplate_critter_hash = {}
        for _, critter in pairs(L["critters"]) do
          nameplate_critter_hash[string.lower(critter)] = true
        end
      end
      
      local isCritter = nameplate_critter_hash[string.lower(name)] and true or false
      critter_cache[name] = isCritter
      return isCritter
    elseif C.nameplates.totems == "1" then
      return TotemPlate(name) and true or nil
    end

    -- nothing to hide
    return nil
  end

  local function SetPlateHealthVisible(plate, visible)
    if not plate or not plate.health then return end

    if visible then
      plate.health:Show()
      -- 旧版边框开启时不恢复新版贴图边框(避免两套边框叠加)
      if plate.health.backdrop and not cfg_oldborder then
        plate.health.backdrop:Show()
      end
    else
      plate.health:Hide()
      if plate.health.backdrop then
        plate.health.backdrop:Hide()
      end
    end
  end

  local function abbrevname(t)
    return string.sub(t,1,1)..". "
  end

  local function GetNameString(name)
    if not name then return "" end
    if name_cache[name] then return name_cache[name] end

    local rawName = name
    local abbrev = ShaguPlatesX_config.unitframes.abbrevname == "1" or nil
    local size = 20

    -- first try to only abbreviate the first word
    if abbrev and name and strlen(name) > size then
      name = string.gsub(name, "^(%S+) ", abbrevname)
    end

    -- abbreviate all if it still doesn't fit
    if abbrev and name and strlen(name) > size then
      name = string.gsub(name, "(%S+) ", abbrevname)
    end

    name_cache[rawName] = name
    return name
  end

  local function ResolveQuestUnitIcon(name)
    if not name or name == "" then
      return nil
    end

    if type(IsQuestUnit) == "function" then
      local icon = IsQuestUnit(GetNameString(name))
      if icon and icon ~= "0" then
        return icon
      end
    end

    return nil
  end


  local function GetUnitType(red, green, blue)
    if red > .9 and green < .2 and blue < .2 then
      return "ENEMY_NPC"
    elseif red > .9 and green > .9 and blue < .2 then
      return "NEUTRAL_NPC"
    elseif red < .2 and green < .2 and blue > 0.9 then
      return "FRIENDLY_PLAYER"
    elseif red < .2 and green > .9 and blue < .2 then
      return "FRIENDLY_NPC"
    end
  end

  local filter, list, cache
  local function DebuffFilterPopulate()
    -- initialize variables
    filter = C.nameplates["debuffs"]["filter"]
    if filter == "none" then return end
    list = C.nameplates["debuffs"][filter]
    cache = {}

    -- populate list
    for _, val in pairs({strsplit("#", list)}) do
      cache[strlower(val)] = true
    end
  end

  local function DebuffFilter(effect)
    if filter == "none" then return true end
    if not cache then DebuffFilterPopulate() end

    if filter == "blacklist" and cache[strlower(effect)] then
      return nil
    elseif filter == "blacklist" then
      return true
    elseif filter == "whitelist" and cache[strlower(effect)] then
      return true
    elseif filter == "whitelist" then
      return nil
    end
  end

  local function GetVisibleDebuff(guid, index)
    local texture, stacks, _, spellID = UnitDebuff(guid, index)
    if not texture then return nil end
    if cfg_selfdebuff and (not spellID or not ownDebuffTracker[guid] or not ownDebuffTracker[guid][spellID]) then
      return false
    end

    return true, texture, stacks, spellID, spellID and SpellInfo(spellID) or nil, nil, nil
  end

  local function ResetDebuffIcon(debuff)
    if not debuff then return end

    debuff.isShown = nil
    debuff.lastTexture = nil
    debuff.lastStacks = nil
    debuff.lastCdSpell = nil
    debuff.lastCdStart = nil
    debuff.lastCdDuration = nil

    if debuff.cd then
      debuff.cd:Hide()
    end

    if debuff.stacks then
      debuff.stacks:Hide()
    end

    debuff:Hide()
  end

  local function CreateDebuffIcon(plate, index)
    plate.debuffs[index] = CreateFrame("Frame", plate.platename.."Debuff"..index, plate)
    plate.debuffs[index]:Hide()
    plate.debuffs[index]:SetFrameLevel(1)

    plate.debuffs[index].icon = plate.debuffs[index]:CreateTexture(nil, "BACKGROUND")
    plate.debuffs[index].icon:SetTexture(.3,1,.8,1)
    plate.debuffs[index].icon:SetAllPoints(plate.debuffs[index])

    plate.debuffs[index].stacks = plate.debuffs[index]:CreateFontString(nil, "OVERLAY")
    plate.debuffs[index].stacks:SetAllPoints(plate.debuffs[index])
    plate.debuffs[index].stacks:SetJustifyH("RIGHT")
    plate.debuffs[index].stacks:SetJustifyV("BOTTOM")
    plate.debuffs[index].stacks:SetTextColor(1,1,0)

    if ShaguPlatesX.client <= 11200 then
      -- create a fake animation frame on vanilla to improve performance
      plate.debuffs[index].cd = CreateFrame("Frame", plate.platename.."Debuff"..index.."Cooldown", plate.debuffs[index])
      plate.debuffs[index].cd:SetScript("OnUpdate", CooldownFrame_OnUpdateModel)
      plate.debuffs[index].cd.AdvanceTime = DoNothing
      plate.debuffs[index].cd.SetSequence = DoNothing
      plate.debuffs[index].cd.SetSequenceTime = DoNothing
    else
      -- use regular cooldown animation frames on burning crusade and later
      plate.debuffs[index].cd = CreateFrame(COOLDOWN_FRAME_TYPE, plate.platename.."Debuff"..index.."Cooldown", plate.debuffs[index], "CooldownFrameTemplate")
    end

    plate.debuffs[index].cd.pfCooldownStyleAnimation = 0
    plate.debuffs[index].cd.pfCooldownType = "ALL"
  end

  local function UpdateDebuffConfig(nameplate, i)
    if not nameplate.debuffs[i] then return end

    -- update debuff positions
    local width = tonumber(C.nameplates.width)
    local debuffsize = tonumber(C.nameplates.debuffsize)
    local debuffoffset = tonumber(C.nameplates.debuffoffset)
    local limit = floor(width / debuffsize)
    local font = C.nameplates.use_unitfonts == "1" and ShaguPlatesX.font_unit or ShaguPlatesX.font_default
    local font_size = C.nameplates.use_unitfonts == "1" and C.global.font_unit_size or C.global.font_size
    local font_style = C.nameplates.name.fontstyle

    local aligna, alignb, offs, space
    if C.nameplates.debuffs["position"] == "BOTTOM" then
      aligna, alignb, offs, space = "TOPLEFT", "BOTTOMLEFT", -debuffoffset, -1
    else
      aligna, alignb, offs, space = "BOTTOMLEFT", "TOPLEFT", debuffoffset, 1
    end

    nameplate.debuffs[i].stacks:SetFont(font, font_size, font_style)
    nameplate.debuffs[i]:ClearAllPoints()
    if i == 1 then
      nameplate.debuffs[i]:SetPoint(aligna, nameplate.health, alignb, 0, offs)
    elseif i <= limit then
      nameplate.debuffs[i]:SetPoint("LEFT", nameplate.debuffs[i-1], "RIGHT", 1, 0)
    elseif i > limit and limit > 0 then
      nameplate.debuffs[i]:SetPoint(aligna, nameplate.debuffs[i-limit], alignb, 0, space)
    end

    nameplate.debuffs[i]:SetWidth(tonumber(C.nameplates.debuffsize))
    nameplate.debuffs[i]:SetHeight(tonumber(C.nameplates.debuffsize))
  end

  -- player GUID for cast event filtering
  local playerGUID = nil

  -- track which GUID has combo points (only one at a time)
  local comboPointGuid = nil

  -- create nameplate core
  local nameplates = CreateFrame("Frame", "pfNameplates", UIParent)
  nameplates:RegisterEvent("PLAYER_ENTERING_WORLD")
  nameplates:RegisterEvent("PLAYER_TARGET_CHANGED")
  nameplates:RegisterEvent("UNIT_COMBO_POINTS")
  nameplates:RegisterEvent("PLAYER_COMBO_POINTS")
  nameplates:RegisterEvent("UNIT_AURA")
  nameplates:RegisterEvent("UNIT_CASTEVENT")
  nameplates:RegisterEvent("PLAYER_REGEN_ENABLED")
  nameplates:RegisterEvent("PLAYER_REGEN_DISABLED")
  nameplates:RegisterEvent("MINIMAP_ZONE_CHANGED")

  nameplates:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
      RegisterOwnDebuffEvents(this)
      _, playerGUID = UnitExists("player")
      playerInCombat = UnitAffectingCombat("player") or false
      CacheConfig()
      inCity = cityZones[GetZoneText()] and true or false
      cityChecked = true
      this:SetGameVariables()

    elseif event == "PLAYER_REGEN_DISABLED" then
      playerInCombat = true

    elseif event == "PLAYER_REGEN_ENABLED" then
      playerInCombat = false
      -- memory leak cleanup: wipe cached data for units not currently on screen
      for cachedGuid in pairs(debuffCache) do
        if not guidRegistry[cachedGuid] then
          debuffCache[cachedGuid] = nil
        end
      end
      for cachedGuid in pairs(ownDebuffTracker) do
        if not guidRegistry[cachedGuid] then
          ownDebuffTracker[cachedGuid] = nil
        end
      end
      for cachedGuid in pairs(castEvents) do
        if not guidRegistry[cachedGuid] then
          castEvents[cachedGuid] = nil
        end
      end
      for cachedGuid in pairs(threatMemory) do
        if not guidRegistry[cachedGuid] then
          threatMemory[cachedGuid] = nil
        end
      end
      for cachedGuid in pairs(targetGuidCache) do
        if not guidRegistry[cachedGuid] then
          targetGuidCache[cachedGuid] = nil
        end
      end

    elseif event == "UNIT_AURA" then
      -- SuperWoW: arg1 is the unit GUID - direct O(1) lookup
      local guid = arg1
      local plate = guidRegistry[guid]
      if plate and plate.nameplate then
        plate.nameplate.auraUpdate = true
        plate.nameplate.debuffUpdate = true

        -- Track debuff start times for duration display
        if debuffdurations then
          if not debuffCache[guid] then debuffCache[guid] = {} end
          local seen = {}

          -- Scan current debuffs and track new ones
          for i = 1, 16 do
            local texture, stacks, _, spellID = UnitDebuff(guid, i)
            if not texture then break end

            seen[spellID] = true
            if not debuffCache[guid][spellID] then
              -- New debuff - record start time and lookup duration
              local spellName = SpellInfo(spellID)
              local duration = L["debuffs"][spellName] and L["debuffs"][spellName][0] or nil
              debuffCache[guid][spellID] = { start = GetTime(), duration = duration }
            end
          end

          -- Clear expired debuffs from cache
          for spellID in pairs(debuffCache[guid]) do
            if not seen[spellID] then
              debuffCache[guid][spellID] = nil
            end
          end
        end

        if ownDebuffEventsRegistered then
          PruneOwnDebuffs(guid)
        end
      end

    elseif event == "DEBUFF_ADDED_SELF" then
      local guid = arg1
      local spellID = arg3

      RefreshOwnDebuffDisplay(guid, spellID)

    elseif event == "DEBUFF_REMOVED_SELF" then
      local guid = arg1
      local spellID = arg3

      RefreshOwnDebuffDisplay(guid, spellID, true)

    elseif event == "SPELL_GO_SELF" then
      local spellID = arg2
      local targetGuid = arg4
      local numTargetsHit = arg6

      if numTargetsHit and numTargetsHit > 0 then
        RefreshOwnDebuffDisplay(targetGuid, spellID)
      end

    elseif event == "SPELL_DAMAGE_EVENT_SELF" then
      local targetGuid = arg1
      local spellID = arg3

      RefreshOwnDebuffDisplay(targetGuid, spellID)

    elseif event == "UNIT_CASTEVENT" then
      local casterGUID = arg1
      local eventType = arg3  -- "START", "CAST", "FAIL", "CHANNEL", "MAINHAND", "OFFHAND"
      local spellID = arg4
      local castDuration = arg5

      -- Skip player casts and melee
      if casterGUID == playerGUID then return end
      if eventType == "MAINHAND" or eventType == "OFFHAND" then return end

      -- Store cast data
      if eventType == "START" or eventType == "CHANNEL" then
        if not castEvents[casterGUID] then castEvents[casterGUID] = {} end
        wipe(castEvents[casterGUID])

        local spellName, _, icon = SpellInfo(spellID)
        castEvents[casterGUID].event = eventType
        castEvents[casterGUID].spellID = spellID
        castEvents[casterGUID].spellName = spellName
        castEvents[casterGUID].icon = icon
        castEvents[casterGUID].startTime = GetTime()
        castEvents[casterGUID].endTime = castDuration and GetTime() + castDuration / 1000
        castEvents[casterGUID].duration = castDuration and castDuration / 1000

      elseif eventType == "CAST" or eventType == "FAIL" then
        if castEvents[casterGUID] and castEvents[casterGUID].spellID == spellID then
          wipe(castEvents[casterGUID])
        end
      end

      -- Flag plate for castbar update
      local plate = guidRegistry[casterGUID]
      if plate and plate.nameplate then
        plate.nameplate.castUpdate = true
        fastUpdatePlates[plate] = true
      end

    elseif event == "PLAYER_TARGET_CHANGED" then
      -- Flag target plate for update
      local _, targetGuid = UnitExists("target")
      if targetGuid then
        local plate = guidRegistry[targetGuid]
        if plate and plate.nameplate then
          plate.nameplate.targetUpdate = true
        end
      end

    elseif event == "PLAYER_COMBO_POINTS" or event == "UNIT_COMBO_POINTS" then
      -- Only update the plate that has/had combo points
      local _, newGuid = UnitExists("target")
      local cp = GetComboPoints("player", "target")

      -- Clear old combo point holder if different
      if comboPointGuid and comboPointGuid ~= newGuid then
        local oldPlate = guidRegistry[comboPointGuid]
        if oldPlate and oldPlate.nameplate then
          oldPlate.nameplate.comboUpdate = true
        end
      end

      -- Update new combo point holder
      if cp and cp > 0 and newGuid then
        comboPointGuid = newGuid
        local plate = guidRegistry[newGuid]
        if plate and plate.nameplate then
          plate.nameplate.comboUpdate = true
        end
      else
        comboPointGuid = nil
      end

    elseif event == "MINIMAP_ZONE_CHANGED" and cityChecked then
      local newCity = cityZones[GetZoneText()] and true or false
      if newCity ~= inCity then
        inCity = newCity
        nameplates:SetGameVariables()
      end
    end
  end)

  -- Cache frame-level state (updated once per frame, used by all plates)
  local frameState = {
    now = 0,
    hasTarget = false,
    targetGuid = nil,
    hasMouseover = false,
  }

  nameplates:SetScript("OnUpdate", function()
    -- Update frame-level cache once per frame
    frameState.now = GetTime()
    frameState.hasTarget,frameState.targetGuid = UnitExists("target")
    frameState.hasMouseover = UnitExists("mouseover")

    -- react to newly created worldframe children immediately so the default
    -- plate does not flash before our overlay takes over; keep a periodic
    -- fallback scan for anything unusual that did not change the child count.
    parentcount = WorldFrame:GetNumChildren()
    if parentcount < initialized then
      initialized = parentcount
    end

    if initialized < parentcount then
      childs = { WorldFrame:GetChildren() }
      for i = initialized + 1, parentcount do
        plate = childs[i]
        if IsNamePlate(plate) and not registry[plate] then
          nameplates.OnCreate(plate)
          registry[plate] = plate
        end
      end

      initialized = parentcount
      nextPlateScan = frameState.now + PLATE_SCAN_INTERVAL
    elseif frameState.now >= nextPlateScan then
      childs = { WorldFrame:GetChildren() }
      for i = 1, parentcount do
        plate = childs[i]
        if IsNamePlate(plate) and not registry[plate] then
          nameplates.OnCreate(plate)
          registry[plate] = plate
        end
      end

      initialized = parentcount
      nextPlateScan = frameState.now + PLATE_SCAN_INTERVAL
    end

    -- smooth updates for animated castbars and zoom transitions only
    for plate in pairs(fastUpdatePlates) do
      if activePlates[plate] then
        nameplates.OnUpdate(plate, frameState)
      else
        fastUpdatePlates[plate] = nil
      end
    end

    -- slow path for all active plates
    if frameState.now >= nextSlowUpdate then
      for plate in pairs(activePlates) do
        nameplates.OnUpdate(plate, frameState, true)
      end
      nextSlowUpdate = frameState.now + THROTTLE_INTERVAL
    end

    CleanupUnusedCache(frameState.now)
  end)

  -- combat tracker
  nameplates.combat = CreateFrame("Frame")
  nameplates.combat:RegisterEvent("PLAYER_ENTER_COMBAT")
  nameplates.combat:RegisterEvent("PLAYER_LEAVE_COMBAT")
  nameplates.combat:SetScript("OnEvent", function()
    if event == "PLAYER_ENTER_COMBAT" then
      this.inCombat = 1
      if PlayerFrame then PlayerFrame.inCombat = 1 end
    elseif event == "PLAYER_LEAVE_COMBAT" then
      this.inCombat = nil
      if PlayerFrame then PlayerFrame.inCombat = nil end
    end
  end)

  nameplates.OnCreate = function(frame)
    local parent = frame or this
    platecount = platecount + 1
    local platename = "pfNamePlate" .. platecount

    -- create ShaguPlates nameplate overlay
    local nameplate = CreateFrame("Button", platename, parent)
    nameplate.platename = platename
    nameplate:EnableMouse(0)
    nameplate.parent = parent
    nameplate.cache = {}
    nameplate.original = {}

    -- 保存原始姓名板的 FrameLevel（暴雪根据 Y 坐标自动设置，用于前后遮挡）
    nameplate.baseFrameLevel = parent:GetFrameLevel()

    -- Stagger tick to spread updates across frames (0.05s apart per plate)
    nameplate.tick = GetTime() + math.mod(platecount,10) * 0.05

    -- create shortcuts for all known elements and disable them
    nameplate.original.healthbar, nameplate.original.castbar = parent:GetChildren()
    DisableObject(nameplate.original.healthbar)
    DisableObject(nameplate.original.castbar)

    for i, object in pairs({parent:GetRegions()}) do
      if NAMEPLATE_OBJECTORDER[i] and NAMEPLATE_OBJECTORDER[i] == "raidicon" then
        nameplate[NAMEPLATE_OBJECTORDER[i]] = object
      elseif NAMEPLATE_OBJECTORDER[i] then
        nameplate.original[NAMEPLATE_OBJECTORDER[i]] = object
        DisableObject(object)
      else
        DisableObject(object)
      end
    end

    HookScript(nameplate.original.healthbar, "OnValueChanged", nameplates.OnValueChanged)

    -- adjust sizes and scaling of the nameplate
    local scale = tonumber(C.nameplates.scale) or 1
    nameplate:SetScale(UIParent:GetScale() * scale)
    
    -- 使用原始姓名板的 FrameLevel，确保前面的姓名板能挡住后面的
    local baseLevel = nameplate.baseFrameLevel or 0
    -- 确保 baseLevel 至少为 1，避免边框创建时出现负数
    if baseLevel < 1 then baseLevel = 1 end
    nameplate:SetFrameLevel(baseLevel)

    nameplate.health = CreateFrame("StatusBar", nil, nameplate)
    nameplate.health:SetFrameLevel(baseLevel)
    nameplate.health.bg = nameplate.health:CreateTexture(nil, "BACKGROUND")
    nameplate.health.bg:SetAllPoints(nameplate.health)
    nameplate.health.text = nameplate.health:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameplate.health.text:SetAllPoints()
    nameplate.health.text:SetTextColor(1,1,1,1)

    nameplate.name = nameplate:CreateFontString(nil, "OVERLAY")
    local nameoffset = tonumber(C.nameplates.nameoffset) or 0
    nameplate.name:SetPoint("TOP", nameplate, "TOP", 0, nameoffset)

    nameplate.glow = nameplate:CreateTexture(nil, "BACKGROUND")
    nameplate.glow:SetPoint("CENTER", nameplate.health, "CENTER", 0, 0)
    nameplate.glow:SetTexture(ShaguPlatesX.media["img:dot"])
    nameplate.glow:Hide()

    nameplate.guild = nameplate:CreateFontString(nil, "OVERLAY")
    nameplate.guild:SetPoint("BOTTOM", nameplate.health, "BOTTOM", 0, 0)

    -- 文字层：层级高于血条，保证等级文字能覆盖显示在血条之上
    nameplate.textlayer = CreateFrame("Frame", nil, nameplate)
    nameplate.textlayer:SetAllPoints(nameplate)
    nameplate.textlayer:SetFrameLevel(nameplate.health:GetFrameLevel() + 2)

    nameplate.level = nameplate.textlayer:CreateFontString(nil, "OVERLAY")
    nameplate.level:SetPoint("RIGHT", nameplate.health, "LEFT", -3, 0)

    nameplate.raidicon:SetParent(nameplate.health)
    nameplate.raidicon:SetDrawLayer("OVERLAY")
    nameplate.raidicon:SetTexture(ShaguPlatesX.media["img:raidicons"])

    nameplate.totem = CreateFrame("Frame", nil, nameplate)
    nameplate.totem:SetPoint("CENTER", nameplate, "CENTER", 0, 0)
    nameplate.totem:SetHeight(32)
    nameplate.totem:SetWidth(32)
    nameplate.totem.icon = nameplate.totem:CreateTexture(nil, "OVERLAY")
    nameplate.totem.icon:SetTexCoord(.078, .92, .079, .937)
    nameplate.totem.icon:SetAllPoints()
    CreateBackdrop(nameplate.totem)

    -- 自定义精英图标（尺寸和锚点按布局在 OnConfigChange 里设置）
    nameplate.eliteicon = nameplate:CreateTexture(nil, "OVERLAY")
    nameplate.eliteicon:SetDrawLayer("OVERLAY", 7) -- 确保图标在边框上面
    nameplate.eliteicon:Hide()

    -- 任务怪姓名板提示图标（放在名字左边）
    nameplate.questicon = nameplate:CreateTexture(nil, "OVERLAY")
    nameplate.questicon:SetDrawLayer("OVERLAY", 7) -- 确保图标在边框上面
    nameplate.questicon:SetWidth(20)
    nameplate.questicon:SetHeight(20)
    nameplate.questicon:SetPoint("RIGHT", nameplate.name, "LEFT", -2, 0)
    nameplate.questicon:Hide()
    
    -- 目标名字文本（显示敌人正在攻击谁，放在名字右边）
    nameplate.targetname = nameplate:CreateFontString(nil, "OVERLAY")
    nameplate.targetname:SetPoint("LEFT", nameplate.name, "RIGHT", 4, 0)
    nameplate.targetname:SetJustifyH("LEFT")

    do -- debuffs
      nameplate.debuffs = {}
      CreateDebuffIcon(nameplate, 1)
    end

    do -- combopoints
      local _, class = UnitClass("player")
      local combopoints = { }
      if class == "ROGUE" or class == "DRUID" then
        for i = 1, 5 do
          combopoints[i] = CreateFrame("Frame", nil, nameplate)
          combopoints[i]:Hide()
          combopoints[i]:SetFrameLevel(8)
          combopoints[i].tex = combopoints[i]:CreateTexture("OVERLAY")
          combopoints[i].tex:SetAllPoints()

          if i < 3 then
            combopoints[i].tex:SetTexture(1, .3, .3, .75)
          elseif i < 4 then
            combopoints[i].tex:SetTexture(1, 1, .3, .75)
          else
            combopoints[i].tex:SetTexture(.3, 1, .3, .75)
          end
        end
      end
      nameplate.combopoints = combopoints
    end

    do -- castbar
      local castbar = CreateFrame("StatusBar", nil, nameplate.health)
      castbar:Hide()

      castbar:SetScript("OnShow", function()
        if C.nameplates.debuffs["position"] == "BOTTOM" then
          nameplate.debuffs[1]:SetPoint("TOPLEFT", this, "BOTTOMLEFT", 0, -4)
        end
      end)

      castbar:SetScript("OnHide", function()
        if C.nameplates.debuffs["position"] == "BOTTOM" then
          nameplate.debuffs[1]:SetPoint("TOPLEFT", this:GetParent(), "BOTTOMLEFT", 0, -4)
        end
      end)

      -- DragonflightReloaded 风格施法条背景
      castbar.dfrl_bg = castbar:CreateTexture(nil, "BACKGROUND")
      castbar.dfrl_bg:SetAllPoints(castbar)
      castbar.dfrl_bg:SetTexture("Interface\\AddOns\\ShaguPlatesX\\img\\castbar_bg")

      -- 施法时间文本（施法条右下方）
      castbar.text = castbar:CreateFontString("Status", "OVERLAY", "GameFontNormal")
      castbar.text:SetDrawLayer("OVERLAY", 7)
      castbar.text:SetPoint("TOPRIGHT", castbar, "BOTTOMRIGHT", 0, -2)
      castbar.text:SetNonSpaceWrap(false)
      castbar.text:SetTextColor(1,1,1,1)
      castbar.text:SetJustifyH("RIGHT")

      -- 法术名字（施法条左下方）
      castbar.spell = castbar:CreateFontString("Status", "OVERLAY", "GameFontNormal")
      castbar.spell:SetDrawLayer("OVERLAY", 7)
      castbar.spell:SetPoint("TOPLEFT", castbar, "BOTTOMLEFT", 0, -2)
      castbar.spell:SetNonSpaceWrap(false)
      castbar.spell:SetTextColor(1,1,1,1)
      castbar.spell:SetJustifyH("LEFT")

      -- 施法条火花效果
      castbar.spark = castbar:CreateTexture(nil, "OVERLAY")
      castbar.spark:SetTexture("Interface\\AddOns\\ShaguPlatesX\\img\\castbar_spark")
      castbar.spark:SetBlendMode("ADD")
      castbar.spark:SetWidth(20)
      castbar.spark:Hide()

      -- 施法图标（移到左边）
      castbar.icon = CreateFrame("Frame", nil, castbar)
      castbar.icon:SetFrameLevel(castbar:GetFrameLevel() + 2)
      castbar.icon.tex = castbar.icon:CreateTexture(nil, "OVERLAY")
      castbar.icon.tex:SetAllPoints()

      nameplate.castbar = castbar
    end

    parent.nameplate = nameplate
    HookScript(parent, "OnShow", nameplates.OnShow)
    HookScript(parent, "OnHide", nameplates.OnHide)
    parent:SetScript("OnUpdate", nil)  -- Disable Blizzard's OnUpdate, we handle centrally

    nameplates.OnConfigChange(parent)
    nameplates.OnShow(parent)
  end

  nameplates.OnConfigChange = function(frame)
    local parent = frame
    local nameplate = frame.nameplate

    local font = C.nameplates.use_unitfonts == "1" and ShaguPlatesX.font_unit or ShaguPlatesX.font_default
    local font_size = C.nameplates.use_unitfonts == "1" and C.global.font_unit_size or C.global.font_size
    local font_style = C.nameplates.name.fontstyle
    local glowr, glowg, glowb, glowa = GetStringColor(C.nameplates.glowcolor)
    local hlr, hlg, hlb, hla = GetStringColor(C.nameplates.highlightcolor)
    local bgr, bgg, bgb, bga = GetStringColor(C.appearance.border.background)
    local hptexture = ShaguPlatesX.media[C.nameplates.healthtexture]
    local rawborder, default_border = GetBorderSize("nameplates")

    local plate_width = C.nameplates.width + 50
    local plate_height = C.nameplates.heighthealth + font_size + 5
    local plate_height_cast = C.nameplates.heighthealth + font_size + 5 + C.nameplates.heightcast + 5
    local combo_size = 5

    local width = tonumber(C.nameplates.width)
    local debuffsize = tonumber(C.nameplates.debuffsize)
    local healthoffset = tonumber(C.nameplates.health.offset)
    local nameoffset = tonumber(C.nameplates.nameoffset) or 0
    local scale = tonumber(C.nameplates.scale) or 1
    local orientation = C.nameplates.verticalhealth == "1" and "VERTICAL" or "HORIZONTAL"

    local c = combatstate -- load combat state colors
    c.CASTING.r, c.CASTING.g, c.CASTING.b, c.CASTING.a = GetStringColor(C.nameplates.combatcasting)
    c.THREAT.r, c.THREAT.g, c.THREAT.b, c.THREAT.a = GetStringColor(C.nameplates.combatthreat)
    c.NOTHREAT.r, c.NOTHREAT.g, c.NOTHREAT.b, c.NOTHREAT.a = GetStringColor(C.nameplates.combatnothreat)
    c.STUN.r, c.STUN.g, c.STUN.b, c.STUN.a = GetStringColor(C.nameplates.combatstun)

    nameplate:SetScale(UIParent:GetScale() * scale)
    nameplate:SetWidth(plate_width)
    nameplate:SetHeight(plate_height)
    nameplate:SetPoint("TOP", parent, "TOP", 0, 0)

    nameplate.name:SetFont(font, font_size, font_style)

    -- 血条位置（使用 healthoffset 偏移）
    nameplate.health:SetOrientation(orientation)
    nameplate.health:ClearAllPoints()
    nameplate.health:SetPoint("CENTER", nameplate, "CENTER", 0, healthoffset)
    
    nameplate.name:ClearAllPoints()
    if cfg_layoutold then
      -- 旧版布局：名字顶部居中、独立偏移（使用 nameoffset）
      nameplate.name:SetJustifyH("CENTER")
      nameplate.name:SetPoint("TOP", nameplate, "TOP", 0, nameoffset)
    else
      -- 新版布局：名字紧贴血条上方、与血条左对齐
      nameplate.name:SetJustifyH("LEFT")
      nameplate.name:SetPoint("BOTTOMLEFT", nameplate.health, "TOPLEFT", 0, 1 + nameoffset)
    end
    nameplate.health:SetStatusBarTexture(hptexture)
    nameplate.health.bg:SetTexture(hptexture or "Interface\\BUTTONS\\WHITE8X8")
    nameplate.health.bg:SetVertexColor(bgr, bgg, bgb, bga)
    nameplate.health:SetWidth(C.nameplates.width)
    nameplate.health:SetHeight(C.nameplates.heighthealth)
    nameplate.health.hlr, nameplate.health.hlg, nameplate.health.hlb, nameplate.health.hla = hlr, hlg, hlb, hla

    if cfg_oldborder then
      -- 旧版经典边框：纯色 backdrop（宽度/颜色走全局边框配置，战斗中可按战斗状态变色）
      if nameplate.health.backdrop then nameplate.health.backdrop:Hide() end
      if not nameplate.health.borderproxy then
        local proxy = CreateFrame("Frame", nil, nameplate.health)
        proxy:SetAllPoints(nameplate.health)
        nameplate.health.borderproxy = proxy
      end
      nameplate.health.borderproxy:SetFrameLevel(nameplate.health:GetFrameLevel())
      nameplate.health.borderproxy:Show()
      CreateBackdrop(nameplate.health.borderproxy, default_border)
      nameplate.health.bg:Hide()
    else
      -- 新版贴图边框（动态变色），细边框
      if nameplate.health.borderproxy then nameplate.health.borderproxy:Hide() end
      nameplate.health.bg:Show()
      CreateBorder(nameplate.health, 2)

      -- 修复背景 FrameLevel，避免负数
      if nameplate.health.backdrop then
        nameplate.health.backdrop:Show()
        local level = nameplate.health:GetFrameLevel()
        if level < 1 then
          nameplate.health.backdrop:SetFrameLevel(0)
        else
          nameplate.health.backdrop:SetFrameLevel(level - 1)
        end
      end
    end

    nameplate.health.text:ClearAllPoints()
    if cfg_layoutold then
      -- 旧版布局：血量文字铺满整条血条，对齐走 hptextpos 配置
      nameplate.health.text:SetFont(font, font_size - 2, "OUTLINE")
      nameplate.health.text:SetAllPoints()
      nameplate.health.text:SetJustifyH(C.nameplates.hptextpos)
    else
      -- 新版布局：血量文字在血条右端上方，大半覆盖血条
      nameplate.health.text:SetFont(font, font_size, "OUTLINE")
      nameplate.health.text:SetPoint("BOTTOMRIGHT", nameplate.health, "RIGHT", -1, -1)
      nameplate.health.text:SetJustifyH("LEFT")
    end

    nameplate.guild:SetFont(font, font_size, font_style)
    
    -- 目标名字字体设置
    nameplate.targetname:SetFont(font, font_size - 1, "OUTLINE")

    nameplate.glow:SetWidth(C.nameplates.width + 60)
    nameplate.glow:SetHeight(C.nameplates.heighthealth + 30)
    nameplate.glow:SetVertexColor(glowr, glowg, glowb, glowa)

    nameplate.raidicon:ClearAllPoints()
    nameplate.raidicon:SetPoint(C.nameplates.raidiconpos, nameplate.health, C.nameplates.raidiconpos, C.nameplates.raidiconoffx, C.nameplates.raidiconoffy)
    -- 标记图标贴图：开启后换回客户端原版图标（图集布局一致，texcoord 由客户端维护）
    if C.nameplates.raidiconblizz == "1" then
      nameplate.raidicon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    else
      nameplate.raidicon:SetTexture(ShaguPlatesX.media["img:raidicons"])
    end
    nameplate.level:SetFont(font, font_size, font_style)
    nameplate.level:ClearAllPoints()
    nameplate.level:SetJustifyH("LEFT")
    nameplate.eliteicon:ClearAllPoints()
    if cfg_layoutold then
      -- 旧版布局：等级在血条右侧，33px 精英图标在血条左侧
      nameplate.level:SetPoint("LEFT", nameplate.health, "RIGHT", 5, 0)
      nameplate.eliteicon:SetWidth(33)
      nameplate.eliteicon:SetHeight(33)
      nameplate.eliteicon:SetPoint("RIGHT", nameplate.health, "LEFT", 2, 0)
    else
      -- 新版布局：等级在血条左端下方大半覆盖血条，14px 精英小图标在名字右端
      nameplate.level:SetPoint("TOPLEFT", nameplate.health, "LEFT", 2, 2)
      nameplate.eliteicon:SetWidth(14)
      nameplate.eliteicon:SetHeight(14)
      nameplate.eliteicon:SetPoint("LEFT", nameplate.name, "RIGHT", 2, 0)
    end
    UpdateIconScale(nameplate)

    for i=1,16 do
      UpdateDebuffConfig(nameplate, i)
    end

    if nameplate.combopoints[1] then
      for i=1,5 do
        nameplate.combopoints[i]:SetWidth(combo_size)
        nameplate.combopoints[i]:SetHeight(combo_size)
        nameplate.combopoints[i]:SetPoint("TOPRIGHT", nameplate.health, "BOTTOMRIGHT", -(i-1)*(combo_size+default_border*3), -default_border*3)
        CreateBackdrop(nameplate.combopoints[i], default_border)
      end
    end

    nameplate.castbar:SetPoint("TOPLEFT", nameplate.health, "BOTTOMLEFT", 0, -default_border*3)
    nameplate.castbar:SetPoint("TOPRIGHT", nameplate.health, "BOTTOMRIGHT", 0, -default_border*3)
    nameplate.castbar:SetHeight(C.nameplates.heightcast)

    if not cfg_layoutold then
      -- 新版布局施法条：血条纹理 + 黄色 + 边框（经典样式）
      nameplate.castbar:SetStatusBarTexture(hptexture)
      nameplate.castbar:SetStatusBarColor(.9, .8, 0, 1)
      CreateBackdrop(nameplate.castbar, default_border)
      if nameplate.castbar.backdrop then nameplate.castbar.backdrop:Show() end
      nameplate.castbar.dfrl_bg:Hide()
      nameplate.castbar.spark:Hide()

      -- 时间在施法条左侧，半透明白
      nameplate.castbar.text:ClearAllPoints()
      nameplate.castbar.text:SetPoint("RIGHT", nameplate.castbar, "LEFT", -4, 0)
      nameplate.castbar.text:SetDrawLayer("OVERLAY", 7)
      nameplate.castbar.text:SetTextColor(1, 1, 1, .5)

      -- 法术名居中压在施法条上
      nameplate.castbar.spell:ClearAllPoints()
      nameplate.castbar.spell:SetPoint("CENTER", nameplate.castbar, "CENTER")
      nameplate.castbar.spell:SetDrawLayer("OVERLAY", 7)
      nameplate.castbar.spell:SetTextColor(1, 1, 1, 1)

      -- 图标在右侧，跨血条+施法条高度，带边框
      nameplate.castbar.icon:ClearAllPoints()
      nameplate.castbar.icon:SetPoint("BOTTOMLEFT", nameplate.castbar, "BOTTOMRIGHT", default_border*3, 0)
      nameplate.castbar.icon:SetPoint("TOPLEFT", nameplate.health, "TOPRIGHT", default_border*3, 0)
      nameplate.castbar.icon:SetWidth(C.nameplates.heightcast + default_border*3 + C.nameplates.heighthealth)
      nameplate.castbar.icon:SetFrameLevel(nameplate.castbar:GetFrameLevel())
      nameplate.castbar.icon.tex:SetDrawLayer("BORDER")
      CreateBackdrop(nameplate.castbar.icon, default_border)
      if nameplate.castbar.icon.backdrop then nameplate.castbar.icon.backdrop:Show() end
    else
      -- 旧版布局施法条（DragonflightReloaded 风格）
      nameplate.castbar.spark:SetHeight(C.nameplates.heightcast + 10)
      local dfrl_castbar_texture = "Interface\\AddOns\\ShaguPlatesX\\img\\castbar_bar"
      nameplate.castbar:SetStatusBarTexture(dfrl_castbar_texture)
      nameplate.castbar:SetStatusBarColor(1, 1, 1, 1)  -- 使用白色让纹理原色显示
      nameplate.castbar.dfrl_bg:Show()
      if nameplate.castbar.backdrop then nameplate.castbar.backdrop:Hide() end

      -- 时间在施法条右下方
      nameplate.castbar.text:ClearAllPoints()
      nameplate.castbar.text:SetPoint("TOPRIGHT", nameplate.castbar, "BOTTOMRIGHT", 0, -2)
      nameplate.castbar.text:SetDrawLayer("OVERLAY", 7)
      nameplate.castbar.text:SetTextColor(1, 1, 1, 1)

      -- 法术名在施法条左下方
      nameplate.castbar.spell:ClearAllPoints()
      nameplate.castbar.spell:SetPoint("TOPLEFT", nameplate.castbar, "BOTTOMLEFT", 0, -2)
      nameplate.castbar.spell:SetDrawLayer("OVERLAY", 7)
      nameplate.castbar.spell:SetTextColor(1, 1, 1, 1)

      -- 图标在左侧，大小由 casticonsize 配置
      local casticonsize = tonumber(C.nameplates.casticonsize) or (C.nameplates.heightcast + default_border*3 + C.nameplates.heighthealth)
      nameplate.castbar.icon:ClearAllPoints()
      nameplate.castbar.icon:SetPoint("BOTTOMRIGHT", nameplate.castbar, "BOTTOMLEFT", -default_border*3 + 10, 0)
      nameplate.castbar.icon:SetWidth(casticonsize)
      nameplate.castbar.icon:SetHeight(casticonsize)
      nameplate.castbar.icon:SetFrameLevel(nameplate.castbar:GetFrameLevel() + 2)
      nameplate.castbar.icon.tex:SetDrawLayer("OVERLAY")
      if nameplate.castbar.icon.backdrop then nameplate.castbar.icon.backdrop:Hide() end
    end

    nameplate.castbar.text:SetFont(font, font_size, "OUTLINE")
    -- 法术名字体大小可配置(默认14), 新旧样式通用
    -- 取整并限制范围, 避免无效字号导致 SetFont 失败(文字不渲染)
    local castbarspellsize = tonumber(C.nameplates.castbarspellfontsize) or 14
    castbarspellsize = math.floor(castbarspellsize)
    if castbarspellsize <= 0 then castbarspellsize = 14 end
    if castbarspellsize < 6 then castbarspellsize = 6 end
    if castbarspellsize > 32 then castbarspellsize = 32 end
    nameplate.castbar.spell:SetFont(font, castbarspellsize, "OUTLINE")

    nameplate.debuffUpdate = true
    nameplates:OnDataChanged(nameplate)
  end

  nameplates.OnValueChanged = function()
    -- Just sync health bar, don't run full OnDataChanged
    local plate = this:GetParent().nameplate
    if plate and plate.health then
      plate.health:SetMinMaxValues(plate.original.healthbar:GetMinMaxValues())
      plate.health:SetValue(plate.original.healthbar:GetValue())
    end
  end

  -- 边框着色：旧版静态边框染 borderproxy 的 backdrop，新版贴图边框染 bor 贴图
  -- 颜色参数缺省时按边框模式取默认色（旧版跟随全局边框配置色，新版纯黑）
  -- 挂在 nameplates 表上，避免给 OnDataChanged 增加 upvalue（5.0 上限 32）
  nameplates.SetPlateBorderColor = function(plate, r, g, b, a)
    if cfg_oldborder then
      if not r then r, g, b, a = border_er, border_eg, border_eb, border_ea end
      local proxy = plate.health and plate.health.borderproxy
      if proxy and proxy.backdrop then
        proxy.backdrop:SetBackdropBorderColor(r, g, b, a)
      end
    else
      if not r then r, g, b, a = er, eg, eb, ea end
      SetBorderColor(plate.health, r, g, b, a)
    end
  end

  nameplates.OnDataChanged = function(self, plate)
    local visible = plate:IsVisible()
    local hp = plate.original.healthbar:GetValue()
    local hpmin, hpmax = plate.original.healthbar:GetMinMaxValues()
    local name = plate.original.name:GetText()
    local level = plate.original.level:IsShown() and plate.original.level:GetObjectType() == "FontString" and plate.original.level:GetText() or "??"
    local target = plate.istarget
    local mouseover = UnitExists("mouseover") and plate.original.glow:IsShown() or nil
    local unitstr = target and "target" or mouseover and "mouseover" or nil
    local red, green, blue = plate.original.healthbar:GetStatusBarColor()
    local unittype = GetUnitType(red, green, blue) or "ENEMY_NPC"
    local font_size = C.nameplates.use_unitfonts == "1" and C.global.font_unit_size or C.global.font_size

    -- use superwow unit guid as unitstr if possible
    local guid = plate.lastGuid or plate.parent:GetName(1)
    if guid and not unitstr then
      unitstr = guid
    end

    -- cache stable unit data per GUID so periodic updates stay cheap
    local class, player, elite, guild
    if guid then
      local meta = GetGuidMeta(guid, frameState.now > 0 and frameState.now or GetTime())
      if meta then
        class = meta.class or nil
        player = meta.player
        elite = meta.elite or nil
        guild = meta.guild or nil
      end
    end

    if player and unittype == "ENEMY_NPC" then unittype = "ENEMY_PLAYER" end
    elite = plate.original.levelicon:IsShown() and not player and "boss" or elite

    -- skip data updates on invisible frames
    if not visible then return end

    -- target event sometimes fires too quickly, where nameplate identifiers are not
    -- yet updated. So while being inside this event, we cannot trust the unitstr.
    if event == "PLAYER_TARGET_CHANGED" then unitstr = nil end

    -- remove unitstr on unit name mismatch
    if unitstr and UnitName(unitstr) ~= name then unitstr = nil end

    -- use mobhealth values if addon is running
    if (MobHealth3 or MobHealthFrame) and target and name == UnitName('target') and MobHealth_GetTargetCurHP() then
      hp = MobHealth_GetTargetCurHP() > 0 and MobHealth_GetTargetCurHP() or hp
      hpmax = MobHealth_GetTargetMaxHP() > 0 and MobHealth_GetTargetMaxHP() or hpmax
    end

    -- always make sure to keep plate visible
    plate:Show()

    if target and C.nameplates.targetglow == "1" then
      plate.glow:Show() else plate.glow:Hide()
    end

    -- target indicator
    -- 战斗状态边框染色仅在经典边框模式生效（贴图边框为灰底乘算染色，效果太淡）
    if superwow_active and C.nameplates.outcombatstate == "1" and cfg_oldborder then
      -- determine color based on combat state
      local color = GetCombatStateColor(guid or "")
      if not color then color = combatstate.NONE end

      -- set border color
      self.SetPlateBorderColor(plate, color.r, color.g, color.b, color.a)
    elseif target then
      -- 选中时使用白色边框
      self.SetPlateBorderColor(plate, target_er, target_eg, target_eb, target_ea)
    elseif C.nameplates.outfriendlynpc == "1" and unittype == "FRIENDLY_NPC" then
      local c = unitcolors[unittype]; self.SetPlateBorderColor(plate, c[1], c[2], c[3], c[4])
    elseif C.nameplates.outfriendly == "1" and unittype == "FRIENDLY_PLAYER" then
      local c = unitcolors[unittype]; self.SetPlateBorderColor(plate, c[1], c[2], c[3], c[4])
    elseif C.nameplates.outneutral == "1" and strfind(unittype, "NEUTRAL") then
      local c = unitcolors[unittype]; self.SetPlateBorderColor(plate, c[1], c[2], c[3], c[4])
    elseif C.nameplates.outenemy == "1" and strfind(unittype, "ENEMY") then
      local c = unitcolors[unittype]; self.SetPlateBorderColor(plate, c[1], c[2], c[3], c[4])
    else
      -- 默认边框色（新版贴图边框用纯黑，旧版边框跟随全局配置色）
      self.SetPlateBorderColor(plate)
    end

    -- hide frames according to the configuration
    local TotemIcon = TotemPlate(name)
    local hidePlate = HidePlate(unittype, name, (hpmax-hp == hpmin), target)

    if TotemIcon and hidePlate then
      -- create totem icon
      plate.totem.icon:SetTexture("Interface\\Icons\\" .. TotemIcon)

      plate.glow:Hide()
      plate.level:Hide()
      plate.name:Hide()
      SetPlateHealthVisible(plate, nil)
      plate.guild:Hide()
      plate.totem:Show()
    elseif hidePlate then
      plate.name:SetParent(plate)
      plate.guild:SetPoint("BOTTOM", plate.name, "BOTTOM", -2, -(font_size + 2))

      plate.level:Hide()
      plate.name:Show()
      SetPlateHealthVisible(plate, nil)
      if guild and C.nameplates.showguildname == "1" then
        plate.glow:SetPoint("CENTER", plate.name, "CENTER", 0, -(font_size / 2) - 2)
      else
        plate.glow:SetPoint("CENTER", plate.name, "CENTER", 0, 0)
      end
      plate.totem:Hide()
    else
      plate.name:SetParent(plate.health)
      plate.guild:SetPoint("BOTTOM", plate.health, "BOTTOM", 0, -(font_size + 4))

      plate.level:Show()
      plate.name:Show()
      SetPlateHealthVisible(plate, true)
      plate.glow:SetPoint("CENTER", plate.health, "CENTER", 0, 0)
      plate.totem:Hide()
    end

    plate.name:SetText(GetNameString(name))
    -- 精英标识样式: icon=图标, text=等级文字后缀, both=两者, none=不显示
    local elitestyle = C.nameplates.elitestyle or "icon"
    if cfg_layoutold then
      -- 旧版布局：纯等级数字(+精英后缀)
      if elitestyle == "text" or elitestyle == "both" then
        plate.level:SetText(string.format("%s%s", level or "??", (elitestrings[elite] or "")))
      else
        plate.level:SetText(level or "??")
      end
    else
      -- 新版布局：白色 "Lv" 前缀 + 等级数字
      if elitestyle == "text" or elitestyle == "both" then
        plate.level:SetText(string.format("|cffffffffLv|r%s%s", level or "??", (elitestrings[elite] or "")))
      else
        plate.level:SetText("|cffffffffLv|r" .. (level or "??"))
      end
    end
    local levelr, levelg, levelb = plate.original.level:GetTextColor()
    if not cfg_layoutold then
      -- 定制难度色板（红/黄/绿三档重映射，灰色保持原样）；旧版布局保持客户端原色
      if levelr > 0.9 and levelg < 0.6 then
        levelr, levelg, levelb = 0.9569, 0.3412, 0.2275
      elseif levelr > 0.9 and levelg >= 0.6 then
        levelr, levelg, levelb = 1, 0.7843, 0
      elseif levelg > 0.9 and levelr < 0.6 then
        levelr, levelg, levelb = 0.6902, 1, 0
      end
    end
    plate.level:SetTextColor(levelr, levelg, levelb, 1)

    -- 自定义精英图标显示
    if plate.eliteicon then
      -- 图腾、纯文字模式或不显示时,隐藏精英图标
      if TotemIcon or elitestyle == "text" or elitestyle == "none" then
        plate.eliteicon:Hide()
      elseif elite == "elite" or elite == "worldboss" or elite == "boss" then
        -- 精英和世界BOSS：旧版布局用皇冠，新版用金龙图标（取自 pfQuest）
        plate.eliteicon:SetTexture(cfg_layoutold and "Interface\\AddOns\\ShaguPlatesX\\img\\crown_64" or "Interface\\AddOns\\ShaguPlatesX\\img\\JY")
        plate.eliteicon:Show()
      elseif elite == "rare" or elite == "rareelite" then
        -- 稀有和稀有精英：旧版布局用皇冠，新版用银龙图标（取自 pfQuest）
        plate.eliteicon:SetTexture(cfg_layoutold and "Interface\\AddOns\\ShaguPlatesX\\img\\crown_65" or "Interface\\AddOns\\ShaguPlatesX\\img\\YY")
        plate.eliteicon:Show()
      else
        plate.eliteicon:Hide()
      end
    end

    -- 显示目标名字（敌人正在攻击谁）
    if cfg_showtargetname and plate.targetname and unitstr and not UnitIsUnit(unitstr, "player") then
      local targetName = UnitName(unitstr .. "target")
      if targetName then
        -- 如果目标是玩家，显示"你"
        if UnitIsUnit(unitstr .. "target", "player") then
          plate.targetname:SetText(">> 你")
          plate.targetname:SetTextColor(1, 0.2, 0.2)
        else
          plate.targetname:SetText(">> " .. targetName)
          -- 根据职业着色（定制色板）
          local _, class = UnitClass(unitstr .. "target")
          if class and mhtui_classcolors[class] then
            local color = mhtui_classcolors[class]
            plate.targetname:SetTextColor(color[1], color[2], color[3])
          else
            plate.targetname:SetTextColor(1, 1, 0.5)
          end
        end
      else
        plate.targetname:SetText("")
      end
    elseif plate.targetname then
      plate.targetname:SetText("")
    end

    -- 任务怪姓名板提示图标
    if plate.questicon then
      local icon = ResolveQuestUnitIcon(name)
      if icon and icon ~= "0" then
        plate.questicon:SetTexture(icon)
        plate.questicon:Show()
      else
        plate.questicon:Hide()
      end
    end

    if guild and C.nameplates.showguildname == "1" then
      plate.guild:SetText(guild)
      if guild == GetGuildInfo("player") then
        plate.guild:SetTextColor(0, 0.9, 0, 1)
      else
        plate.guild:SetTextColor(0.8, 0.8, 0.8, 1)
      end
      plate.guild:Show()
    else
      plate.guild:Hide()
    end

    -- Health bar - only update when values change
    if plate.cache.hp ~= hp or plate.cache.hpmax ~= hpmax then
      plate.cache.hp = hp
      plate.cache.hpmax = hpmax
      plate.health:SetMinMaxValues(hpmin, hpmax)
      plate.health:SetValue(hp)

      if cfg_showhp then
        local rhp, rhpmax
        if guid and UnitHealthMax then
          rhp = UnitHealth(guid)
          rhpmax = UnitHealthMax(guid)
        elseif hpmax > 100 or (round(hpmax/100*hp) ~= hp) then
          rhp, rhpmax = hp, hpmax
        end

        if rhp and rhpmax then
          local setting = C.nameplates.hptextformat
          -- 百分比不带 % 号
          local pct = ceil(hp/hpmax*100)
          if setting == "curperc" then
            plate.health.text:SetText(Abbreviate(rhp).." | "..pct)
          elseif setting == "cur" then
            plate.health.text:SetText(Abbreviate(rhp))
          elseif setting == "curmax" then
            plate.health.text:SetText(Abbreviate(rhp).." - "..Abbreviate(rhpmax))
          elseif setting == "curmaxs" then
            plate.health.text:SetText(Abbreviate(rhp).." / "..Abbreviate(rhpmax))
          elseif setting == "curmaxperc" then
            plate.health.text:SetText(Abbreviate(rhp).." - "..Abbreviate(rhpmax).." | "..pct)
          elseif setting == "curmaxpercs" then
            plate.health.text:SetText(Abbreviate(rhp).." / "..Abbreviate(rhpmax).." | "..pct)
          elseif setting == "deficit" then
            plate.health.text:SetText("-"..Abbreviate(rhpmax - rhp))
          else
            plate.health.text:SetText(pct)
          end
        else
          plate.health.text:SetText(ceil(hp/hpmax*100))
        end
      end
    end

    local r, g, b, a
    local c = unitcolors[unittype]
    if c then r, g, b, a = c[1], c[2], c[3], c[4] else r, g, b, a = 1, 1, 1, 1 end

    -- 玩家职业色使用定制色板
    if unittype == "ENEMY_PLAYER" and C.nameplates["enemyclassc"] == "1" and class and mhtui_classcolors[class] then
      r, g, b, a = mhtui_classcolors[class][1], mhtui_classcolors[class][2], mhtui_classcolors[class][3], 1
    elseif unittype == "FRIENDLY_PLAYER" and C.nameplates["friendclassc"] == "1" and class and mhtui_classcolors[class] then
      r, g, b, a = mhtui_classcolors[class][1], mhtui_classcolors[class][2], mhtui_classcolors[class][3], 1
    end

    if superwow_active and unitstr and UnitIsTapped(unitstr) and not UnitIsTappedByPlayer(unitstr) then
      r, g, b, a = .5, .5, .5, .8
    end

    if superwow_active and C.nameplates.barcombatstate == "1" then
      local color = GetCombatStateColor(guid or "")

      if color then
        r, g, b, a = color.r, color.g, color.b, color.a
      end
    end

    if r ~= plate.cache.r or g ~= plate.cache.g or b ~= plate.cache.b then
      plate.health:SetStatusBarColor(r, g, b, a)
      plate.cache.r, plate.cache.g, plate.cache.b = r, g, b
    end

    if r + g + b ~= plate.cache.namecolor and unittype == "FRIENDLY_PLAYER" and C.nameplates["friendclassnamec"] == "1" and class and mhtui_classcolors[class] then
      plate.name:SetTextColor(r, g, b, a)
      plate.cache.namecolor = r + g + b
    end

    -- update combopoints
    if plate.combopoints[1] then
      for i=1, 5 do plate.combopoints[i]:Hide() end
      if target and C.nameplates.cpdisplay == "1" then
        for i=1, GetComboPoints("target") do plate.combopoints[i]:Show() end
      end
    end

    -- update debuffs only when the aura list changed
    local index = 1
    local scanDebuffs = cfg_showdebuffs and guid and (plate.debuffUpdate or plate.lastDebuffGuid ~= guid)

    if scanDebuffs then
      plate.lastDebuffGuid = guid

      for i = 1, 16 do
        local showDebuff, texture, stacks, spellID, effect, duration, timeleft = GetVisibleDebuff(guid, i)
        if showDebuff == nil then break end

        if showDebuff and effect and DebuffFilter(effect) then
          local debuff = plate.debuffs[index]
          if not debuff then
            CreateDebuffIcon(plate, index)
            UpdateDebuffConfig(plate, index)
            debuff = plate.debuffs[index]
          end

          -- Only update texture if changed
          if debuff.lastTexture ~= texture then
            debuff.lastTexture = texture
            debuff.icon:SetTexture(texture)
            debuff.icon:SetTexCoord(.078, .92, .079, .937)
          end

          -- Only show if not already shown
          if not debuff.isShown then
            debuff.isShown = true
            debuff:Show()
          end

          -- Stacks - only update when changed
          local showStacks = stacks and stacks > 1
          if debuff.lastStacks ~= stacks then
            debuff.lastStacks = stacks
            if showStacks then
              debuff.stacks:SetText(stacks)
              debuff.stacks:Show()
            else
              debuff.stacks:Hide()
            end
          end

          -- Duration - only set timer when spell changes
          if debuffdurations then
            -- Ensure cache exists (handles race condition where UNIT_AURA fired before plate was registered)
            if not debuffCache[guid] then debuffCache[guid] = {} end
            if not debuffCache[guid][spellID] then
              local spellName = SpellInfo(spellID)
              local estimatedDuration = L["debuffs"][spellName] and L["debuffs"][spellName][0] or nil
              debuffCache[guid][spellID] = { start = GetTime(), duration = estimatedDuration }
            end

            local cache = debuffCache[guid][spellID]
            if cache.duration and cache.start and debuff.lastCdSpell ~= spellID then
              debuff.lastCdSpell = spellID
              debuff.lastCdStart = cache.start
              debuff.lastCdDuration = cache.duration
              debuff.cd:SetAlpha(0)
              debuff.cd:Show()
              CooldownFrame_SetTimer(debuff.cd, cache.start, cache.duration, 1)
            elseif (not cache.duration or not cache.start) and debuff.lastCdSpell then
              debuff.lastCdSpell = nil
              debuff.lastCdStart = nil
              debuff.lastCdDuration = nil
              debuff.cd:Hide()
            end
          end

          index = index + 1
        end
      end

      for i = index, 16 do
        ResetDebuffIcon(plate.debuffs[i])
      end

      plate.debuffUpdate = nil
    else
      if not cfg_showdebuffs or not guid then
        plate.lastDebuffGuid = nil
        plate.debuffUpdate = nil
        for i = 1, 16 do
          ResetDebuffIcon(plate.debuffs[i])
        end
      end
    end
  end

  nameplates.OnShow = function(frame)
    local frame = frame or this
    local nameplate = frame.nameplate
    local now = frameState.now > 0 and frameState.now or GetTime()

    activePlates[frame] = true
    nameplate.lastAlpha = nil
    nameplate.debuffUpdate = true

    -- SuperWoW: Register plate in GUID registry for O(1) lookups
    local guid = frame:GetName(1)
    if guid then
      -- Clear old GUID mapping if plate was reused (but keep debuff cache - it's keyed by GUID globally)
      if nameplate.lastGuid and nameplate.lastGuid ~= guid then
        guidRegistry[nameplate.lastGuid] = nil
      end
      guidRegistry[guid] = frame
      nameplate.lastGuid = guid
      TouchGuid(guid, now)

      if castEvents[guid] then
        fastUpdatePlates[frame] = true
      end
    end

    nameplates:OnDataChanged(nameplate)
  end

  nameplates.OnHide = function(frame)
    local frame = frame or this
    local nameplate = frame.nameplate
    local now = frameState.now > 0 and frameState.now or GetTime()

    if not nameplate then return end

    activePlates[frame] = nil
    fastUpdatePlates[frame] = nil

    local guid = nameplate.lastGuid
    if guid and guidRegistry[guid] == frame then
      guidRegistry[guid] = nil
      TouchGuid(guid, now)
    end

    if nameplate.castbar then
      nameplate.castbar.isShown = nil
      nameplate.castbar.lastCastStart = nil
      nameplate.castbar.lastSpell = nil
      nameplate.castbar.lastTime = nil
      if nameplate.castbar.spark then
        nameplate.castbar.spark:Hide()
      end
      nameplate.castbar:Hide()
    end

    nameplate.health.zoomTransition = nil
    nameplate.health.zoomed = nil
    nameplate.health:SetWidth(cfg_width)
    nameplate.health:SetHeight(cfg_heighthealth)
    nameplate.lastRaidIconSize = nil
    nameplate.debuffUpdate = nil
    nameplate.lastDebuffGuid = nil
    for i = 1, 16 do
      ResetDebuffIcon(nameplate.debuffs[i])
    end
    UpdateIconScale(nameplate)
  end

  nameplates.OnUpdate = function(frame, state, slowOnly)
    local nameplate = frame.nameplate
    local original = nameplate.original
    local health = nameplate.health
    local now = state.now
    local guid = nameplate.lastGuid
    local castData = guid and castEvents[guid]
    local needsFastUpdate = nil

    if guid then
      TouchGuid(guid, now)
    end

    -- 同步原始姓名板的 FrameLevel（只在改变时更新，开销很小）
    local currentLevel = frame:GetFrameLevel()
    if nameplate.lastFrameLevel ~= currentLevel then
      nameplate.lastFrameLevel = currentLevel
      nameplate:SetFrameLevel(currentLevel)
      health:SetFrameLevel(currentLevel)
      -- 边框框架会自动继承正确的层级，不需要手动设置
    end

    -- Target detection via GUID comparison (stable, no flicker)
    local target = state.hasTarget and guid and guid == state.targetGuid or nil
    local mouseover = state.hasMouseover and original.glow:IsShown() or nil
    local previousTarget = nameplate.istarget

    -- Alpha - only set when changed (uses stable GUID-based target detection)
    local wantAlpha = (target or not state.hasTarget) and 1 or cfg_notargalpha
    if nameplate.lastAlpha ~= wantAlpha then
      nameplate.lastAlpha = wantAlpha
      nameplate:SetAlpha(wantAlpha)
    end

    -- Castbar - only update when actively casting for smooth animation
    local castbar = nameplate.castbar
    local showCast = cfg_showcastbar and (not cfg_targetcastbar or target)
    local castInfo = showCast and castData

    if castInfo and castInfo.spellID and castInfo.endTime and now < castInfo.endTime and castInfo.event ~= "CAST" and castInfo.event ~= "FAIL" then
      needsFastUpdate = true
      -- Only set min/max when cast changes (use 0-based range for smooth StatusBar rendering)
      if castbar.lastCastStart ~= castInfo.startTime then
        castbar.lastCastStart = castInfo.startTime
        castbar:SetMinMaxValues(0, castInfo.endTime - castInfo.startTime)
      end

      -- Value must update for smooth animation (0-based for precision)
      if castInfo.event == "CHANNEL" then
        castbar:SetValue(castInfo.endTime - now)
      else
        castbar:SetValue(now - castInfo.startTime)
      end

      -- 更新火花位置（经典黄色施法条无火花，仅 DF 风格施法条更新）
      if castbar.spark and cfg_layoutold then
        local progress = (now - castInfo.startTime) / (castInfo.endTime - castInfo.startTime)
        if castInfo.event == "CHANNEL" then
          progress = 1 - progress
        end
        if progress > 0 and progress < 1 then
          -- 使用血条的实际宽度（施法条锚定到血条，宽度相同）
          local sparkPos = (health:GetWidth() or cfg_width or 100) * progress
          castbar.spark:ClearAllPoints()
          castbar.spark:SetPoint("CENTER", castbar, "LEFT", sparkPos, 0)
          castbar.spark:Show()
        else
          castbar.spark:Hide()
        end
      end

      -- Text/icon only when changed
      local timeLeft = floor((castInfo.endTime - now) * 10)
      if castbar.lastTime ~= timeLeft then
        castbar.lastTime = timeLeft
        castbar.text:SetText(string.format("%.1f", timeLeft / 10))
      end

      if castbar.lastSpell ~= castInfo.spellID then
        castbar.lastSpell = castInfo.spellID
        castbar.spell:SetText(cfg_spellname and castInfo.spellName or "")
        if castInfo.icon then
          castbar.icon.tex:SetTexture(castInfo.icon)
          castbar.icon.tex:SetTexCoord(.1,.9,.1,.9)
        end
      end

      -- Show only when needed
      if not castbar.isShown then
        castbar.isShown = true
        castbar:Show()
      end
    else
      -- Hide cast info and bar
      if castInfo and castInfo.spellID and (
        castInfo.event == "CAST" or castInfo.event == "FAIL" or
        (castInfo.endTime and now >= castInfo.endTime)
      ) then
        wipe(castInfo)
      end
      if castbar.isShown then
        castbar.isShown = nil
        castbar.lastCastStart = nil
        castbar.lastSpell = nil
        castbar.lastTime = nil
        if castbar.spark then castbar.spark:Hide() end
        castbar:Hide()
      end
    end

    if target and cfg_targetzoom then
      local wc = cfg_width * cfg_zoomval
      local hc = cfg_heighthealth * (cfg_zoomval * .9)

      if cfg_zoominstant then
        if not health.zoomed or health.zoomTransition then
          health:SetWidth(wc)
          health:SetHeight(hc)
          health.zoomTransition = nil
          health.zoomed = true
        end
      else
        local w, h = health:GetWidth(), health:GetHeight()
        local animation = nil

        if wc >= w then
          health:SetWidth(w * 1.05)
          animation = true
        end

        if hc >= h then
          health:SetHeight(h * 1.05)
          animation = true
        end

        if animation then
          health.zoomTransition = true
          needsFastUpdate = true
        elseif not health.zoomed or health.zoomTransition then
          health:SetWidth(wc)
          health:SetHeight(hc)
          health.zoomTransition = nil
          health.zoomed = true
        end
      end
    elseif health.zoomed or health.zoomTransition then
      if cfg_zoominstant then
        health:SetWidth(cfg_width)
        health:SetHeight(cfg_heighthealth)
        health.zoomTransition = nil
        health.zoomed = nil
      else
        local w, h = health:GetWidth(), health:GetHeight()
        local animation = nil

        if cfg_width <= w then
          health:SetWidth(w * .95)
          animation = true
        end

        if cfg_heighthealth <= h then
          health:SetHeight(h * .95)
          animation = true
        end

        if animation then
          health.zoomTransition = true
          needsFastUpdate = true
        else
          health:SetWidth(cfg_width)
          health:SetHeight(cfg_heighthealth)
          health.zoomTransition = nil
          health.zoomed = nil
        end
      end
    end

    UpdateIconScale(nameplate)

    if needsFastUpdate then
      fastUpdatePlates[frame] = true
    else
      fastUpdatePlates[frame] = nil
    end

    if not slowOnly then
      return
    end

    nameplate.istarget = target

    local update
    if nameplate.auraUpdate or nameplate.targetUpdate or nameplate.castUpdate or nameplate.comboUpdate then
      update = true
      nameplate.auraUpdate = nil
      nameplate.targetUpdate = nil
      nameplate.castUpdate = nil
      nameplate.comboUpdate = nil
    end

    if previousTarget ~= target then
      nameplate.target_strata = nil
    end

    if target and nameplate.target_strata ~= 1 then
      nameplate:SetFrameStrata("LOW")
      nameplate.target_strata = 1
    elseif not target and nameplate.target_strata ~= 0 then
      nameplate:SetFrameStrata("BACKGROUND")
      nameplate.target_strata = 0
    end

    if nameplate.cache.target ~= target then
      nameplate.cache.target = target
      update = true
    end

    if nameplate.cache.mouseover ~= mouseover then
      nameplate.cache.mouseover = mouseover
      update = true
    end

    local r, g, b = original.name:GetTextColor()
    if r + g + b ~= nameplate.cache.namecolor then
      nameplate.cache.namecolor = r + g + b

      if cfg_namefightcolor then
        if r > .9 and g < .2 and b < .2 then
          nameplate.name:SetTextColor(1,0.4,0.2,1)
        else
          nameplate.name:SetTextColor(r,g,b,1)
        end
      else
        nameplate.name:SetTextColor(1,1,1,1)
      end
      update = true
    end

    if not nameplate.tick or nameplate.tick < now then
      update = true
    end

    if update then
      nameplates:OnDataChanged(nameplate)
      nameplate.tick = now + .5
    end

  end

  -- set nameplate game settings
  nameplates.SetGameVariables = function()
    local forceHide = C.nameplates["disableincity"] == "1" and inCity

    -- update visibility (hostile)
    if not forceHide and C.nameplates["showhostile"] == "1" then
      _G.NAMEPLATES_ON = true
      ShowNameplates()
    else
      _G.NAMEPLATES_ON = nil
      HideNameplates()
    end

    -- update visibility (friendly)
    if not forceHide and C.nameplates["showfriendly"] == "1" then
      _G.FRIENDNAMEPLATES_ON = true
      ShowFriendNameplates()
    else
      _G.FRIENDNAMEPLATES_ON = nil
      HideFriendNameplates()
    end
  end

  nameplates:SetGameVariables()

  nameplates.UpdateConfig = function()
    -- update cached config values
    RegisterOwnDebuffEvents(nameplates)
    CacheConfig()

    -- update debuff filters
    DebuffFilterPopulate()

    wipe(name_cache)
    wipe(totem_cache)
    wipe(critter_cache)

    -- recompute city state in case locale/zone changed
    inCity = cityZones[GetZoneText()] and true or false
    cityChecked = true

    -- update nameplate visibility
    nameplates:SetGameVariables()

    -- apply all config changes
    for plate in pairs(registry) do
      plate.nameplate.lastAlpha = nil  -- force alpha recalculation
      nameplates.OnConfigChange(plate)
    end
  end

  if ShaguPlatesX.client <= 11200 then
    -- handle vanilla only settings
    -- due to the secured lua api, those settings can't be applied to TBC and later.
    local hookOnConfigChange = nameplates.OnConfigChange
    nameplates.OnConfigChange = function(self)
      hookOnConfigChange(self)

      local parent = self
      local nameplate = self.nameplate
      local plate = (C.nameplates["overlap"] == "1" or C.nameplates["vertical_offset"] ~= "0") and nameplate or parent

      -- disable all clicks for now
      parent:EnableMouse(false)
      nameplate:EnableMouse(false)

      -- adjust vertical offset
      if C.nameplates["vertical_offset"] ~= "0" then
        nameplate:SetPoint("TOP", parent, "TOP", 0, tonumber(C.nameplates["vertical_offset"]))
      end

      -- replace clickhandler
      if C.nameplates["overlap"] == "1" or C.nameplates["vertical_offset"] ~= "0" then
        plate:SetScript("OnClick", function() parent:Click() end)
      end

      -- enable mouselook on rightbutton down
      if C.nameplates["rightclick"] == "1" then
        plate:SetScript("OnMouseDown", nameplates.mouselook.OnMouseDown)
      else
        plate:SetScript("OnMouseDown", nil)
      end
    end

    local hookOnDataChanged = nameplates.OnDataChanged
    nameplates.OnDataChanged = function(self, nameplate)
      hookOnDataChanged(self, nameplate)

      -- make sure to keep mouse events disabled on parent nameplate
      if (C.nameplates["overlap"] == "1" or C.nameplates["vertical_offset"] ~= "0") then
        nameplate.parent:EnableMouse(false)
      end
    end

    local hookOnUpdate = nameplates.OnUpdate
    nameplates.OnUpdate = function(frame, state, slowOnly)
      -- initialize shortcut variables
      local plate = (C.nameplates["overlap"] == "1" or C.nameplates["vertical_offset"] ~= "0") and frame.nameplate or frame
      if slowOnly then
        local clickable = C.nameplates["clickthrough"] ~= "1" and true or false

        -- disable all click events
        if not clickable then
          frame:EnableMouse(false)
          frame.nameplate:EnableMouse(false)
        else
          plate:EnableMouse(clickable)
        end

        if C.nameplates["overlap"] == "1" then
          if frame:GetWidth() > 1 then
            -- set parent to 1 pixel to have them overlap each other
            frame:SetWidth(1)
            frame:SetHeight(1)
          end
        else
          local scale = tonumber(C.nameplates.scale) or 1
          local effectiveScale = UIParent:GetScale() * scale
          local targetWidth = floor(frame.nameplate:GetWidth() * effectiveScale)

          if not frame.nameplate.dwidth then
            -- cache initial sizing value for comparison
            frame.nameplate.dwidth = targetWidth
          end

          if floor(frame:GetWidth()) ~= targetWidth then
            -- align parent plate to the actual size (respecting custom scale)
            frame:SetWidth(frame.nameplate:GetWidth() * effectiveScale)
            frame:SetHeight(frame.nameplate:GetHeight() * effectiveScale)
            frame.nameplate.dwidth = targetWidth
          end
        end
      end

      -- disable click events while spell is targeting
      local mouseEnabled = frame.nameplate:IsMouseEnabled()
      if C.nameplates["clickthrough"] == "0" and C.nameplates["overlap"] == "1" and SpellIsTargeting() == mouseEnabled then
        frame.nameplate:EnableMouse(not mouseEnabled)
      end

      hookOnUpdate(frame, state, slowOnly)
    end

    -- enable mouselook on rightbutton down
    nameplates.mouselook = CreateFrame("Frame", nil, UIParent)
    nameplates.mouselook.time = nil
    nameplates.mouselook.frame = nil
    nameplates.mouselook.OnMouseDown = function()
      if arg1 and arg1 == "RightButton" then
        MouselookStart()

        -- start detection of the rightclick emulation
        nameplates.mouselook.time = GetTime()
        nameplates.mouselook.frame = this
        nameplates.mouselook:Show()
      end
    end

    nameplates.mouselook:SetScript("OnUpdate", function()
      -- break here if nothing to do
      if not this.time or not this.frame then
        this:Hide()
        return
      end

      -- if threshold is reached (0.5 second) no click action will follow
      if not IsMouselooking() and this.time + tonumber(C.nameplates["clickthreshold"]) < GetTime() then
        this:Hide()
        return
      end

      -- run a usual nameplate rightclick action
      if not IsMouselooking() then
        this.frame:Click("LeftButton")
        if UnitCanAttack("player", "target") and not nameplates.combat.inCombat then AttackTarget() end
        this:Hide()
        return
      end
    end)
  end

  ShaguPlatesX.nameplates = nameplates
end)
