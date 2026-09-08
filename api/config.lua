-- load ShaguPlates environment
setfenv(1, ShaguPlatesX:GetEnvironment())

function ShaguPlatesX:UpdateConfig(group, subgroup, entry, value)
  -- create empty config if not existing
  if not ShaguPlatesX_config then
    _G.ShaguPlatesX_config = {}
  end

  -- check for missing config groups
  if not ShaguPlatesX_config[group] then
    ShaguPlatesX_config[group] = {}
  end

  -- update config
  if not subgroup and entry and value and not ShaguPlatesX_config[group][entry] then
    ShaguPlatesX_config[group][entry] = value
  end

  -- check for missing config subgroups
  if subgroup and not ShaguPlatesX_config[group][subgroup] then
    ShaguPlatesX_config[group][subgroup] = {}
  end

  -- update config in subgroup
  if subgroup and entry and value and not ShaguPlatesX_config[group][subgroup][entry] then
    ShaguPlatesX_config[group][subgroup][entry] = value
  end
end

function ShaguPlatesX:LoadConfig()
  --                MODULE        SUBGROUP       ENTRY               VALUE
  -- ========== 全局配置 ==========
  ShaguPlatesX:UpdateConfig("global",     nil,           "language",         GetLocale())  -- 语言
  ShaguPlatesX:UpdateConfig("global",     nil,           "profile",          "default")    -- 配置文件
  ShaguPlatesX:UpdateConfig("global",     nil,           "pixelperfect",     "0")          -- 像素完美
  ShaguPlatesX:UpdateConfig("global",     nil,           "offscreen",        "0")          -- 屏幕外渲染

  -- 字体设置
  ShaguPlatesX:UpdateConfig("global",     nil,           "font_blizzard",    "0")          -- 使用暴雪字体
  ShaguPlatesX:UpdateConfig("global",     nil,           "font_default", "Fonts\\FRIZQT__.TTF")  -- 默认字体
  ShaguPlatesX:UpdateConfig("global",     nil,           "font_size",        "14")        -- 字体大小
  ShaguPlatesX:UpdateConfig("global",     nil,           "font_unit", "Fonts\\FRIZQT__.TTF")     -- 单位框架字体
  ShaguPlatesX:UpdateConfig("global",     nil,           "font_unit_size",   "14")         -- 单位框架字体大小
  ShaguPlatesX:UpdateConfig("global",     nil,           "font_unit_style",  "OUTLINE")    -- 单位框架字体样式
  ShaguPlatesX:UpdateConfig("global",     nil,           "font_unit_name",   ShaguPlatesX.path.."\\fonts\\Myriad-Pro.ttf")  -- 单位名字字体
  ShaguPlatesX:UpdateConfig("global",     nil,           "font_combat",      ShaguPlatesX.path.."\\fonts\\Continuum.ttf")   -- 战斗字体

  -- 其他全局设置
  ShaguPlatesX:UpdateConfig("global",     nil,           "force_region",     "1")          -- 强制区域设置
  ShaguPlatesX:UpdateConfig("global",     nil,           "errors",           "1")          -- 显示错误
  ShaguPlatesX:UpdateConfig("global",     nil,           "twentyfour",       "1")          -- 24小时制
  ShaguPlatesX:UpdateConfig("global",     nil,           "servertime",       "0")          -- 服务器时间
  ShaguPlatesX:UpdateConfig("global",     nil,           "override_shagutweaks_nameplates", "1")  -- 覆盖ShaguTweaks姓名板
  ShaguPlatesX:UpdateConfig("global",     nil,           "override_shagutweaks_targetlibs", "1")  -- 覆盖ShaguTweaks目标库
  ShaguPlatesX:UpdateConfig("global",     nil,           "override_superapi_castlib", "1")        -- 覆盖SuperAPI施法库

  -- ========== 界面配置 ==========
  ShaguPlatesX:UpdateConfig("gui",        nil,           "reloadmarker",     "0")          -- 重载标记
  ShaguPlatesX:UpdateConfig("gui",        nil,           "showdisabled",     "0")          -- 显示禁用项

  -- ========== 单位框架配置 ==========
  ShaguPlatesX:UpdateConfig("unitframes", nil,           "pastel",           "1")          -- 柔和颜色
  ShaguPlatesX:UpdateConfig("unitframes", nil,           "manacolor",        ".5,.5,1,1")  -- 法力颜色
  ShaguPlatesX:UpdateConfig("unitframes", nil,           "animation_speed",  "5")          -- 动画速度
  ShaguPlatesX:UpdateConfig("unitframes", nil,           "druidmanabar",     "1")          -- 德鲁伊法力条
  ShaguPlatesX:UpdateConfig("unitframes", nil,           "druidmanaheight",  "2")          -- 德鲁伊法力条高度
  ShaguPlatesX:UpdateConfig("unitframes", nil,           "druidmanatext",    "0")          -- 德鲁伊法力文字
  ShaguPlatesX:UpdateConfig("unitframes", nil,           "abbrevnum",        "1")          -- 缩写数字
  ShaguPlatesX:UpdateConfig("unitframes", nil,           "abbrevname",       "1")          -- 缩写名字

  -- ========== 聊天配置 ==========
  ShaguPlatesX:UpdateConfig("chat",       "text",        "bracket",          "[]")         -- 括号样式

  -- ========== 外观配置 ==========
  -- 边框设置
  ShaguPlatesX:UpdateConfig("appearance", "border",      "background",       "0,0,0,1")    -- 背景颜色
  ShaguPlatesX:UpdateConfig("appearance", "border",      "color",            "0.2,0.2,0.2,1")  -- 边框颜色
  ShaguPlatesX:UpdateConfig("appearance", "border",      "shadow",           "0")          -- 阴影
  ShaguPlatesX:UpdateConfig("appearance", "border",      "shadow_intensity", ".35")        -- 阴影强度
  ShaguPlatesX:UpdateConfig("appearance", "border",      "pixelperfect",     "1")          -- 像素完美
  ShaguPlatesX:UpdateConfig("appearance", "border",      "force_blizz", "1")               -- 强制暴雪样式
  ShaguPlatesX:UpdateConfig("appearance", "border",      "hidpi",            "1")          -- 高DPI
  ShaguPlatesX:UpdateConfig("appearance", "border",      "default",          "3")          -- 默认边框大小
  ShaguPlatesX:UpdateConfig("appearance", "border",      "nameplates",       "2")          -- 姓名板边框大小
  ShaguPlatesX:UpdateConfig("appearance", "border",      "actionbars",       "-1")         -- 动作条边框(-1=使用默认)
  ShaguPlatesX:UpdateConfig("appearance", "border",      "unitframes",       "-1")         -- 单位框架边框
  ShaguPlatesX:UpdateConfig("appearance", "border",      "panels",           "-1")         -- 面板边框
  ShaguPlatesX:UpdateConfig("appearance", "border",      "chat",             "-1")         -- 聊天边框
  ShaguPlatesX:UpdateConfig("appearance", "border",      "bags",             "-1")         -- 背包边框
  
  -- 冷却计时器设置
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "lowcolor",         "1,.2,.2,1")  -- 低于阈值颜色(红色)
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "normalcolor",      "1,1,1,1")    -- 正常颜色(白色)
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "minutecolor",      ".2,1,1,1")   -- 分钟颜色(青色)
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "hourcolor",        ".2,.5,1,1")  -- 小时颜色(蓝色)
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "daycolor",         ".2,.2,1,1")  -- 天数颜色(深蓝)
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "threshold",        "2")          -- 阈值(秒)
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "font_size",        "12")         -- 字体大小
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "font_size_blizz",  "12")         -- 暴雪字体大小
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "font_size_foreign","12")         -- 外部字体大小
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "debuffs",          "1")          -- Debuff冷却
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "blizzard",         "0")          -- 暴雪冷却
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "foreign",          "0")          -- 外部冷却
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "milliseconds",     "1")          -- 显示毫秒
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "hideanim",         "0")          -- 隐藏动画
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "font",             ShaguPlatesX.path.."\\fonts\\BigNoodleTitling.ttf")  -- 冷却字体
  ShaguPlatesX:UpdateConfig("appearance", "cd",          "dynamicsize",      "1")          -- 动态大小
  
  -- 其他外观设置
  ShaguPlatesX:UpdateConfig("appearance", "castbar",     "texture",          ShaguPlatesX.path.."\\img\\bar")  -- 施法条纹理
  ShaguPlatesX:UpdateConfig("appearance", "infight",     "screen",           "0")          -- 战斗中屏幕效果
  ShaguPlatesX:UpdateConfig("appearance", "infight",     "aggro",            "0")          -- 仇恨效果
  ShaguPlatesX:UpdateConfig("appearance", "infight",     "health",           "1")          -- 血量效果
  ShaguPlatesX:UpdateConfig("appearance", "infight",     "intensity",           "16")      -- 效果强度
  ShaguPlatesX:UpdateConfig("appearance", "bags",        "movable",          "0")          -- 背包可移动
  ShaguPlatesX:UpdateConfig("appearance", "bags",        "icon_size",        "-1")         -- 背包图标大小
  ShaguPlatesX:UpdateConfig("appearance", "minimap",     "size",            "140")         -- 小地图大小
  ShaguPlatesX:UpdateConfig("appearance", "minimap",     "coordsloc",        "bottomleft") -- 坐标位置

  -- ========== 提示框配置 ==========
  ShaguPlatesX:UpdateConfig("tooltip",     nil,          "font_tooltip",     ShaguPlatesX.path.."\\fonts\\Myriad-Pro.ttf")  -- 提示框字体

  -- ========== 动作条配置 ==========
  -- 启用的动作条
  ShaguPlatesX:UpdateConfig("bars",       "bar1",        "enable",           "1")          -- 主动作条
  ShaguPlatesX:UpdateConfig("bars",       "bar3",        "enable",           "1")          -- 右侧动作条1
  ShaguPlatesX:UpdateConfig("bars",       "bar4",        "enable",           "1")          -- 右侧动作条2
  ShaguPlatesX:UpdateConfig("bars",       "bar5",        "enable",           "1")          -- 底部左侧
  ShaguPlatesX:UpdateConfig("bars",       "bar6",        "enable",           "1")          -- 底部右侧
  ShaguPlatesX:UpdateConfig("bars",       "bar11",       "enable",           "1")          -- 宠物动作条
  ShaguPlatesX:UpdateConfig("bars",       "bar12",       "enable",           "1")          -- 姿态/图腾条

  -- 动作条布局
  ShaguPlatesX:UpdateConfig("bars",       "bar3",        "formfactor",       "6 x 2")      -- 6列2行
  ShaguPlatesX:UpdateConfig("bars",       "bar5",        "formfactor",       "6 x 2")      -- 6列2行
  ShaguPlatesX:UpdateConfig("bars",       "bar4",        "formfactor",       "1 x 12")     -- 1列12行
  ShaguPlatesX:UpdateConfig("bars",       "bar11",       "formfactor",       "10 x 1")     -- 10列1行
  ShaguPlatesX:UpdateConfig("bars",       "bar12",       "formfactor",       "10 x 1")     -- 10列1行

  -- 图标大小
  ShaguPlatesX:UpdateConfig("bars",       "bar11",       "icon_size",        "18")         -- 宠物图标大小
  ShaguPlatesX:UpdateConfig("bars",       "bar12",       "icon_size",        "18")         -- 姿态图标大小

  -- 所有动作条的默认设置
  for i=1,12 do
    ShaguPlatesX:UpdateConfig("bars",     "bar"..i,      "enable",           "0")          -- 启用
    ShaguPlatesX:UpdateConfig("bars",     "bar"..i,      "icon_size",        "20")         -- 图标大小
    ShaguPlatesX:UpdateConfig("bars",     "bar"..i,      "spacing",          "1")          -- 间距
    ShaguPlatesX:UpdateConfig("bars",     "bar"..i,      "formfactor",       "12 x 1")     -- 布局
    ShaguPlatesX:UpdateConfig("bars",     "bar"..i,      "background",       "1")          -- 背景
    ShaguPlatesX:UpdateConfig("bars",     "bar"..i,      "autohide",         "0")          -- 自动隐藏
    if i ~= 11 and i ~= 12 then
      ShaguPlatesX:UpdateConfig("bars",     "bar"..i,      "buttons",           "12")       -- 按钮数量
    end
  end

  -- 动作条通用设置
  ShaguPlatesX:UpdateConfig("bars",       nil,           "animation",        "zoomfade")   -- 动画效果
  ShaguPlatesX:UpdateConfig("bars",       nil,           "nacolor",          ".3,.3,.3,1") -- 不可用颜色
  ShaguPlatesX:UpdateConfig("bars",       nil,           "font",             ShaguPlatesX.path.."\\fonts\\BigNoodleTitling.ttf")  -- 字体

  -- 狮鹫装饰
  ShaguPlatesX:UpdateConfig("bars",       "gryphons",    "texture",          "None")       -- 纹理(None=隐藏)
  ShaguPlatesX:UpdateConfig("bars",       "gryphons",    "color",            ".6,.6,.6,1") -- 颜色
  ShaguPlatesX:UpdateConfig("bars",       "gryphons",    "size",             "64")         -- 大小

  -- ========== 图腾配置 ==========
  ShaguPlatesX:UpdateConfig("totems",     nil,           "direction",        "HORIZONTAL") -- 方向(水平/垂直)
  ShaguPlatesX:UpdateConfig("totems",     nil,           "iconsize",         "26")         -- 图标大小
  ShaguPlatesX:UpdateConfig("totems",     nil,           "spacing",          "3")

  -- ========== 姓名板配置 ==========
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "showhostile",      "1")      -- 显示敌对单位
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "showfriendly",     "0")      -- 显示友方单位
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "use_unitfonts", "1")         -- 使用单位框架字体
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "legacy",           "0")      -- 传统模式
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "overlap",          "1")      -- 允许重叠
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "verticalhealth",   "0")      -- 垂直血条
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "vertical_offset",  "10")      -- 垂直偏移
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "scale",            "1")      -- 缩放比例
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "nameoffset",       "10")     -- 名字偏移
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "showcastbar",      "1")      -- 显示施法条
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "showtargetname",   "1")      -- 显示目标是谁
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "targetcastbar",    "0")      -- 仅显示目标施法条
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "spellname",        "1")      -- 显示法术名字
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "layout",           "new")   -- 姓名板布局(new新版/old旧版)
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "oldborder",        "1")      -- 旧版姓名板边框(纯色静态)
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "castbarspellfontsize", "14")  -- 施法条法术名字体大小
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "showdebuffs",      "0")      -- 显示Debuff
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "selfdebuff",       "0")      -- 仅显示自己的Debuff
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "guessdebuffs",     "1")      -- 猜测Debuff持续时间
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "clickthrough",     "0")      -- 点击穿透
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "rightclick",       "1")      -- 右键点击
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "clickthreshold",   "0.5")    -- 点击阈值
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "enemyclassc",      "1")      -- 敌对职业颜色
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "friendclassc",     "1")      -- 友方职业颜色
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "enemyclassnamec",  "0")      -- 敌军职业名字颜色
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "friendclassnamec", "0")      -- 友军职业名字颜色
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "raidiconsize",     "50")     -- 团队图标大小
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "raidiconpos",      "CENTER") -- 团队图标位置
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "raidiconoffx",     "0")      -- 团队图标X偏移
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "raidiconoffy",     "50")     -- 团队图标Y偏移
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "raidiconblizz",    "0")      -- 使用客户端原版标记图标
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "fullhealth",       "1")      -- 满血时显示
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "target",           "1")      -- 目标时显示
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "namefightcolor",   "1")      -- 战斗中名字颜色
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "enemynpc",         "0")      -- 隐藏敌对NPC
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "enemyplayer",      "0")      -- 隐藏敌对玩家
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "neutralnpc",       "0")      -- 隐藏中立NPC
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "friendlynpc",      "0")      -- 隐藏友方NPC
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "friendlyplayer",   "0")      -- 隐藏友方玩家
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "critters",         "1")      -- 隐藏小动物
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "totems",           "1")      -- 隐藏图腾
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "totemicons",       "0")      -- 显示图腾图标
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "showguildname",    "0")      -- 显示公会名
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "elitestyle",       "icon")   -- 精英标识样式(icon图标/text文字/both两者/none无)
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "disableincity",    "0")      -- 主城禁用姓名板
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "factionicon",      "1")      -- 显示玩家阵营图标

  -- 战斗状态颜色
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "outcombatstate",   "1")      -- 脱战状态颜色
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "barcombatstate",   "0")      -- 血条战斗状态颜色
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "ccombatthreat",    "1")      -- 显示仇恨颜色
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "ccombatnothreat",  "1")      -- 显示无仇恨颜色
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "ccombatstun",      "1")      -- 显示眩晕颜色
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "ccombatcasting",   "0")      -- 显示施法颜色
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "combatthreat",     ".6,1,0,1")      -- 仇恨颜色(绿色)
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "combatnothreat",   ".9,.2,.3,1")    -- 无仇恨颜色(红色)
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "combatstun",       ".8,.8,.8,1")    -- 眩晕颜色(灰色)
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "combatcasting",    ".7,.2,.7,1")    -- 施法颜色(紫色)

  -- 边框颜色
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "outfriendly",      "0")      -- 友方玩家边框
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "outfriendlynpc",   "1")      -- 友方NPC边框
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "outneutral",       "1")      -- 中立边框
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "outenemy",         "1")      -- 敌对边框
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "targethighlight",  "0")      -- 目标高亮
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "highlightcolor",   "1,1,1,1")       -- 高亮颜色

  -- 尺寸和位置
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "showhp",           "1")      -- 显示血量数字
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "hptextpos",        "RIGHT")  -- 血量文字位置
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "hptextformat",     "percent")   -- 血量文字格式（纯百分比，不带 % 号）
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "width",            "140")    -- 姓名板宽度
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "debuffsize",       "14")     -- Debuff图标大小
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "debuffoffset",     "4")      -- Debuff偏移
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "heighthealth",     "25")      -- 血条高度
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "heightcast",       "15")      -- 施法条高度
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "casticonsize",     "15")      -- 施法图标大小(空=自动)
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "cpdisplay",        "0")      -- 显示连击点
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "targetglow",       "0")      -- 目标发光
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "glowcolor",        "1,1,1,1")       -- 发光颜色
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "targetzoom",       "0")      -- 目标缩放
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "targetzoomval",    ".30")    -- 缩放值
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "targetzoominstant","0")      -- 瞬间缩放
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "notargalpha",      "1")    -- 非目标透明度
  ShaguPlatesX:UpdateConfig("nameplates", nil,           "healthtexture",    "Interface\\AddOns\\ShaguPlates\\img\\pfUI-A")  -- 血条纹理（pfUI-A 横向渐变）
  ShaguPlatesX:UpdateConfig("nameplates", "name",        "fontstyle",        "OUTLINE")       -- 名字字体样式
  ShaguPlatesX:UpdateConfig("nameplates", "health",      "offset",           "0")    -- 血条偏移(负数向下)
  
  -- Debuff过滤
  ShaguPlatesX:UpdateConfig("nameplates", "debuffs",     "filter",           "none")   -- 过滤类型(none/whitelist/blacklist)
  ShaguPlatesX:UpdateConfig("nameplates", "debuffs",     "whitelist",        "")       -- 白名单
  ShaguPlatesX:UpdateConfig("nameplates", "debuffs",     "blacklist",        "")       -- 黑名单
  ShaguPlatesX:UpdateConfig("nameplates", "debuffs",     "showstacks",       "0")      -- 显示层数
  ShaguPlatesX:UpdateConfig("nameplates", "debuffs",     "position",         "BOTTOM") -- Debuff位置

  -- ========== 动作按钮配置 ==========
  ShaguPlatesX:UpdateConfig("abuttons",   nil,           "enable",           "1")          -- 启用动作按钮
  ShaguPlatesX:UpdateConfig("abuttons",   nil,           "position",         "bottom")     -- 位置(bottom/top)
  ShaguPlatesX:UpdateConfig("abuttons",   nil,           "spacing",          "2")          -- 间距
  ShaguPlatesX:UpdateConfig("abuttons",   nil,           "hideincombat",     "1")          -- 战斗中隐藏

  -- ========== 截图配置 ==========
  ShaguPlatesX:UpdateConfig("screenshot", nil,           "interval",         "0")          -- 截图间隔(秒,0=禁用)
  ShaguPlatesX:UpdateConfig("screenshot", nil,           "faction",          "0")          -- 阵营变化时截图
  ShaguPlatesX:UpdateConfig("screenshot", nil,           "hk",               "0")          -- 荣誉击杀时截图
  ShaguPlatesX:UpdateConfig("screenshot", nil,           "loot",             "0")          -- 拾取时截图
  ShaguPlatesX:UpdateConfig("screenshot", nil,           "caption",          "0")          -- 截图标题

  -- ========== 位置和禁用配置 ==========
  ShaguPlatesX:UpdateConfig("position",   nil,           nil,                nil)          -- 框架位置保存
  ShaguPlatesX:UpdateConfig("disabled",   nil,           nil,                nil)          -- 禁用的模块
end

function ShaguPlatesX:MigrateConfig()
  -- migrating to new fonts (1.5 -> 1.6)
  if checkversion(1, 6, 0) then
    -- migrate font_default
    if ShaguPlatesX_config.global.font_default == "arial" then
      ShaguPlatesX_config.global.font_default = "Myriad-Pro"
    elseif ShaguPlatesX_config.global.font_default == "homespun" then
      ShaguPlatesX_config.global.font_default = "Homespun"
    elseif ShaguPlatesX_config.global.font_default == "diediedie" then
      ShaguPlatesX_config.global.font_default = "DieDieDie"
    end

    -- migrate font_square
    if ShaguPlatesX_config.global.font_square == "arial" then
      ShaguPlatesX_config.global.font_square = "Myriad-Pro"
    elseif ShaguPlatesX_config.global.font_square == "homespun" then
      ShaguPlatesX_config.global.font_square = "Homespun"
    elseif ShaguPlatesX_config.global.font_square == "diediedie" then
      ShaguPlatesX_config.global.font_square = "DieDieDie"
    end

    -- migrate font_combat
    if ShaguPlatesX_config.global.font_combat == "arial" then
      ShaguPlatesX_config.global.font_combat = "Myriad-Pro"
    elseif ShaguPlatesX_config.global.font_combat == "homespun" then
      ShaguPlatesX_config.global.font_combat = "Homespun"
    elseif ShaguPlatesX_config.global.font_combat == "diediedie" then
      ShaguPlatesX_config.global.font_combat = "DieDieDie"
    end
  end



  -- migrating to new fontnames (> 2.6)
  if checkversion(2, 6, 0) then
    -- migrate font_combat
    if ShaguPlatesX_config.global.font_square then
      ShaguPlatesX_config.global.font_unit = ShaguPlatesX_config.global.font_square
      ShaguPlatesX_config.global.font_square = nil
    end
  end

  -- migrating old to new font layout (> 3.0.0)
  if checkversion(3, 0, 0) then
    -- migrate font_default
    if not strfind(ShaguPlatesX_config.global.font_default, "\\") then
      ShaguPlatesX_config.global.font_default = ShaguPlatesX.path.."\\fonts\\" .. ShaguPlatesX_config.global.font_default .. ".ttf"
    end

    -- migrate font_unit
    if not strfind(ShaguPlatesX_config.global.font_unit, "\\") then
      ShaguPlatesX_config.global.font_unit = ShaguPlatesX.path.."\\fonts\\" .. ShaguPlatesX_config.global.font_unit .. ".ttf"
    end

    -- migrate font_combat
    if not strfind(ShaguPlatesX_config.global.font_combat, "\\") then
      ShaguPlatesX_config.global.font_combat = ShaguPlatesX.path.."\\fonts\\" .. ShaguPlatesX_config.global.font_combat .. ".ttf"
    end
  end


  -- migrating animation_speed (> 3.1.2)
  if checkversion(3, 1, 2) then
    if tonumber(ShaguPlatesX_config.unitframes.animation_speed) >= 13 then
      ShaguPlatesX_config.unitframes.animation_speed = "13"
    elseif tonumber(ShaguPlatesX_config.unitframes.animation_speed) >= 8 then
      ShaguPlatesX_config.unitframes.animation_speed = "8"
    elseif tonumber(ShaguPlatesX_config.unitframes.animation_speed) >= 5 then
      ShaguPlatesX_config.unitframes.animation_speed = "5"
    elseif tonumber(ShaguPlatesX_config.unitframes.animation_speed) >= 3 then
      ShaguPlatesX_config.unitframes.animation_speed = "3"
    elseif tonumber(ShaguPlatesX_config.unitframes.animation_speed) >= 2 then
      ShaguPlatesX_config.unitframes.animation_speed = "2"
    elseif tonumber(ShaguPlatesX_config.unitframes.animation_speed) >= 1 then
      ShaguPlatesX_config.unitframes.animation_speed = "1"
    else
      ShaguPlatesX_config.unitframes.animation_speed = "5"
    end
  end

  -- migrating actionbar settings (> 3.19)
  if checkversion(3, 19, 0) then

    local migratebars = {
      ["pfBarActionMain"] = "pfActionBarMain",
      ["pfBarBottomLeft"] = "pfActionBarTop",
      ["pfBarBottomRight"] = "pfActionBarLeft",
      ["pfBarTwoRight"] = "pfActionBarVertical",
      ["pfBarRight"] = "pfActionBarRight",
      ["pfBarShapeshift"] = "pfActionBarStances",
      ["pfBarPet"] = "pfActionBarPet",
    }

    -- migrate bar positions and scaling
    for oldname, newname in pairs(migratebars) do
      if ShaguPlatesX_config.position[oldname] then
        ShaguPlatesX_config.position[newname] = ShaguPlatesX.api.CopyTable(ShaguPlatesX_config.position[oldname])
        ShaguPlatesX_config.position[oldname] = nil
      end
    end

    -- migrate global settings to bar specifics
    for i=1,12 do
      if ShaguPlatesX_config.bars.icon_size then
        ShaguPlatesX_config.bars["bar"..i].icon_size = ShaguPlatesX_config.bars.icon_size
      end

      if ShaguPlatesX_config.bars.background then
        ShaguPlatesX_config.bars["bar"..i].background = ShaguPlatesX_config.bars.background
      end

      if ShaguPlatesX_config.bars.showmacro then
        ShaguPlatesX_config.bars["bar"..i].showmacro = ShaguPlatesX_config.bars.showmacro
      end

      if ShaguPlatesX_config.bars.showkeybind then
        ShaguPlatesX_config.bars["bar"..i].showkeybind = ShaguPlatesX_config.bars.showkeybind
      end

      if ShaguPlatesX_config.bars.hide_time then
        ShaguPlatesX_config.bars["bar"..i].hide_time = ShaguPlatesX_config.bars.hide_time
      end
    end

    ShaguPlatesX_config.bars.icon_size = nil
    ShaguPlatesX_config.bars.background = nil
    ShaguPlatesX_config.bars.showmacro = nil
    ShaguPlatesX_config.bars.showkeybind = nil
    ShaguPlatesX_config.bars.hide_time = nil

    if ShaguPlatesX_config.bars.hide_actionmain then
      ShaguPlatesX_config.bars.bar1.autohide = ShaguPlatesX_config.bars.hide_actionmain
      ShaguPlatesX_config.bars.hide_actionmain = nil
    end

    if ShaguPlatesX_config.bars.hide_bottomleft then
      ShaguPlatesX_config.bars.bar6.autohide = ShaguPlatesX_config.bars.hide_bottomleft
      ShaguPlatesX_config.bars.hide_bottomleft = nil
    end

    if ShaguPlatesX_config.bars.hide_bottomright then
      ShaguPlatesX_config.bars.bar5.autohide = ShaguPlatesX_config.bars.hide_bottomright
      ShaguPlatesX_config.bars.hide_bottomright = nil
    end

    if ShaguPlatesX_config.bars.hide_right then
      ShaguPlatesX_config.bars.bar3.autohide = ShaguPlatesX_config.bars.hide_right
      ShaguPlatesX_config.bars.hide_right = nil
    end

    if ShaguPlatesX_config.bars.hide_tworight then
      ShaguPlatesX_config.bars.bar4.autohide = ShaguPlatesX_config.bars.hide_tworight
      ShaguPlatesX_config.bars.hide_tworight = nil
    end

    if ShaguPlatesX_config.bars.hide_shapeshift then
      ShaguPlatesX_config.bars.bar11.autohide = ShaguPlatesX_config.bars.hide_shapeshift
      ShaguPlatesX_config.bars.hide_shapeshift = nil
    end

    if ShaguPlatesX_config.bars.hide_pet then
      ShaguPlatesX_config.bars.bar12.autohide = ShaguPlatesX_config.bars.hide_pet
      ShaguPlatesX_config.bars.hide_pet = nil
    end

    if ShaguPlatesX_config.bars.actionmain and ShaguPlatesX_config.bars.actionmain.formfactor then
      ShaguPlatesX_config.bars.bar1.formfactor = ShaguPlatesX_config.bars.actionmain.formfactor
      ShaguPlatesX_config.bars.actionmain.formfactor = nil
    end

    if ShaguPlatesX_config.bars.bottomleft and ShaguPlatesX_config.bars.bottomleft.formfactor then
      ShaguPlatesX_config.bars.bar6.formfactor = ShaguPlatesX_config.bars.bottomleft.formfactor
      ShaguPlatesX_config.bars.bottomleft.formfactor = nil
    end

    if ShaguPlatesX_config.bars.bottomright and ShaguPlatesX_config.bars.bottomright.formfactor then
      ShaguPlatesX_config.bars.bar5.formfactor = ShaguPlatesX_config.bars.bottomright.formfactor
      ShaguPlatesX_config.bars.bottomright.formfactor = nil
    end

    if ShaguPlatesX_config.bars.right and ShaguPlatesX_config.bars.right.formfactor then
      ShaguPlatesX_config.bars.bar3.formfactor = ShaguPlatesX_config.bars.right.formfactor
      ShaguPlatesX_config.bars.right.formfactor = nil
    end

    if ShaguPlatesX_config.bars.tworight and ShaguPlatesX_config.bars.tworight.formfactor then
      ShaguPlatesX_config.bars.bar4.formfactor = ShaguPlatesX_config.bars.tworight.formfactor
      ShaguPlatesX_config.bars.tworight.formfactor = nil
    end

    if ShaguPlatesX_config.bars.shapeshift and ShaguPlatesX_config.bars.shapeshift.formfactor then
      ShaguPlatesX_config.bars.bar11.formfactor = ShaguPlatesX_config.bars.shapeshift.formfactor
      ShaguPlatesX_config.bars.shapeshift.formfactor = nil
    end

    if ShaguPlatesX_config.bars.pet and ShaguPlatesX_config.bars.pet.formfactor then
      ShaguPlatesX_config.bars.bar12.formfactor = ShaguPlatesX_config.bars.pet.formfactor
      ShaguPlatesX_config.bars.pet.formfactor = nil
    end
  end


  ShaguPlatesX_config.version = ShaguPlatesX.version.string
end
