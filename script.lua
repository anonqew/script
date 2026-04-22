local AT = {
    showWatermark = cookie.GetNumber("AT_Watermark", 1) == 1,
    showESP = cookie.GetNumber("AT_ESP", 0) == 1,
    showInteract = cookie.GetNumber("AT_Interact", 0) == 1,
    showAutoAdvert = cookie.GetNumber("AT_AutoAdvert", 0) == 1,
    autoAdvertCooldownMinutes = math.Clamp(cookie.GetNumber("AT_AutoAdvertCooldownMinutes", 10), 10, 60),

    DEFAULT_MENU_KEY = KEY_B,
    MenuKey = math.floor(tonumber(cookie.GetNumber("AT_MenuBind", KEY_B)) or KEY_B),
    Cooldown = 0.5,

    lastActionTime = 0,
    activeCatIndex = 2,
    CachedViewPos = nil,
    CachedViewTime = 0,
    nextEntCheck = 0,
    nextPropCheck = 0,
    nextRagdollCheck = 0,
    showBetaWarningTime = 0,

    autoAdvertNextRun = 0,
    autoAdvertStepTime = 0,
    autoAdvertIndex = 1,
    autoAdvertRunning = false,
    autoAdvertIgnoreOwnChatUntil = 0,
    AUTO_ADVERT_STEP_DELAY = 3,

    DISCORD_API_BASE = "https://small-bonus-2395.magicrp.workers.dev",
    discordAuthorized = false,
    discordAuthPending = false,
    discordGateOpenTried = false,
    discordAutoCheckStarted = false,
    discordAuthState = "",
    discordAuthUserTag = "",
    discordPollTimer = "AdminTool.DiscordAuthPoll",
    discordBootCheckStarted = false,
    discordBootRetryCount = 0,
    discordBootMaxRetries = 20,

    AFK_IDLE_SECONDS = 120,
    AFK_TRACK_INTERVAL = 0.5,
    afkTrackNextUpdate = 0,

    PROP_LOG_BUFFER_SIZE = 100,
    PROP_LOG_NEXT = 1,
    PROP_LOG_COUNT = 0,
    PROP_LOG_VERSION = 0,
    PROP_LOG_WINDOW = 3,
    PROP_LOG_SUSPICIOUS_COUNT = 6,
    PROP_LOG_READY_TIME = CurTime() + 8,

    rndx = nil,
    rndxLoading = false,
    cachedScale = 1
}

local UI_Frames = {
    AdminTool = nil,
    Punishment = nil,
    WMSettings = nil,
    About = nil,
    AutoAdvert = nil,
    MenuBind = nil,
    ThemeColor = nil,
    DiscordGate = nil,
    PlayerStats = nil,
    PlayerStatsError = nil
}

local Cache = {
    HiddenEnts = {},
    HiddenPropEnts = {},
    HiddenRagdolls = {},
    AFK = {},
    PROP_LOG_BUFFER = {},
    PROP_LOG_TRACK = {},
    PROP_LOGGED_ENTS = {}
}

local AFKStats = {
    state              = "ACTIVE",
    idleSince          = 0,
    afkSince           = 0,
    lastAng            = nil,

    AFK_THRESHOLD      = 300,
    FLUSH_INTERVAL     = 300,
    MIN_SAVE_SECONDS   = 60,

    pendingSeconds     = 0,
    lastFlushTime      = 0,
    dbCache            = nil,
    dbLoaded           = false,
    MAX_DAYS_KEPT      = 90,

    wmFlashTime        = 0,
    afkReason          = ""
}

local function AFK_FormatHMS(sec)
    sec = math.max(0, math.floor(sec or 0))
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
end

local function AFK_FormatHuman(sec)
    sec = math.max(0, math.floor(sec or 0))
    if sec < 60 then return sec .. " сек" end
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    if h > 0 then
        if m > 0 then return h .. " ч " .. m .. " мин" end
        return h .. " ч"
    end
    return m .. " мин"
end

local OptCore = {
    ffc_fov_cos = math.cos(math.rad(55)),
    ffc_culled_ply = 0,
    ffc_culled_ent = 0,
    ffc_culled_prop = 0,
    ffc_visible_objects = {},

    atb_chunks = 12,
    atb_chunk_idx = 0,
    atb_next_tick = 0,
    atb_smoothed_fps = 60,
    atb_target_fps = 80,
    atb_load_factor = 1.0,
    atb_frame_samples = {},
    atb_sample_idx = 1,

    pms_states = {},
    pms_next_check = 0,
    pms_frozen_count = 0,

    dpr_reaped = 0,
    dpr_reaped_total = 0,
    dpr_reap_classes = {
        ["env_fire"] = true, ["env_firesmoke"] = true, ["env_smokestack"] = true,
        ["env_steam"] = true, ["env_dustpuff"] = true, ["info_particle_system"] = true,
        ["env_sprite"] = true, ["env_spritetrail"] = true, ["env_laser"] = true,
        ["beam"] = true, ["env_beam"] = true, ["env_smoketrail"] = true,
        ["env_bubbles"] = true,
    },
    dpr_tracked = {},
    dpr_spark_anim = {},

    smd_next_gc = 0,
    smd_next_flush = 0,
    smd_lua_memory = 0,
    smd_peak_memory = 0,
    smd_gc_collections = 0,

    radar_sweep_angle = 0,
    last_paint_time = 0,
}

CreateClientConVar("at_opt_ffc_enabled",     "1", true, false)
CreateClientConVar("at_opt_atb_enabled",     "1", true, false)
CreateClientConVar("at_opt_pms_enabled",     "1", true, false)
CreateClientConVar("at_opt_dpr_enabled",     "0", true, false)
CreateClientConVar("at_opt_smd_enabled",     "1", true, false)
CreateClientConVar("at_opt_ffc_fov",        "110", true, false)

local Config = {
    opt_classes = { spawned_money = true, spawned_weapon = true, spawned_shipment = true },
    PROP_LOG_CLASS_FILTER = { prop_physics = true, prop_physics_multiplayer = true },
    THEME_DEFAULT_GREEN = Color(170, 234, 89),
    THEME_DEFAULT_GOLD = Color(234, 193, 89),
    AUTO_ADVERT_MESSAGES = {
        "say /ooc >На сервере открыт набор в администрацию :dwayne:",
        "say /ooc >Если хочешь помогать проекту — подавай заявку :angrygun:",
        "say /ooc >Заявку можно оставить в Discord сервере :roflanebalo:",
        "say /ooc >Канал: набор-в-администрацию :joecool:"
    },
    AUTO_ADVERT_CHAT_LOOKUP = {},
    Mats = {
        INFO = Material("arena/info.png", "smooth noclamp"),
        CLOSE = Material("arena/close.png", "smooth noclamp"),
        MAINBTN = Material("arena/query_btn_start.png", "smooth noclamp"),
        SETTINGS = Material("arena/range.png", "smooth noclamp")
    },
    Sounds = {
        hover = "ambient/water/rain_drip1.wav",
        click = "ambient/water/rain_drip2.wav"
    },
    CVars = {
        dist_ply = CreateClientConVar("at_opt_drawdist_ply", "0", true, false),
        dist_ent = CreateClientConVar("at_opt_drawdist_ent", "0", true, false),
        dist_prop = CreateClientConVar("at_opt_drawdist_prop", "0", true, false),
        hide_ragdolls = CreateClientConVar("at_opt_hide_ragdolls", "0", true, false)
    }
}

do
    local texts = {
        "/ooc >На сервере открыт набор в администрацию :dwayne:",
        "/ooc >Если хочешь помогать проекту — подавай заявку :angrygun:",
        "/ooc >Заявку можно оставить в Discord сервере :roflanebalo:",
        "/ooc >Канал: набор-в-администрацию :joecool:"
    }
    for _, msg in ipairs(texts) do Config.AUTO_ADVERT_CHAT_LOOKUP[string.Trim(string.lower(msg))] = true end
end

local function LoadRNDX()
    if AT.rndx or AT.rndxLoading then return end
    AT.rndxLoading = true
    http.Fetch("https://raw.githubusercontent.com/deltazore/admintool/refs/heads/main/renderlib.lua", function(body)
        local func = CompileString(body, "RNDX_Library", false)
        if isfunction(func) then
            AT.rndx = func()
        else
            print("[AdminTool] Ошибка компиляции RNDX: " .. tostring(func))
        end
        AT.rndxLoading = false
    end, function(err)
        AT.rndxLoading = false
        print("[AdminTool] Ошибка загрузки RNDX: " .. tostring(err))
    end)
end
LoadRNDX()

local function UpdateATScale() AT.cachedScale = math.min(ScrW() / 1920, ScrH() / 1080) end
UpdateATScale()
hook.Add("OnScreenSizeChanged", "AdminTool.UpdateScale", function() timer.Simple(0, UpdateATScale) end)
local function ATScale(x) return math.max(1, math.Round(x * AT.cachedScale)) end

local function ClampColorChannel(n) return math.Clamp(math.Round(tonumber(n) or 0), 0, 255) end

local function SafeSimpleText(text, font, x, y, col, ax, ay)
    if not draw or not draw.SimpleText then return 0, 0 end
    local str = tostring(text or "")
    font = font or "DermaDefault"
    
    surface.SetFont(font)
    local w = surface.GetTextSize(str)
    if not w then font = "DermaDefault" end
    
    return draw.SimpleText(str, font, tonumber(x) or 0, tonumber(y) or 0, col or color_white, ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_TOP)
end

local UI = {
    pad = function() return ATScale(16) end,
    pad2 = function() return ATScale(4) end,
    header_h = function() return ATScale(132) end,
    sidebar_w = function() return ATScale(360) end,
    body_pad = function() return ATScale(38) end,
    anim = 0.16
}

local THEME = {
    bg = Color(10, 10, 10, 210),
    subBorder = Color(255, 255, 255, 13),
    subBg = Color(28, 28, 28),
    inactive = Color(255, 255, 255, 102),
    hover = Color(255, 255, 255, 26),
    redHover = Color(255, 107, 107, 90),
    green = Color(Config.THEME_DEFAULT_GREEN.r, Config.THEME_DEFAULT_GREEN.g, Config.THEME_DEFAULT_GREEN.b),
    gold = Color(Config.THEME_DEFAULT_GOLD.r, Config.THEME_DEFAULT_GOLD.g, Config.THEME_DEFAULT_GOLD.b),
    red = Color(255, 43, 43),
    blue = Color(114, 191, 255),
    white = color_white,
    textSub = Color(140, 140, 140),
    card = Color(28, 28, 28),
    card2 = Color(22, 22, 22),
    line = Color(255, 255, 255, 10)
}

local STAFF_HIERARCHY = {
    { name = "Крутой чел", color = Color(255, 187, 0), steamids = { ["STEAM_0:0:634285691"] = true, ["STEAM_0:1:518025435"] = true }, ranks = {} },
    { name = "Высшая администрация", color = Color(255, 0, 0), ranks = { superadmin = true, root = true, sudoroot = true, spectator = true, ["gl.curator"] = true, stcurator = true, gladmin = true } },
    { name = "Старшая администрация", color = Color(0, 92, 12), ranks = { support = true, operator = true, stadmin = true } },
    { name = "Младшая администрация", color = Color(0, 140, 255), ranks = { admin = true, moder = true, helper = true } }
}

local DATA = {
    { name = "Поддержать" },
    { name = "Оптимизация" },
    { name = "Список администрации" },
    { name = "Игроки в AFK" },
    { name = "Логи пропов" },
    { name = "Админ-статистика AFK" },
    {
        name = "Настройки",
        items = {
            { cmd = "Watermark", desc = "Отображение индикатора вверху экрана", isToggle = true },
            { cmd = "Информация на игроке", desc = "Отображение доп. информации на игроке", isToggle = true, adminOnly = true },
            { cmd = "Взаимодействие с игроком", desc = "Отображение меню взаимодействия с игроком", isToggle = true},
            { cmd = "Авто-реклама", desc = "Автоматически отправляет 4 сообщения с выбранным интервалом", isToggle = true },
            { cmd = "Клавиша открытия меню", desc = "Изменяет кнопку открытия главного меню AdminTool", isAction = true }
        }
    }
}

local function TMi(n) return n end
local function TH(n) return n * 60 end
local function TD(n) return n * 1440 end
local function TW(n) return n * 10080 end
local function TMO(n) return n * 43200 end
local function TimeOpt(label, minutes, perma) return { label = label, minutes = minutes or 0, perma = perma == true } end

local AA_TIME_OPT = { TimeOpt("1d", TD(1)), TimeOpt("2d", TD(2)), TimeOpt("4d", TD(4)), TimeOpt("5d", TD(5)), TimeOpt("1mo", TMO(1)) }
local NSPN_TIME_OPT = { TimeOpt("1d", TD(1)), TimeOpt("3d", TD(3)), TimeOpt("5d", TD(5)), TimeOpt("1mo", TMO(1)) }
local NPA_TIME_OPT = { TimeOpt("1d", TD(1)), TimeOpt("2d", TD(2)), TimeOpt("3d", TD(3)), TimeOpt("1w", TW(1)) }

local PROJECT_CONFIGS = {
    ["magic"] = {
        PUNISH_CONFIG = {
            reasons = {
                ban = { "NRP", "Leave", "FDMG", "RDMx1", "RDMx2", "RDMx3", "RDMx4", "MRDM", "NLR", "FRP", "PLB", "BA", "FA", "FWanted", "CJ", "JA", "OSADM", "OSAR", "OSS", "НПЧ", "Махинации", "SR", "РМР", "FW", "GZA", "KZ", "ONA", "FT", "NNA", "FCheck", "FCuff", "FDemote", "NRPGun", "VA", "SA", "BS", "Неадекват", "Помеха", "Рецидив", "1.2", "1.5", "1.6", "1.7", "1.9", "MB", "PA", "FDA", "KA", "TSA", "RB", "AAx1", "AAx2", "AAx3", "AAx4", "AAx5", "НСПНx6", "AAx7", "НСПНx8", "НПАx9", "AAx10", "AAx11", "НПАx12", "AAx13", "НПАx14", "НПАx15", "AAx16", "AAx18", "AAx19", "НПАx20", "НПАx21", "НСПНx22", "НПИС", "0.17", "0.16" },
                perma = { "Cheats", "ПКС", "Слив", "0.8", "0.9", "0.17", "0.23" },
                mute = { "OSA", "MetaGaming" }
            },
            types = {
                { n = "Выдача блокировки", t = "ban", c = "ban" },
                { n = "Выдача перманентной блокировки", t = "perma", c = "perma" },
                { n = "Выдача глобального мута", t = "mute", c = "mute" },
                { n = "Выдача мута чата", t = "mute_chat", c = "mutechat" },
                { n = "Выдача мута войса", t = "mute_voice", c = "mutevoice" }
            }
        },
        PUNISH_TIME_OPTIONS = {
            NRP = { TimeOpt("10mi", TMi(10)) }, Leave = { TimeOpt("30mi", TMi(30)) }, FDMG = { TimeOpt("10mi", TMi(10)) },
            RDMx1 = { TimeOpt("10mi", TMi(10)) }, RDMx2 = { TimeOpt("20mi", TMi(20)) }, RDMx3 = { TimeOpt("30mi", TMi(30)) },
            RDMx4 = { TimeOpt("40mi", TMi(40)) }, MRDM = { TimeOpt("1w", TW(1)), TimeOpt("1mo", TMO(1)) },
            NLR = { TimeOpt("10mi", TMi(10)) }, FRP = { TimeOpt("10mi", TMi(10)) }, PLB = { TimeOpt("20mi", TMi(20)) },
            BA = { TimeOpt("1d", TD(1)), TimeOpt("3d", TD(3)) }, FA = { TimeOpt("10mi", TMi(10)) }, FWanted = { TimeOpt("10mi", TMi(10)) },
            CJ = { TimeOpt("10mi", TMi(10)) }, JA = { TimeOpt("10mi", TMi(10)), TimeOpt("15mi", TMi(15)) },
            OSADM = { TimeOpt("30mi", TMi(30)), TimeOpt("45mi", TMi(45)) }, OSAR = { TimeOpt("10mi", TMi(10)), TimeOpt("24h", TH(24)) },
            OSS = { TimeOpt("4d", TD(4)) }, ["НПЧ"] = { TimeOpt("30mi", TMi(30)) }, ["Махинации"] = { TimeOpt("1h", TH(1)), TimeOpt("4d", TD(4)) },
            SR = { TimeOpt("30mi", TMi(30)) }, ["РМР"] = { TimeOpt("10mi", TMi(10)) }, FW = { TimeOpt("10mi", TMi(10)) },
            GZA = { TimeOpt("10mi", TMi(10)) }, KZ = { TimeOpt("10mi", TMi(10)) }, ONA = { TimeOpt("1d", TD(1)) },
            FT = { TimeOpt("10mi", TMi(10)) }, NNA = { TimeOpt("10mi", TMi(10)) }, FCheck = { TimeOpt("10mi", TMi(10)) },
            FCuff = { TimeOpt("10mi", TMi(10)) }, FDemote = { TimeOpt("10mi", TMi(10)) }, NRPGun = { TimeOpt("10mi", TMi(10)) },
            VA = { TimeOpt("10mi", TMi(10)) }, SA = { TimeOpt("30mi", TMi(30)) }, BS = { TimeOpt("1w", TW(1)) },
            ["Неадекват"] = { TimeOpt("1h", TH(1)), TimeOpt("12h", TH(12)) }, ["Помеха"] = { TimeOpt("10mi", TMi(10)) },
            ["Рецидив"] = { TimeOpt("24h", TH(24)), TimeOpt("1w", TW(1)) },
            ["0.16"] = { TimeOpt("24h", TH(24)) }, ["0.17"] = { TimeOpt("1mo", TMO(1)), TimeOpt("perma", 0, true) },
            ["1.2"] = { TimeOpt("6h", TH(6)) }, ["1.5"] = { TimeOpt("4h", TH(4)) }, ["1.6"] = { TimeOpt("30mi", TMi(30)) },
            ["1.7"] = { TimeOpt("30mi", TMi(30)) }, ["1.9"] = { TimeOpt("1d", TD(1)), TimeOpt("15d", TD(15)) },
            MB = { TimeOpt("10mi", TMi(10)) }, PA = { TimeOpt("10mi", TMi(10)) }, FDA = { TimeOpt("10mi", TMi(10)) },
            KA = { TimeOpt("10mi", TMi(10)) }, TSA = { TimeOpt("10mi", TMi(10)) }, RB = { TimeOpt("1d", TD(1)) },
            OSA = { TimeOpt("10mi", TMi(10)) }, MetaGaming = { TimeOpt("10mi", TMi(10)) },

            AAx1 = AA_TIME_OPT, AAx2 = AA_TIME_OPT, AAx3 = AA_TIME_OPT, AAx4 = AA_TIME_OPT, AAx5 = AA_TIME_OPT,
            AAx7 = AA_TIME_OPT, AAx10 = AA_TIME_OPT, AAx11 = AA_TIME_OPT, AAx13 = AA_TIME_OPT, AAx16 = AA_TIME_OPT,
            AAx18 = AA_TIME_OPT, AAx19 = AA_TIME_OPT,
            
            ["НСПНx6"] = NSPN_TIME_OPT, ["НСПНx8"] = NSPN_TIME_OPT, ["НСПНx22"] = NSPN_TIME_OPT,
            
            ["НПАx9"] = NPA_TIME_OPT, ["НПАx12"] = NPA_TIME_OPT, ["НПАx14"] = NPA_TIME_OPT,
            ["НПАx15"] = NPA_TIME_OPT, ["НПАx20"] = NPA_TIME_OPT, ["НПАx21"] = NPA_TIME_OPT,
            ["НПИС"] = { TimeOpt("30mi", TMi(30)) }
        }
    },
    ["infinity"] = {
        PUNISH_CONFIG = {
            reasons = {
                ban = { "NRP", "Leave", "FDMG", "RDMx1", "RDMx2", "RDMx3", "RDMx4", "MRDM", "NLR", "FRP", "PLB", "BA", "FA", "FWanted", "CJ", "JA", "OSADM", "OSAR", "OSS", "НПЧ", "Махинации", "SR", "РМР", "FW", "GZA", "KZ", "ONA", "FT", "NNA", "FCheck", "FCuff", "FDemote", "NRPGun", "VA", "SA", "BS", "Неадекват", "Помеха", "Рецидив", "1.2", "1.5", "1.6", "1.7", "1.9", "MB", "PA", "FDA", "KA", "TSA", "RB", "ADM1.1", "ADM1.2", "ADM1.3", "ADM1.4", "ADM1.5", "ADM1.6", "ADM1.7", "ADM1.8", "ADM1.9", "ADM1.10", "ADM1.11", "ADM1.12", "ADM1.13", "ADM1.14", "ADM1.15", "ADM1.16", "ADM1.17", "ADM1.18", "ADM1.19", "ADM1.20", "ADM1.21", "НПИС", "0.17", "0.16" },
                perma = { "Cheats", "ПКС", "Слив", "0.8", "0.9", "0.23" },
                mute = { "OSA", "MetaGaming" }
            },
            types = {
                { n = "Выдача блокировки", t = "ban", c = "ban" },
                { n = "Выдача перманентной блокировки", t = "perma", c = "perma" },
                { n = "Выдача глобального мута", t = "mute", c = "mute" },
                { n = "Выдача мута чата", t = "mute_chat", c = "mutechat" },
                { n = "Выдача мута войса", t = "mute_voice", c = "mutevoice" }
            }
        },
        PUNISH_TIME_OPTIONS = {
            NRP = { TimeOpt("10mi", TMi(10)) }, Leave = { TimeOpt("30mi", TMi(30)) }, FDMG = { TimeOpt("10mi", TMi(10)) },
            RDMx1 = { TimeOpt("10mi", TMi(10)) }, RDMx2 = { TimeOpt("20mi", TMi(20)) }, RDMx3 = { TimeOpt("30mi", TMi(30)) },
            RDMx4 = { TimeOpt("40mi", TMi(40)) }, MRDM = { TimeOpt("1w", TW(1)), TimeOpt("1mo", TMO(1)) },
            NLR = { TimeOpt("10mi", TMi(10)) }, FRP = { TimeOpt("10mi", TMi(10)) }, PLB = { TimeOpt("20mi", TMi(20)) },
            BA = { TimeOpt("1d", TD(1)), TimeOpt("3d", TD(3)) }, FA = { TimeOpt("10mi", TMi(10)) }, FWanted = { TimeOpt("10mi", TMi(10)) },
            CJ = { TimeOpt("10mi", TMi(10)) }, JA = { TimeOpt("10mi", TMi(10)), TimeOpt("15mi", TMi(15)) },
            OSADM = { TimeOpt("30mi", TMi(30)), TimeOpt("45mi", TMi(45)) }, OSAR = { TimeOpt("10mi", TMi(10)), TimeOpt("24h", TH(24)) },
            OSS = { TimeOpt("4d", TD(4)) }, ["НПЧ"] = { TimeOpt("30mi", TMi(30)) }, ["Махинации"] = { TimeOpt("1h", TH(1)), TimeOpt("4d", TD(4)) },
            SR = { TimeOpt("30mi", TMi(30)) }, ["РМР"] = { TimeOpt("10mi", TMi(10)) }, FW = { TimeOpt("10mi", TMi(10)) },
            GZA = { TimeOpt("10mi", TMi(10)) }, KZ = { TimeOpt("10mi", TMi(10)) }, ONA = { TimeOpt("1d", TD(1)) },
            FT = { TimeOpt("10mi", TMi(10)) }, NNA = { TimeOpt("10mi", TMi(10)) }, FCheck = { TimeOpt("10mi", TMi(10)) },
            FCuff = { TimeOpt("10mi", TMi(10)) }, FDemote = { TimeOpt("10mi", TMi(10)) }, NRPGun = { TimeOpt("10mi", TMi(10)) },
            VA = { TimeOpt("10mi", TMi(10)) }, SA = { TimeOpt("30mi", TMi(30)) }, BS = { TimeOpt("1w", TW(1)) },
            ["Неадекват"] = { TimeOpt("1h", TH(1)), TimeOpt("12h", TH(12)) }, ["Помеха"] = { TimeOpt("10mi", TMi(10)) },
            ["Рецидив"] = { TimeOpt("24h", TH(24)), TimeOpt("1w", TW(1)) },
            ["0.16"] = { TimeOpt("24h", TH(24)) }, ["0.17"] = { TimeOpt("3w", TW(3)), TimeOpt("1mo", TMO(1)) },
            ["1.2"] = { TimeOpt("6h", TH(6)) }, ["1.5"] = { TimeOpt("4h", TH(4)) }, ["1.6"] = { TimeOpt("30mi", TMi(30)) },
            ["1.7"] = { TimeOpt("30mi", TMi(30)) }, ["1.9"] = { TimeOpt("1d", TD(1)), TimeOpt("15d", TD(15)) },
            MB = { TimeOpt("10mi", TMi(10)) }, PA = { TimeOpt("10mi", TMi(10)) }, FDA = { TimeOpt("10mi", TMi(10)) },
            KA = { TimeOpt("10mi", TMi(10)) }, TSA = { TimeOpt("10mi", TMi(10)) }, RB = { TimeOpt("1d", TD(1)) },
            OSA = { TimeOpt("10mi", TMi(10)) }, MetaGaming = { TimeOpt("10mi", TMi(10)) },
            
            ["ADM1.1"] = AA_TIME_OPT, ["ADM1.2"] = AA_TIME_OPT, ["ADM1.3"] = AA_TIME_OPT, ["ADM1.4"] = AA_TIME_OPT, ["ADM1.5"] = AA_TIME_OPT, ["ADM1.6"] = AA_TIME_OPT, ["ADM1.7"] = AA_TIME_OPT,
            ["ADM1.8"] = AA_TIME_OPT, ["ADM1.9"] = AA_TIME_OPT, ["ADM1.10"] = AA_TIME_OPT,["ADM1.11"] = AA_TIME_OPT,["ADM1.12"] = AA_TIME_OPT,["ADM1.13"] = AA_TIME_OPT,["ADM1.14"] = AA_TIME_OPT,
            ["ADM1.15"] = AA_TIME_OPT,["ADM1.16"] = AA_TIME_OPT,["ADM1.17"] = AA_TIME_OPT,["ADM1.18"] = AA_TIME_OPT,["ADM1.19"] = AA_TIME_OPT,["ADM1.20"] = AA_TIME_OPT,["ADM1.21"] = AA_TIME_OPT,
            ["НПИС"] = { TimeOpt("30mi", TMi(30)) }
        }
    }
}

local activeConfig = (game.GetIPAddress() == "212.22.93.109:27015") and PROJECT_CONFIGS["infinity"] or PROJECT_CONFIGS["magic"]

local PUNISH_CONFIG = activeConfig.PUNISH_CONFIG
local PUNISH_TIME_OPTIONS = activeConfig.PUNISH_TIME_OPTIONS

local function CloneTimeOptions(tbl)
    local out = {}
    for i, v in ipairs(tbl or {}) do out[i] = { label = v.label, minutes = v.minutes, perma = v.perma } end
    return out
end

local BAN_RANK_LIMITS = {
    helper = 240, moder = 540, admin = 43200,
    stadmin = math.huge, operator = math.huge, support = math.huge, gladmin = math.huge,
    stcurator = math.huge, ["gl.curator"] = math.huge, spectator = math.huge, sudoroot = math.huge,
    root = math.huge, superadmin = math.huge
}

local OPT_PRESETS = {
    { name = "Очень низкие", desc = "Максимально разгружает клиент в критических ситуациях", color = Color(255, 43, 43), cvars = { cl_threaded_bone_setup = 1, cl_threaded_client_leaf_system = 1, mat_picmip = 2, r_rootlod = 2, r_shadows = 0, mat_specular = 0, mat_bumpmap = 0, r_3dsky = 0, r_waterdrawreflection = 0, r_waterdrawrefraction = 0, r_decals = 0, mp_decals = 0, r_drawmodeldecals = 0, r_dynamic = 0, r_drawdetailprops = 0, cl_ejectbrass = 0, at_opt_drawdist_ply = 1000, at_opt_drawdist_ent = 700, at_opt_drawdist_prop = 800, at_opt_hide_ragdolls = 1, at_opt_ffc_enabled = 1, at_opt_atb_enabled = 1, at_opt_pms_enabled = 1, at_opt_dpr_enabled = 1, at_opt_smd_enabled = 1 } },
    { name = "Низкие", desc = "Жесткая оптимизация для стабильной игры на слабом железе", color = Color(255, 120, 120), cvars = { cl_threaded_bone_setup = 1, cl_threaded_client_leaf_system = 1, mat_picmip = 2, r_rootlod = 2, r_shadows = 0, mat_specular = 0, mat_bumpmap = 0, r_3dsky = 0, r_waterdrawreflection = 0, r_waterdrawrefraction = 0, r_decals = 64, mp_decals = 64, r_drawmodeldecals = 0, r_dynamic = 0, r_drawdetailprops = 0, cl_ejectbrass = 0, at_opt_drawdist_ply = 1800, at_opt_drawdist_ent = 1200, at_opt_drawdist_prop = 1400, at_opt_hide_ragdolls = 1, at_opt_ffc_enabled = 1, at_opt_atb_enabled = 1, at_opt_pms_enabled = 1, at_opt_dpr_enabled = 1, at_opt_smd_enabled = 1 } },
    { name = "Средние", desc = "Оптимальный режим для долгой ежедневной работы администратора", color = Color(170, 234, 89), cvars = { cl_threaded_bone_setup = 1, cl_threaded_client_leaf_system = 1, mat_picmip = 1, r_rootlod = 1, r_shadows = 1, mat_specular = 1, mat_bumpmap = 1, r_3dsky = 1, r_waterdrawreflection = 0, r_waterdrawrefraction = 1, r_decals = 256, mp_decals = 256, r_drawmodeldecals = 1, r_dynamic = 0, r_drawdetailprops = 1, cl_ejectbrass = 0, at_opt_drawdist_ply = 3200, at_opt_drawdist_ent = 2600, at_opt_drawdist_prop = 2400, at_opt_hide_ragdolls = 0, at_opt_ffc_enabled = 1, at_opt_atb_enabled = 1, at_opt_pms_enabled = 1, at_opt_dpr_enabled = 0, at_opt_smd_enabled = 1 } },
    { name = "Высокие", desc = "Хороший баланс между читаемостью сцены и производительностью", color = Color(114, 191, 255), cvars = { cl_threaded_bone_setup = 1, cl_threaded_client_leaf_system = 1, mat_picmip = 1, r_rootlod = 1, r_shadows = 1, mat_specular = 1, mat_bumpmap = 1, r_3dsky = 1, r_waterdrawreflection = 0, r_waterdrawrefraction = 1, r_decals = 512, mp_decals = 512, r_drawmodeldecals = 1, r_dynamic = 1, r_drawdetailprops = 1, cl_ejectbrass = 0, at_opt_drawdist_ply = 4200, at_opt_drawdist_ent = 3200, at_opt_drawdist_prop = 3000, at_opt_hide_ragdolls = 0, at_opt_ffc_enabled = 1, at_opt_atb_enabled = 1, at_opt_pms_enabled = 0, at_opt_dpr_enabled = 0, at_opt_smd_enabled = 1 } },
    { name = "Очень высокие", desc = "Для спокойной игры, когда важнее визуал, чем максимальный FPS", color = Color(120, 210, 255), cvars = { cl_threaded_bone_setup = 1, cl_threaded_client_leaf_system = 1, mat_picmip = 0, r_rootlod = 0, r_shadows = 1, mat_specular = 1, mat_bumpmap = 1, r_3dsky = 1, r_waterdrawreflection = 0, r_waterdrawrefraction = 1, r_decals = 1024, mp_decals = 1024, r_drawmodeldecals = 1, r_dynamic = 1, r_drawdetailprops = 1, cl_ejectbrass = 1, at_opt_drawdist_ply = 0, at_opt_drawdist_ent = 0, at_opt_drawdist_prop = 0, at_opt_hide_ragdolls = 0, at_opt_ffc_enabled = 0, at_opt_atb_enabled = 1, at_opt_pms_enabled = 0, at_opt_dpr_enabled = 0, at_opt_smd_enabled = 0 } },
    { name = "Ультра", desc = "Почти без ограничений: для мощных ПК и лучшей картинки", color = Color(190, 160, 255), cvars = { cl_threaded_bone_setup = 1, cl_threaded_client_leaf_system = 1, mat_picmip = 0, r_rootlod = 0, r_shadows = 1, mat_specular = 1, mat_bumpmap = 1, r_3dsky = 1, r_waterdrawreflection = 1, r_waterdrawrefraction = 1, r_decals = 2048, mp_decals = 2048, r_drawmodeldecals = 1, r_dynamic = 1, r_drawdetailprops = 1, cl_ejectbrass = 1, at_opt_drawdist_ply = 0, at_opt_drawdist_ent = 0, at_opt_drawdist_prop = 0, at_opt_hide_ragdolls = 0, at_opt_ffc_enabled = 0, at_opt_atb_enabled = 0, at_opt_pms_enabled = 0, at_opt_dpr_enabled = 0, at_opt_smd_enabled = 0 } }
}

local function ApplyOptPreset(preset)
    if not istable(preset) or not istable(preset.cvars) then return end
    for cvar, val in pairs(preset.cvars) do
        RunConsoleCommand(cvar, tostring(val))
    end
end

local OPT_SETTINGS = {
    { cat = "Дальность прорисовки (0 — бесконечно)" },
    { name = "Прорисовка игроков",        cv = "at_opt_drawdist_ply",  t = "slider", min = 0, max = 5000, desc = "Игроки пропадают на заданном расстоянии от камеры. Работает только если ты за профу администратора!" },
    { name = "Прорисовка энтити/NPC",     cv = "at_opt_drawdist_ent",  t = "slider", min = 0, max = 5000, desc = "Скрывает энтити и NPC для экономии ресурсов" },
    { name = "Прорисовка пропов",         cv = "at_opt_drawdist_prop", t = "slider", min = 0, max = 5000, desc = "Скрывает дальние prop_physics" },

    { cat = "Многоядерная обработка" },
    { name = "Многопоточные кости",       cv = "cl_threaded_bone_setup", t = "toggle", on = 1, off = 0, desc = "Ускоряет расчёт анимаций игроков" },

    { cat = "Графика и детализация" },
    { name = "Качество текстур (0 — макс, 2 — мыло)", cv = "mat_picmip",  t = "slider", min = 0, max = 2,    desc = "Снижает разрешение всех текстур" },
    { name = "Детализация моделей (0 — макс, 2 — ужас)", cv = "r_rootlod", t = "slider", min = 0, max = 2,   desc = "Упрощает геометрию пропов и игроков" },
    { name = "Количество следов",          cv = "r_decals",          t = "slider", min = 0, max = 2048, desc = "Чем меньше, тем быстрее пропадают следы" },
    { name = "Детали карты и трава",       cv = "r_drawdetailprops", t = "toggle", on = 1, off = 0, desc = "Отключает мелкие декоративные детали на карте" },

    { cat = "Эффекты и тени" },
    { name = "Отрисовка теней",            cv = "r_shadows",              t = "toggle", on = 1, off = 0, desc = "Полностью отключает тени объектов" },
    { name = "3D Skybox",                  cv = "r_3dsky",                t = "toggle", on = 1, off = 0, desc = "Отключает дальний фон карты" },
    { name = "Отражения в воде",           cv = "r_waterdrawreflection",  t = "toggle", on = 1, off = 0, desc = "Отключает зеркальность воды" },
    { name = "Блики и бампмаппинг",        cv = "mat_specular",           t = "toggle", on = 1, off = 0, desc = "Отключает блеск и рельефность поверхностей" },
    { name = "Динамический свет",          cv = "r_dynamic",              t = "toggle", on = 1, off = 0, desc = "Отключает динамические источники света от эффектов и выстрелов" },
    { name = "Гильзы",                     cv = "cl_ejectbrass",          t = "toggle", on = 1, off = 0, desc = "Отключает вылет гильз от оружия" },

    { cat = "Локальные скрытия" },
    { name = "Скрывать рэгдоллы",          cv = "at_opt_hide_ragdolls",   t = "toggle", on = 1, off = 0, desc = "Локально убирает рэгдоллы с карты" },

    { cat = "Быстрые действия" },
    { name = "Очистить декали и кровь",    t = "action", btn = "Очистить", desc = "Моментально очищает следы крови, выстрелов и прочие декали", action = function() RunConsoleCommand("r_cleardecals") end },
}

local function GetCookieColor(prefix, fallback) return Color(ClampColorChannel(cookie.GetNumber(prefix .. "_r", fallback.r)), ClampColorChannel(cookie.GetNumber(prefix .. "_g", fallback.g)), ClampColorChannel(cookie.GetNumber(prefix .. "_b", fallback.b))) end
local function SetCookieColor(prefix, col) cookie.Set(prefix .. "_r", tostring(ClampColorChannel(col.r))); cookie.Set(prefix .. "_g", tostring(ClampColorChannel(col.g))); cookie.Set(prefix .. "_b", tostring(ClampColorChannel(col.b))) end
local function ResetCookieColor(prefix, fallback) SetCookieColor(prefix, fallback) end
local function ApplyThemeAccentColors() THEME.green, THEME.gold = GetCookieColor("AT_THEME_GREEN", Config.THEME_DEFAULT_GREEN), GetCookieColor("AT_THEME_GOLD", Config.THEME_DEFAULT_GOLD) end
ApplyThemeAccentColors()

local function CreateFonts()
    for i = 1, 50 do
        local size = ATScale(i)
        surface.CreateFont("AT.Bold." .. i, { font = "Nunito Bold", size = size, weight = 700, extended = true, antialias = true })
        surface.CreateFont("AT.Light." .. i, { font = "Nunito Bold", size = size, weight = 700, extended = true, antialias = true })
    end
end
CreateFonts()
hook.Add("OnScreenSizeChanged", "AdminTool.RecreateFonts", function() timer.Simple(0, CreateFonts) end)

local function LCol(a, b, t) return Color(math.Round(Lerp(t, a.r, b.r)), math.Round(Lerp(t, a.g, b.g)), math.Round(Lerp(t, a.b, b.b)), math.Round(Lerp(t, a.a or 255, b.a or 255))) end

local function PaintSubPanel(x, y, w, h, r)
    if not AT.rndx then return end
    r = r or ATScale(16)
    AT.rndx.Draw(r, x, y, w, h, THEME.subBg)
    AT.rndx.DrawOutlined(r, x, y, w, h, THEME.subBorder, 1)
end

local function PaintHoverFill(x, y, w, h, col, r) 
    if AT.rndx then AT.rndx.Draw(r or ATScale(16), x, y, w, h, col or THEME.hover) end 
end

local function PlayHover() end
local function PlayClick() 
    local p = LocalPlayer()
    if IsValid(p) then p:EmitSound(Config.Sounds.click, 0, 100, 0.5) end 
end

local function SetStandardSliderPaint(sl)
    sl.Paint = function(s, w, h)
        if AT.rndx then
            AT.rndx.Draw(256, 0, h * 0.5 - ATScale(3), w, ATScale(6), ColorAlpha(color_white, 20))
            AT.rndx.Draw(256, 0, h * 0.5 - ATScale(3), w * s:GetSlideX(), ATScale(6), THEME.green)
        end
    end
    sl.Knob.Paint = function(_, w, h) 
        if AT.rndx then AT.rndx.Draw(256, ATScale(2), ATScale(2), w - ATScale(4), h - ATScale(4), color_white) end 
    end
end

local function CreateHoverButton(parent, paintFn, clickFn, enterFn)
    local btn = parent:Add("DButton")
    btn:SetText("")
    btn.Paint = paintFn
    btn.OnCursorEntered = enterFn or PlayHover
    btn.DoClick = function(s) PlayClick(); if clickFn then clickFn(s) end end
    return btn
end

local function CreateSubButton(parent, text, font, click, rounding)
    return CreateHoverButton(parent, function(s, w, h)
        PaintSubPanel(0, 0, w, h, rounding or ATScale(12))
        if s:IsHovered() then PaintHoverFill(0, 0, w, h, THEME.hover, rounding or ATScale(12)) end
        SafeSimpleText(text, font or "AT.Bold.16", w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end, click)
end

local function CreateActionButton(parent, text, w, h, click, font)
    local btn = CreateSubButton(parent, text, font or "AT.Bold.16", click)
    if w then btn:SetWide(w) end
    if h then btn:SetTall(h) end
    return btn
end

local function GetLocalSteamID()
    local p = LocalPlayer()
    if not IsValid(p) then return nil end
    local sid = p:SteamID()
    if not sid or sid == "" or sid == "NULL" then return nil end
    return sid
end

local function SetDiscordAuthorized(enabled, userTag) AT.discordAuthorized = enabled == true; AT.discordAuthUserTag = tostring(userTag or "") end
local function StopDiscordPolling() timer.Remove(AT.discordPollTimer); AT.discordAuthPending = false end
local function CloseDiscordGate() if IsValid(UI_Frames.DiscordGate) then UI_Frames.DiscordGate:Remove() end; UI_Frames.DiscordGate = nil end

local function PollDiscordStatus(state)
    if not state or state == "" then return end
    StopDiscordPolling(); AT.discordAuthPending = true
    timer.Create(AT.discordPollTimer, 2, 0, function()
        http.Fetch(AT.DISCORD_API_BASE .. "/auth/status?state=" .. state, function(body)
            local data = util.JSONToTable(body or "")
            if not istable(data) or data.ok ~= true or data.status == "pending" then return end
            StopDiscordPolling()
            if data.status == "approved" then
                SetDiscordAuthorized(true, data.user_tag or "")
                notification.AddLegacy("Discord успешно подтверждён", 0, 4)
                surface.PlaySound("buttons/button15.wav")
                CloseDiscordGate()
                return
            end
            SetDiscordAuthorized(false, "")
            notification.AddLegacy(data.status == "denied" and "У вас нет доступа: вас нет на Discord-сервере" or "Авторизация Discord не была завершена", 1, 5)
            surface.PlaySound("buttons/button10.wav")
        end, function(err)
            StopDiscordPolling()
            notification.AddLegacy("Ошибка запроса к Discord API: " .. tostring(err), 1, 5)
            surface.PlaySound("buttons/button10.wav")
        end)
    end)
end

local function StartDiscordAuthorization()
    if AT.discordAuthPending then notification.AddLegacy("Авторизация уже ожидается", 0, 3); return end
    local steamid = GetLocalSteamID()
    if not steamid then notification.AddLegacy("Не удалось получить SteamID игрока", 1, 4); surface.PlaySound("buttons/button10.wav"); return end

    http.Fetch(AT.DISCORD_API_BASE .. "/auth/start?steamid=" .. steamid, function(body)
        local data = util.JSONToTable(body or "")
        if not istable(data) or data.ok ~= true or not data.auth_url or not data.state then
            notification.AddLegacy("Не удалось начать Discord-авторизацию", 1, 4); surface.PlaySound("buttons/button10.wav"); return
        end
        AT.discordAuthState, AT.discordAuthPending = tostring(data.state), true
        gui.OpenURL(tostring(data.auth_url))
        notification.AddLegacy("Открыт браузер Discord. Заверши вход там.", 0, 5)
        PollDiscordStatus(AT.discordAuthState)
    end, function(err)
        notification.AddLegacy("Ошибка подключения к Worker: " .. tostring(err), 1, 5); surface.PlaySound("buttons/button10.wav")
    end)
end

local function HasScriptAccess(ply) return IsValid(ply) and AT.discordAuthorized == true end
local function HasToolAccess(ply) return IsValid(ply) and (ply:Team() == TEAM_ADMIN) or false end
local function IsLocalFSpectating() return FSpectate and FSpectate.isSpectating == true end

local function GetStaffEntry(ply)
    if not IsValid(ply) then return nil end
    local sid, grp = ply:SteamID(), string.lower(ply:GetUserGroup() or "")
    for _, h in ipairs(STAFF_HIERARCHY) do
        if (h.steamids and h.steamids[sid]) or (h.ranks and h.ranks[grp]) then return h end
    end
    return nil
end

local function GetLocalBanLimitMinutes()
    local p = LocalPlayer()
    return BAN_RANK_LIMITS[string.lower(IsValid(p) and (p:GetUserGroup() or "") or "")] or 0
end

local function FormatTime(min)
    local out = {}
    for _, v in ipairs({ { "mo", 43200 }, { "w", 10080 }, { "d", 1440 }, { "h", 60 }, { "mi", 1 } }) do
        local n = math.floor(min / v[2])
        if n > 0 then table.insert(out, n .. v[1]); min = min % v[2] end
    end
    return table.concat(out)
end

local function FormatLimitText(limit) return limit == math.huge and "perma" or FormatTime(limit) end
local function IsBanType(t) return t == "ban" or t == "perma" end

local function CanUseDurationForType(t, minutes, perma)
    if not IsBanType(t) then return true end
    local limit = GetLocalBanLimitMinutes()
    if limit == math.huge then return true end
    if perma then return false end
    return minutes <= limit
end

local function NotifyBanLimitError(t, minutes, perma)
    if not IsBanType(t) then return end
    local limit = GetLocalBanLimitMinutes()
    if limit == math.huge then return end
    local msg = perma and ("Ваш ранг не может выдавать perma. Лимит: " .. FormatLimitText(limit)) or ("Нельзя выдать " .. FormatTime(minutes) .. ". Лимит: " .. FormatLimitText(limit))
    notification.AddLegacy(msg, 1, 4)
    surface.PlaySound("buttons/button10.wav")
end

local function GetReasonTimeOptions(reason, punishType)
    local opts = CloneTimeOptions(PUNISH_TIME_OPTIONS[reason])
    if not opts or punishType == "perma" then return nil end
    if punishType == "ban" and reason == "0.17" then
        local filtered = {}
        for _, opt in ipairs(opts) do if not opt.perma then table.insert(filtered, opt) end end
        return filtered
    end
    return opts
end

local function SayText(txt, delay)
    timer.Simple(delay or 0, function()
        local p = LocalPlayer()
        if not IsValid(p) then return end
        p:ConCommand('say "' .. string.Replace(txt, "\"", "'") .. '"\n')
    end)
end

local function GetCameraPos()
    local p = LocalPlayer()
    if not IsValid(p) then return vector_origin end
    if AT.CachedViewPos and isvector(AT.CachedViewPos) and RealTime() - AT.CachedViewTime <= 0.25 then return AT.CachedViewPos end
    local eye = EyePos()
    if eye and isvector(eye) then return eye end
    if IsLocalFSpectating() and FSpectate.getSpecEnt then
        local ent = FSpectate.getSpecEnt()
        if IsValid(ent) then return ent:IsPlayer() and ent:GetShootPos() or ent:LocalToWorld(ent:OBBCenter()) end
    end
    eye = p:EyePos()
    return eye and isvector(eye) and eye or p:GetPos()
end

local function GetMenuBindName()
    local name = string.upper(input.GetKeyName(AT.MenuKey or AT.DEFAULT_MENU_KEY) or "B")
    return name == "[" and "LBRACKET" or (name == "]" and "RBRACKET" or name)
end

local function SetMenuBind(keyCode)
    keyCode = math.floor(tonumber(keyCode) or AT.DEFAULT_MENU_KEY)
    if keyCode <= 0 then keyCode = AT.DEFAULT_MENU_KEY end
    AT.MenuKey = keyCode
    cookie.Set("AT_MenuBind", tostring(keyCode))
end

local function GetPlayerJobName(ply)
    if not IsValid(ply) then return "Неизвестно" end
    if team and team.GetName then
        local ok, name = pcall(team.GetName, ply:Team())
        if ok and isstring(name) and name ~= "" then return name end
    end
    return "Неизвестно"
end

local function RunBASpectate(ply)
    if not IsValid(ply) then return end
    local sid, p = ply:SteamID(), LocalPlayer()
    if sid and sid ~= "" and IsValid(p) then
        p:ConCommand("ba spectate " .. sid .. "\n")
        PlayClick()
    end
end

local function StyleScrollbar(sp)
    local vb = sp:GetVBar()
    vb:SetWide(ATScale(5))
    vb:SetHideButtons(true)
    vb.Paint = function() end
    vb.btnGrip:SetCursor("hand")
    vb.btnGrip.Paint = function(s, w, h) 
        if AT.rndx then AT.rndx.Draw(ATScale(8), 0, 0, w, h, ColorAlpha(color_white, s:IsHovered() and 100 or 20)) end 
    end
end

local function DrawCircleAvatar(pnl, ply, size)
    local av, poly = vgui.Create("AvatarImage", pnl), {}
    av:SetSize(size, size)
    av:SetPlayer(ply, 128)
    av:SetPaintedManually(true)
    for i = 0, 48 do
        local a = math.rad((i / 48) * -360)
        poly[i + 1] = { x = size / 2 + math.sin(a) * size / 2, y = size / 2 + math.cos(a) * size / 2 }
    end
    pnl.Paint = function()
        render.ClearStencil()
        render.SetStencilEnable(true)
        render.SetStencilWriteMask(1)
        render.SetStencilTestMask(1)
        render.SetStencilReferenceValue(1)
        render.SetStencilCompareFunction(STENCIL_ALWAYS)
        render.SetStencilPassOperation(STENCIL_REPLACE)
        draw.NoTexture()
        surface.DrawPoly(poly)
        render.SetStencilCompareFunction(STENCIL_EQUAL)
        render.SetStencilPassOperation(STENCIL_KEEP)
        if IsValid(av) then av:PaintManual() end
        render.SetStencilEnable(false)
    end
end

local function CreateHeaderIcon(parent, mat, click, danger)
    return CreateHoverButton(parent, function(s, w, h)
        if s:IsHovered() then PaintHoverFill(0, 0, w, h, danger and THEME.redHover or THEME.hover, 256) end
        surface.SetDrawColor(s:IsHovered() and color_white or THEME.inactive)
        surface.SetMaterial(mat)
        local p = ATScale(4)
        surface.DrawTexturedRect(p, p, w - p * 2, h - p * 2)
    end, click)
end

local function CreatePrimaryButton(parent, text, click)
    local btn = CreateHoverButton(parent, function(s, w, h)
        if Config.Mats.MAINBTN:IsError() then
            PaintSubPanel(0, 0, w, h, ATScale(12))
            if s:IsHovered() then PaintHoverFill(0, 0, w, h, THEME.hover, ATScale(12)) end
        else
            surface.SetDrawColor(color_white)
            surface.SetMaterial(Config.Mats.MAINBTN)
            surface.DrawTexturedRect(0, 0, w, h)
        end
        SafeSimpleText(text, "AT.Bold.24", w * 0.5, h * 0.5, ColorAlpha(color_white, s:IsHovered() and 100 or 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end, click)
    btn:SetCursor("hand")
    return btn
end

local function GetDarkThemeGreen() return Color(math.Clamp(math.floor(THEME.green.r * 0.38), 0, 255), math.Clamp(math.floor(THEME.green.g * 0.38), 0, 255), math.Clamp(math.floor(THEME.green.b * 0.38), 0, 255)) end

local function CreateToggle(parent, getValue, onToggle, x, y)
    local btn, lerpVal = parent:Add("DButton"), (getValue() and 1 or 0)
    btn:SetText(""); btn:SetSize(ATScale(70), ATScale(36))
    if x and y then btn:SetPos(x, y) end
    btn.Paint = function(_, w, h)
        local enabled = getValue()
        lerpVal = Lerp(FrameTime() * 10, lerpVal, enabled and 1 or 0)
        if AT.rndx then
            AT.rndx.Draw(256, 0, 0, w, h, enabled and GetDarkThemeGreen() or THEME.subBg)
            AT.rndx.DrawOutlined(256, 0, 0, w, h, THEME.subBorder, 1)
            AT.rndx.Draw(256, ATScale(4) + (w - ATScale(40)) * lerpVal, ATScale(4), ATScale(28), h - ATScale(8), enabled and THEME.green or ColorAlpha(color_white, 13))
        end
    end
    btn.DoClick = function() PlayClick(); onToggle(not getValue()) end
    return btn
end

local function CreateCard(parent, tall, mb)
    local pnl = parent:Add("DPanel")
    pnl:Dock(TOP); pnl:SetTall(tall); pnl:DockMargin(0, 0, 0, mb or ATScale(16))
    pnl.Paint = function(_, w, h) PaintSubPanel(0, 0, w, h, ATScale(16)) end
    return pnl
end

local function CreateSectionLabel(parent, text)
    local lbl = parent:Add("DLabel")
    lbl:SetText(text); lbl:SetFont("AT.Bold.24"); lbl:SetTextColor(color_white)
    lbl:Dock(TOP); lbl:DockMargin(0, ATScale(4), 0, ATScale(12)); lbl:SizeToContents()
    return lbl
end

local function AngleDeltaAbs(a, b)
    if not a or not b then return 0 end
    return math.abs(math.AngleDifference(a.p or 0, b.p or 0)) + math.abs(math.AngleDifference(a.y or 0, b.y or 0)) + math.abs(math.AngleDifference(a.r or 0, b.r or 0))
end

local function GetTrackedEyeAngles(ply)
    if not IsValid(ply) then return Angle(0, 0, 0) end
    if ply.EyeAngles then
        local ok, ang = pcall(ply.EyeAngles, ply)
        if ok and ang then return ang end
    end
    return ply:GetAngles()
end

local function GetAFKStatusText(ply, afkSeconds)
    local text = "AFK " .. FormatTime(math.floor(math.max(0, afkSeconds) / 60))
    if ply.GetObserverMode and ply:GetObserverMode() ~= OBS_MODE_NONE then
        local targ = ply.GetObserverTarget and ply:GetObserverTarget() or nil
        if IsValid(targ) and targ:IsPlayer() then text = text .. ", Следит за " .. targ:Nick()
        elseif ply.GetNWBool and ply:GetNWBool("Spectating", false) then text = text .. ", В наблюдении" end
    end
    return text
end

local function GetAFKPlayers()
    local out, ct = {}, CurTime()
    for _, ply in ipairs(player.GetAll()) do
        local data = Cache.AFK[ply]
        if IsValid(ply) and data and data.lastActive and (ct - data.lastActive) >= AT.AFK_IDLE_SECONDS then
            table.insert(out, { ply = ply, afkSeconds = ct - data.lastActive })
        end
    end
    table.sort(out, function(a, b)
        if a.afkSeconds == b.afkSeconds then return (IsValid(a.ply) and a.ply:Nick() or "") < (IsValid(b.ply) and b.ply:Nick() or "") end
        return a.afkSeconds > b.afkSeconds
    end)
    return out
end

local function AFK_GetDayKey(ts)
    ts = ts or os.time()
    local d = os.date("*t", ts)
    d.hour, d.min, d.sec = 0, 0, 0
    return os.time(d)
end

local function AFK_SanitizeDays(days)
    for k, v in pairs(days) do
        local n = math.floor(tonumber(v) or 0)
        if n <= 0 then days[k] = nil
        elseif n > 86400 then days[k] = 86400
        else days[k] = n end
    end
end

local function AFK_PruneOldDays(db)
    if not db or not db.days then return end
    local cutoff = AFK_GetDayKey(os.time() - AFKStats.MAX_DAYS_KEPT * 86400)
    for k in pairs(db.days) do
        local kn = tonumber(k)
        if kn and kn < cutoff then db.days[k] = nil end
    end
end

local function AFK_SaveDB()
    if not AFKStats.dbLoaded or not AFKStats.dbCache then return end
    local sid = GetLocalSteamID()
    local p = LocalPlayer()
    if not sid or not IsValid(p) then return end

    AFK_PruneOldDays(AFKStats.dbCache)
    
    HTTP({
        method = "POST",
        url = AT.DISCORD_API_BASE .. "/afk/sync",
        headers = { ["Content-Type"] = "application/json" },
        body = util.TableToJSON({ steamid = sid, nick = p:Nick(), days = AFKStats.dbCache.days })
    })
end

local function AFK_LoadDB(callback)
    if AFKStats.dbLoaded then if callback then callback() end return end
    local sid = GetLocalSteamID()
    if not sid then return end

    http.Fetch(AT.DISCORD_API_BASE .. "/afk/get?steamid=" .. sid, 
        function(body, len, headers, code)
            local ok, parsed = pcall(util.JSONToTable, body)
            local rawDays = (code == 200 and ok and parsed and parsed.ok and parsed.data) and parsed.data.days or {}
            
            local normDays = {}
            for k, v in pairs(rawDays) do
                local n = math.floor(tonumber(v) or 0)
                if n > 0 then normDays[tostring(k)] = math.min(n, 86400) end
            end
            
            AFKStats.dbCache = { days = normDays, createdAt = (parsed and parsed.data and parsed.data.updated_at) or os.time() }
            AFKStats.dbLoaded = true
            if callback then callback() end
        end,
        function()
            AFKStats.dbCache = { days = {}, createdAt = os.time() }
            AFKStats.dbLoaded = true
            if callback then callback() end
        end
    )
end

local function AFK_FlushPending(force)
    if AFKStats.pendingSeconds <= 0 or not AFKStats.dbLoaded then return end

    if not force and AFKStats.pendingSeconds < AFKStats.MIN_SAVE_SECONDS then return end

    local db = AFKStats.dbCache
    local today = tostring(AFK_GetDayKey(os.time()))
    db.days[today] = (db.days[today] or 0) + AFKStats.pendingSeconds
    AFKStats.pendingSeconds = 0
    AFKStats.lastFlushTime = CurTime()
    AFK_SaveDB()
end

concommand.Add("at_afk_debug", function()
    MsgC(Color(120, 200, 255), "\n=== AFK DEBUG ===\n")
    MsgC(color_white, "LocalPlayer SteamID: " .. tostring(GetLocalSteamID()) .. "\n")
    MsgC(color_white, "dbLoaded: " .. tostring(AFKStats.dbLoaded) .. "\n")
    if AFKStats.dbCache and AFKStats.dbCache.days then
        local cnt, total = 0, 0
        for k, v in pairs(AFKStats.dbCache.days) do
            cnt = cnt + 1; total = total + (tonumber(v) or 0)
        end
        MsgC(color_white, "Total days in API Cache: " .. cnt .. ", total seconds: " .. total .. "\n")
    end
    MsgC(color_white, "pendingSeconds: " .. tostring(AFKStats.pendingSeconds) .. "\n")
    MsgC(color_white, "State: " .. tostring(AFKStats.state) .. "\n")
    MsgC(Color(120, 200, 255), "=================\n\n")
end)

concommand.Add("at_afk_reload", function()
    AFKStats.dbLoaded = false
    AFKStats.dbCache = nil
    AFK_LoadDB(function()
        MsgC(Color(80, 220, 120), "[AdminTool] AFK: данные успешно загружены из API.\n")
    end)
end)

local function AFK_WipeStats()
    AFKStats.dbCache = { days = {}, createdAt = os.time() }
    AFKStats.pendingSeconds = 0
    AFKStats.dbLoaded = true
    AFK_SaveDB()
end

local function AFK_StartInit()
    AFKStats.dbLoaded = false
    AFKStats.dbCache = nil
    AFKStats.lastFlushTime = CurTime()

    local TIMER_ID = "AdminTool.AFKChronicleLoad"
    timer.Create(TIMER_ID, 1, 0, function()
        local sid = GetLocalSteamID()
        if sid then
            timer.Remove(TIMER_ID)
            AFK_LoadDB(function()
                AFKStats.lastFlushTime = CurTime()
            end)
        end
    end)
end

local function AFK_GetTotals()
    local db = AFKStats.dbCache
    if not db or not db.days then return { today = 0, week = 0, month = 0, allTime = 0, avgPerDay = 0, dayCount = 0 } end

    local now = os.time()
    local todayKey = AFK_GetDayKey(now)
    local weekCutoff  = AFK_GetDayKey(now - 6  * 86400)
    local monthCutoff = AFK_GetDayKey(now - 29 * 86400)

    local today, week, month, allTime, dayCount = 0, 0, 0, 0, 0
    for k, v in pairs(db.days) do
        local kn, vn = tonumber(k), tonumber(v) or 0
        if kn then
            if vn > 0 then dayCount = dayCount + 1 end
            allTime = allTime + vn
            if kn == todayKey then today = today + vn end
            if kn >= weekCutoff then week = week + vn end
            if kn >= monthCutoff then month = month + vn end
        end
    end

    today   = today   + AFKStats.pendingSeconds
    week    = week    + AFKStats.pendingSeconds
    month   = month   + AFKStats.pendingSeconds
    allTime = allTime + AFKStats.pendingSeconds

    local avgPerDay = dayCount > 0 and (allTime / dayCount) or 0

    return {
        today     = today,
        week      = week,
        month     = month,
        allTime   = allTime,
        avgPerDay = avgPerDay,
        dayCount  = dayCount,
    }
end

local function AFK_GetExternalTotals(days)
    if not days then return { today = 0, week = 0, month = 0, allTime = 0 } end
    local now = os.time()
    local todayKey = AFK_GetDayKey(now)
    local weekCutoff  = AFK_GetDayKey(now - 6  * 86400)
    local monthCutoff = AFK_GetDayKey(now - 29 * 86400)

    local today, week, month, allTime = 0, 0, 0, 0
    for k, v in pairs(days) do
        local kn, vn = tonumber(k), tonumber(v) or 0
        if kn and vn > 0 then
            allTime = allTime + vn
            if kn == todayKey then today = today + vn end
            if kn >= weekCutoff then week = week + vn end
            if kn >= monthCutoff then month = month + vn end
        end
    end
    return { today = today, week = week, month = month, allTime = allTime }
end

local function AFK_GetExternalLastNDays(days, n)
    local out = {}
    local now = os.time()
    local todayKey = AFK_GetDayKey(now)
    local weekdays = { [1] = "Вс", [2] = "Пн", [3] = "Вт", [4] = "Ср", [5] = "Чт", [6] = "Пт", [7] = "Сб" }
    for i = n - 1, 0, -1 do
        local k = AFK_GetDayKey(now - i * 86400)
        local sec = (days and tonumber(days[tostring(k)])) or 0
        local dt = os.date("*t", k)
        table.insert(out, {
            dayKey    = k,
            seconds   = sec,
            label     = weekdays[dt.wday] or "?",
            shortDate = string.format("%02d.%02d", dt.day, dt.month),
            isToday   = k == todayKey,
        })
    end
    return out
end

local function AFK_GetLastNDays(n)
    local db = AFKStats.dbCache
    local out = {}
    local now = os.time()
    local todayKey = AFK_GetDayKey(now)
    local weekdays = { [1] = "Вс", [2] = "Пн", [3] = "Вт", [4] = "Ср", [5] = "Чт", [6] = "Пт", [7] = "Сб" }
    for i = n - 1, 0, -1 do
        local k = AFK_GetDayKey(now - i * 86400)
        local sec = (db and db.days and tonumber(db.days[tostring(k)])) or 0
        if k == todayKey then sec = sec + AFKStats.pendingSeconds end
        local dt = os.date("*t", k)
        table.insert(out, {
            dayKey   = k,
            seconds  = sec,
            label    = weekdays[dt.wday] or "?",
            shortDate = string.format("%02d.%02d", dt.day, dt.month),
            isToday  = k == todayKey,
        })
    end
    return out
end

local function AFK_WipeStats()
    AFKStats.dbCache = { days = {}, createdAt = os.time() }
    AFKStats.pendingSeconds = 0
    AFKStats.dbLoaded = true
    AFK_SaveDB()
end

local function AFK_UpdateFSM()
    local p = LocalPlayer()
    if not IsValid(p) then return end

    local ct = CurTime()
    local ang = p:EyeAngles()
    local isActing = false

    if p:KeyDown(IN_FORWARD) or p:KeyDown(IN_BACK) or p:KeyDown(IN_MOVELEFT) or p:KeyDown(IN_MOVERIGHT) or
       p:KeyDown(IN_JUMP) or p:KeyDown(IN_DUCK) or p:KeyDown(IN_ATTACK) or p:KeyDown(IN_ATTACK2) or
       p:KeyDown(IN_USE) or p:KeyDown(IN_RELOAD) then
        isActing = true
    end

    if AFKStats.lastAng then
        local dp = math.abs(math.AngleDifference(ang.p, AFKStats.lastAng.p))
        local dy = math.abs(math.AngleDifference(ang.y, AFKStats.lastAng.y))
        if p:KeyDown(IN_LEFT) or p:KeyDown(IN_RIGHT) then dy = 0 end
        if dp > 0.5 or dy > 0.5 then isActing = true end
    end
    AFKStats.lastAng = ang

    if isActing then
        if AFKStats.state == "AFK" then
            local delta = ct - math.max(AFKStats.afkSince, AFKStats.lastFlushTime)
            if delta > 0 then AFKStats.pendingSeconds = AFKStats.pendingSeconds + delta end
            AFK_FlushPending(true)
            AFKStats.wmFlashTime = ct + 1.5
        end
        AFKStats.state = "ACTIVE"
        AFKStats.idleSince = ct
        AFKStats.afkSince = 0
        AFKStats.afkReason = ""
        return
    end

    if AFKStats.state == "ACTIVE" then
        AFKStats.state = "IDLE"
        AFKStats.idleSince = ct
        AFKStats.afkReason = "бездействие"
    elseif AFKStats.state == "IDLE" then
        if ct - AFKStats.idleSince >= AFKStats.AFK_THRESHOLD then
            AFKStats.state = "AFK"
            AFKStats.afkSince = ct
            AFKStats.lastFlushTime = ct
            AFKStats.wmFlashTime = ct + 1.5
        end
    elseif AFKStats.state == "AFK" then
        if ct - AFKStats.lastFlushTime >= AFKStats.FLUSH_INTERVAL then
            AFKStats.pendingSeconds = AFKStats.pendingSeconds + (ct - AFKStats.lastFlushTime)
            AFKStats.lastFlushTime = ct
            AFK_FlushPending(false)
        end
    end
end

local function AFK_GetCurrentAFKTime()
    if AFKStats.state ~= "AFK" then return 0 end
    return CurTime() - AFKStats.afkSince
end

local function PushPropLog(entry)
    Cache.PROP_LOG_BUFFER[AT.PROP_LOG_NEXT] = entry
    AT.PROP_LOG_NEXT = (AT.PROP_LOG_NEXT % AT.PROP_LOG_BUFFER_SIZE) + 1
    AT.PROP_LOG_COUNT = math.min(AT.PROP_LOG_COUNT + 1, AT.PROP_LOG_BUFFER_SIZE)
    AT.PROP_LOG_VERSION = AT.PROP_LOG_VERSION + 1
end

local function GetPropLogEntry(indexFromNewest)
    if indexFromNewest < 1 or indexFromNewest > AT.PROP_LOG_COUNT then return nil end
    local idx = AT.PROP_LOG_NEXT - indexFromNewest
    if idx <= 0 then idx = idx + AT.PROP_LOG_BUFFER_SIZE end
    return Cache.PROP_LOG_BUFFER[idx]
end

local function GetPropLogSnapshot()
    local out = {}
    for i = 1, AT.PROP_LOG_COUNT do
        local e = GetPropLogEntry(i)
        if e then table.insert(out, e) end
    end
    return out
end

local function ClearPropLogs()
    table.Empty(Cache.PROP_LOG_BUFFER); table.Empty(Cache.PROP_LOG_TRACK)
    AT.PROP_LOG_NEXT, AT.PROP_LOG_COUNT, AT.PROP_LOG_VERSION = 1, 0, AT.PROP_LOG_VERSION + 1
end

local function RegisterPropSpawnBurst(ply)
    if not IsValid(ply) then return 0 end
    local sid, ct = ply:SteamID() or ("IDX_" .. ply:EntIndex()), CurTime()
    Cache.PROP_LOG_TRACK[sid] = Cache.PROP_LOG_TRACK[sid] or {}
    local bucket = Cache.PROP_LOG_TRACK[sid]
    table.insert(bucket, ct)
    local keepFrom = ct - AT.PROP_LOG_WINDOW
    while bucket[1] and bucket[1] < keepFrom do table.remove(bucket, 1) end
    return #bucket
end

local function ValidatePropOwner(owner) return IsValid(owner) and owner:IsPlayer() and owner:Nick() ~= nil end

local function GetPropLogOwner(ent)
    if not IsValid(ent) then return nil end
    local owner, ok
    local function Try(method, ...)
        if not method then return nil end
        ok, owner = pcall(method, ent, ...)
        return ok and ValidatePropOwner(owner) and owner or nil
    end

    owner = Try(ent.CPPIGetOwner) or Try(ent.Getowning_ent)
    if owner then return owner end

    for _, key in ipairs({ "Owner", "owner", "Creator", "creator", "Player", "player" }) do
        if ent.GetNWEntity then owner = ent:GetNWEntity(key); if ValidatePropOwner(owner) then return owner end end
        if ent.GetNW2Entity then owner = ent:GetNW2Entity(key); if ValidatePropOwner(owner) then return owner end end
    end

    owner = Try(ent.GetOwner) or Try(ent.GetCreator)
    if owner then return owner end

    local entPos, best, bestDist = ent:GetPos(), nil, 48400
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and not ply:IsDormant() then
            local dist = ply:GetPos():DistToSqr(entPos)
            if dist <= bestDist then best, bestDist = ply, dist end
        end
    end
    return ValidatePropOwner(best) and best or nil
end

local function QueuePropLog(ent)
    if not IsValid(ent) or CurTime() < AT.PROP_LOG_READY_TIME then return end
    local class = ent:GetClass()
    if not Config.PROP_LOG_CLASS_FILTER[class] then return end
    local idx = ent:EntIndex()
    if Cache.PROP_LOGGED_ENTS[idx] then return end
    Cache.PROP_LOGGED_ENTS[idx] = true

    timer.Simple(0.12, function()
        if not IsValid(ent) then return end
        local owner = GetPropLogOwner(ent)
        local isOwner = ValidatePropOwner(owner)
        local model = ent.GetModel and ent:GetModel() or class
        if not isstring(model) or model == "" then model = class end
        local burstCount = isOwner and RegisterPropSpawnBurst(owner) or 0
        PushPropLog({
            createdAt = RealTime(), timeText = os.date("%H:%M:%S"),
            nick = isOwner and owner:Nick() or "Неизвестно", steamid = isOwner and owner:SteamID() or "UNKNOWN",
            model = model, class = class, suspicious = burstCount >= AT.PROP_LOG_SUSPICIOUS_COUNT, burstCount = burstCount
        })
    end)
end

local function GetAutoAdvertCooldown() return math.Clamp(tonumber(AT.autoAdvertCooldownMinutes) or 10, 10, 60) * 60 end
local StopAutoAdvertSequence, ResetAutoAdvertCooldown

do
    local PANEL = {}
    function PANEL:Init()
        self:SetTitle(""); self:ShowCloseButton(false); self:SetDraggable(false)
        self:MakePopup(); self:SetAlpha(0); self:AlphaTo(255, 0.2)
        self.StartTime = SysTime()
    end
    function PANEL:Close()
        if self.Closing then return end; self.Closing = true
        if IsValid(self.RightDrawer) and self.RightDrawer.CloseDrawer then self.RightDrawer:CloseDrawer(true) end
        self:AlphaTo(0, 0.2, 0, function() if IsValid(self) then self:Remove() end end)
    end
    function PANEL:Paint(w, h)
        Derma_DrawBackgroundBlur(self, self.StartTime)
        if AT.rndx then AT.rndx.Draw(0, 0, 0, w, h, THEME.bg) end
    end
    vgui.Register("AT_ArenaFrame", PANEL, "DFrame")
end

local function CreateBaseFrame(onKey, w, h)
    local f = vgui.Create("AT_ArenaFrame")
    f:SetSize(w or ScrW(), h or ScrH()); f:SetPos(0, 0)
    f.OnKeyCodePressed = function(s, key)
        if key == KEY_ESCAPE and IsValid(s.RightDrawer) then s.RightDrawer:CloseDrawer(); return end
        if onKey then onKey(s, key) end
    end
    return f
end

local function CreateHeaderProfile(parent, ply)
    if not IsValid(ply) then return end
    local box = parent:Add("DPanel"); box:SetWide(ATScale(380)); box:Dock(LEFT); box:DockMargin(ATScale(34), 0, 0, 0); box.Paint = nil
    local avatarSize = ATScale(58)
    local av = box:Add("DPanel"); av:SetSize(avatarSize, avatarSize); av:SetPos(0, 0)
    DrawCircleAvatar(av, ply, avatarSize)

    local function MakeCopy(text, font, col, y, notifyText)
        local btn = box:Add("DButton"); btn:SetText(""); btn:SetPos(ATScale(76), y)
        surface.SetFont(font)
        local tw, th = surface.GetTextSize(text)
        btn:SetSize(tw + 4, th + 2)
        local hov = 0
        btn.Paint = function(s)
            hov = Lerp(FrameTime() * 10, hov, s:IsHovered() and 1 or 0)
            SafeSimpleText(text, font, 0, 0, LCol(col, color_white, hov), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
        btn.DoClick = function() SetClipboardText(text); notification.AddLegacy(notifyText, 0, 2); PlayClick() end
    end

    MakeCopy(ply:Nick(), "AT.Bold.22", color_white, 0, "Ник скопирован")
    MakeCopy(ply:SteamID(), "AT.Light.18", THEME.green, ATScale(22), "SteamID скопирован")
    MakeCopy(string.upper(ply:GetUserGroup() or "player"), "AT.Light.16", THEME.textSub, ATScale(40), "Ранг скопирован")
    return box
end

local function OpenDiscordGateFrame()
    if AT.discordAuthorized then return end
    if IsValid(UI_Frames.DiscordGate) then UI_Frames.DiscordGate:MakePopup(); return end

    UI_Frames.DiscordGate = CreateBaseFrame(nil)
    UI_Frames.DiscordGate:SetKeyboardInputEnabled(true); UI_Frames.DiscordGate:SetMouseInputEnabled(true)

    local panel = UI_Frames.DiscordGate:Add("DPanel")
    panel:SetSize(ATScale(700), ATScale(320))
    panel:SetPos(ScrW() * 0.5 - ATScale(350), ScrH() * 0.5 - ATScale(160))
    panel.Paint = function(_, w, h)
        PaintSubPanel(0, 0, w, h, ATScale(16))
        SafeSimpleText("Требуется Discord-авторизация", "AT.Bold.30", w * 0.5, ATScale(42), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        SafeSimpleText("Чтобы получить доступ к функциям AdminTool, авторизуйся через Discord.", "AT.Light.18", w * 0.5, ATScale(96), THEME.textSub, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        SafeSimpleText("Будет проверено, находишься ли ты на нашем Discord-сервере.", "AT.Light.18", w * 0.5, ATScale(126), THEME.textSub, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local status, statusColor = "Статус: не авторизован", THEME.textSub
        if AT.discordAuthorized then
            status = "Статус: доступ разрешён" .. (AT.discordAuthUserTag ~= "" and (" (" .. AT.discordAuthUserTag .. ")") or "")
            statusColor = THEME.green
        elseif AT.discordAuthPending then
            status = "Статус: ожидание подтверждения в браузере"
            statusColor = THEME.gold
        end
        SafeSimpleText(status, "AT.Bold.18", w * 0.5, ATScale(182), statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local btnAuth = CreatePrimaryButton(panel, "Авторизоваться через Discord", StartDiscordAuthorization)
    btnAuth:SetSize(ATScale(360), ATScale(54))
    btnAuth:SetPos(panel:GetWide() * 0.5 - ATScale(180), ATScale(225))
end

local function CheckSavedDiscordAccess()
    if AT.discordAutoCheckStarted then return end
    AT.discordAutoCheckStarted = true
    local steamid = GetLocalSteamID()
    if not steamid then AT.discordAutoCheckStarted = false; return end

    http.Fetch(AT.DISCORD_API_BASE .. "/auth/check?steamid=" .. steamid, function(body)
        AT.discordAutoCheckStarted = false
        local data = util.JSONToTable(body or "")
        if not istable(data) or data.ok ~= true then
            SetDiscordAuthorized(false, "")
            if not AT.discordGateOpenTried then AT.discordGateOpenTried = true; OpenDiscordGateFrame() end
            return
        end
        if data.status == "approved" then SetDiscordAuthorized(true, data.user_tag or ""); CloseDiscordGate(); return end
        SetDiscordAuthorized(false, "")
        if not AT.discordGateOpenTried then AT.discordGateOpenTried = true; OpenDiscordGateFrame() end
    end, function()
        AT.discordAutoCheckStarted = false; SetDiscordAuthorized(false, "")
        if not AT.discordGateOpenTried then AT.discordGateOpenTried = true; OpenDiscordGateFrame() end
    end)
end

local function BootstrapDiscordAuthCheck()
    if AT.discordBootCheckStarted then return end
    AT.discordBootCheckStarted = true
    local function TryStartCheck()
        local steamid = GetLocalSteamID()
        if not steamid then
            AT.discordBootRetryCount = AT.discordBootRetryCount + 1
            if AT.discordBootRetryCount >= AT.discordBootMaxRetries then
                AT.discordBootCheckStarted = false; SetDiscordAuthorized(false, "")
                if not AT.discordGateOpenTried then AT.discordGateOpenTried = true; OpenDiscordGateFrame() end
                return
            end
            timer.Simple(0.5, TryStartCheck); return
        end
        CheckSavedDiscordAccess()
    end
    TryStartCheck()
end

local function OpenAboutMenu()
    if IsValid(UI_Frames.About) then return UI_Frames.About:Close() end
    UI_Frames.About = CreateBaseFrame(nil)
    local pad, headerH = UI.body_pad(), UI.header_h()
    local header = UI_Frames.About:Add("DPanel")
    header:Dock(TOP); header:SetTall(headerH); header:DockPadding(pad, pad, pad, pad); header.Paint = nil

    local right = header:Add("DPanel"); right:SetWide(ATScale(100)); right:Dock(RIGHT)
    right.Paint = function(_, w, h) PaintSubPanel(0, 0, w, h, 256) end
    right.PerformLayout = function(s, w, h)
        local size = h - ATScale(28)
        if IsValid(s.BtnInfo) then s.BtnInfo:SetSize(size, size); s.BtnInfo:SetPos(ATScale(14), ATScale(14)) end
        if IsValid(s.BtnClose) then s.BtnClose:SetSize(size, size); s.BtnClose:SetPos(w - size - ATScale(14), ATScale(14)) end
    end
    right.BtnInfo = CreateHeaderIcon(right, Config.Mats.INFO, function() end, false)
    right.BtnClose = CreateHeaderIcon(right, Config.Mats.CLOSE, function() UI_Frames.About:Close() end, true)

    local title = UI_Frames.About:Add("DLabel")
    title:SetText("О AdminTool"); title:SetFont("AT.Bold.36"); title:SetTextColor(color_white); title:SizeToContents()
    title:SetPos(ScrW() * 0.5 - title:GetWide() * 0.5, headerH + ATScale(150))

    local box = UI_Frames.About:Add("DPanel")
    box:SetSize(ATScale(620), ATScale(320)); box:SetPos(ScrW() * 0.5 - ATScale(310), ScrH() * 0.5 - ATScale(200))
    box.Paint = function(_, w, h)
        PaintSubPanel(0, 0, w, h, ATScale(8))
        local y = ATScale(22)
        for _, line in ipairs({
            "AdminTool - многофункциональный клиентский инструмент", "для быстрого доступа к основным рабочим возможностям прямо в игре.", "",
            "AdminTool упрощает повседневную работу администрации,", "ускоряет выполнение рутинных действий и делает модерацию", "более удобной, быстрой и наглядной прямо во время игрового процесса.", "",
            GetMenuBindName() .. " - открыть главное меню AdminTool", "E - открыть меню взаимодействия с игроком"
        }) do
            SafeSimpleText(line, "AT.Light.20", ATScale(22), y, line == "" and THEME.textSub or color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            y = y + ATScale(30)
        end
    end
    local confirm = CreatePrimaryButton(UI_Frames.About, "Понятно, спасибо", function() UI_Frames.About:Close() end)
    confirm:SetSize(ATScale(450), ATScale(64)); confirm:SetPos(ScrW() * 0.5 - ATScale(225), box.y + box:GetTall() + ATScale(18))
end

local mat_tbank = Material("adonate/tbank.png", "smooth noclamp")
local mat_pressf = Material("adonate/pressf.png", "smooth noclamp")

local DONATE_METHODS = {
    {
        name = "T-Bank",
        desc = "Прямой перевод\nБез комиссии",
        mat = Material("adonate/tbank.png", "smooth noclamp"),
        color = Color(255, 221, 45),
        url = "https://www.tinkoff.ru/rm/r_EDjLvhPfRT.IRRknUITWN/UA7ja92124"
    },
    {
        name = "PressF",
        desc = "Оплата через СБП\nБанки РФ",
        mat = Material("adonate/pressf.png", "smooth noclamp"),
        color = Color(255, 25, 25),
        url = "https://pressf.com/foundet/donate"
    },
}

local function OpenDonateMenu()
    if IsValid(UI_Frames.Donate) then return UI_Frames.Donate:Close() end
    UI_Frames.Donate = CreateBaseFrame(nil)

    local bg = UI_Frames.Donate:Add("DPanel")
    bg:SetSize(ScrW(), ScrH())
    bg:SetPos(0, 0)
    bg.Paint = function(_, w, h)
        if AT.rndx then 
            AT.rndx.DrawBlur(0, 0, w, h, 0, 0, 0, 0, 0, 1.5) 
            AT.rndx.Draw(0, 0, 0, w, h, Color(10, 10, 12, 220)) 
        end
    end

    local btnW, btnH = ATScale(280), ATScale(210)
    local gap = ATScale(24)
    local headerH, bottomPad = ATScale(160), ATScale(30)

    local cols = math.min(#DONATE_METHODS, 3)
    if cols < 1 then cols = 1 end
    local rows = math.max(math.ceil(#DONATE_METHODS / cols), 1)
    
    local boxW = math.max(ATScale(720), (cols * btnW) + ((cols + 1) * gap))
    local boxH = headerH + (rows * btnH) + ((rows - 1) * gap) + bottomPad

    local box = UI_Frames.Donate:Add("DPanel")
    box:SetSize(boxW, boxH)
    box:SetPos(ScrW() * 0.5 - boxW * 0.5, ScrH() * 0.5 - boxH * 0.5)
    box.Paint = function(_, w, h)
        if AT.rndx then
            AT.rndx.Draw(ATScale(24), 0, 0, w, h, Color(22, 22, 24, 250))
            AT.rndx.DrawOutlined(ATScale(24), 0, 0, w, h, Color(255, 255, 255, 12), 1)
        end
        SafeSimpleText("Поддержка разработчика AdminTool", "AT.Bold.36", w * 0.5, ATScale(40), THEME.gold, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        SafeSimpleText("Выберите удобный способ оплаты", "AT.Light.20", w * 0.5, ATScale(85), THEME.textSub, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    local closeBtn = CreateHeaderIcon(box, Config.Mats.CLOSE, function() UI_Frames.Donate:Close() end, true)
    closeBtn:SetSize(ATScale(36), ATScale(36))
    closeBtn:SetPos(boxW - ATScale(52), ATScale(24))

    local wrap = box:Add("DPanel")
    wrap:SetPos(0, headerH)
    wrap:SetSize(boxW, boxH - headerH)
    wrap.Paint = nil

    local btns = {}
    for _, method in ipairs(DONATE_METHODS) do
        local btn = CreateHoverButton(wrap, function(s, w, h)
            local hov = s:IsHovered()
            if AT.rndx then
                AT.rndx.Draw(ATScale(18), 0, 0, w, h, Color(32, 32, 36, 255))
                AT.rndx.DrawOutlined(ATScale(18), 0, 0, w, h, hov and method.color or Color(255, 255, 255, 10), hov and 2 or 1)
                if hov then AT.rndx.Draw(ATScale(18), 0, 0, w, h, ColorAlpha(method.color, 15)) end
                if method.mat and not method.mat:IsError() then 
                    AT.rndx.DrawMaterial(ATScale(8), w * 0.5 - ATScale(36), ATScale(32), ATScale(72), ATScale(72), color_white, method.mat) 
                end
            end
            SafeSimpleText(method.name, "AT.Bold.24", w * 0.5, ATScale(125), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            
            if draw and draw.DrawText then
                draw.DrawText(method.desc, "AT.Light.16", w * 0.5, ATScale(160), THEME.textSub, TEXT_ALIGN_CENTER)
            end
        end, function() 
            PlayClick()
            if method.url and string.Trim(method.url) ~= "" then gui.OpenURL(method.url) end
            notification.AddLegacy("Открываем страницу оплаты: " .. method.name, 0, 3) 
        end)
        btn:SetSize(btnW, btnH)
        table.insert(btns, btn)
    end

    wrap.PerformLayout = function(s, w, h)
        if #btns == 0 then return end
        for i, btn in ipairs(btns) do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            
            local itemsInRow = cols
            if row == rows - 1 then itemsInRow = #btns - (row * cols) end
            
            local rowTotalW = itemsInRow * btnW + (itemsInRow - 1) * gap
            local rowStartX = (w - rowTotalW) / 2

            btn:SetPos(rowStartX + col * (btnW + gap), row * (btnH + gap))
        end
    end
end

local function CreateMainHeader(frame, titleText, subtitleText, profilePly)
    local pad, headerH = UI.body_pad(), UI.header_h()
    local header = frame:Add("DPanel")
    header:Dock(TOP); header:SetTall(headerH); header:DockPadding(pad, pad, pad, pad); header.Paint = nil

    local title = header:Add("DLabel")
    title:SetText(titleText or ""); title:SetFont("AT.Bold.45"); title:SetTextColor(color_white); title:Dock(LEFT)
    title:DockMargin(0, ATScale(6), ATScale(24), 0); title:SizeToContents()

    if subtitleText and subtitleText ~= "" then
        local sub = header:Add("DLabel")
        sub:SetText(subtitleText); sub:SetFont("AT.Light.18"); sub:SetTextColor(THEME.textSub); sub:Dock(LEFT)
        sub:DockMargin(0, ATScale(34), ATScale(20), 0); sub:SizeToContents()
    end

    if IsValid(profilePly) then CreateHeaderProfile(header, profilePly) end

    local right = header:Add("DPanel"); right:SetWide(ATScale(100)); right:Dock(RIGHT)
    right.Paint = function(_, w, h) PaintSubPanel(0, 0, w, h, 256) end
    right.PerformLayout = function(s, w, h)
        local size = h - ATScale(28)
        if IsValid(s.BtnInfo) then s.BtnInfo:SetSize(size, size); s.BtnInfo:SetPos(ATScale(14), ATScale(14)) end
        if IsValid(s.BtnClose) then s.BtnClose:SetSize(size, size); s.BtnClose:SetPos(w - size - ATScale(14), ATScale(14)) end
    end
    right.BtnInfo = CreateHeaderIcon(right, Config.Mats.INFO, OpenAboutMenu, false)
    right.BtnClose = CreateHeaderIcon(right, Config.Mats.CLOSE, function() frame:Close() end, true)
    return header
end

local function CreateSidebarButton(parent, name, index, getActive, click, isGold)
    local btn, hover = parent:Add("DButton"), 0
    btn:SetText(""); btn:Dock(TOP); btn:DockMargin(0, 0, 0, ATScale(14)); btn:SetTall(ATScale(64))
    btn.Paint = function(s, w, h)
        local active = getActive() == index
        hover = Lerp(FrameTime() * 10, hover, s:IsHovered() and 1 or 0)
        
        if isGold then
            if AT.rndx then
                AT.rndx.Draw(ATScale(16), 0, 0, w, h, THEME.subBg)
                AT.rndx.DrawOutlined(ATScale(16), 0, 0, w, h, THEME.gold, 1)
                if s:IsHovered() then PaintHoverFill(0, 0, w, h, ColorAlpha(THEME.gold, 15), ATScale(16)) end
            end
            SafeSimpleText(name, "AT.Bold.22", ATScale(20), h * 0.5, THEME.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        else
            PaintSubPanel(0, 0, w, h, ATScale(16))
            if active then
                PaintHoverFill(0, 0, w, h, Color(255, 255, 255, 18), ATScale(16))
                if AT.rndx then AT.rndx.Draw(ATScale(16), 0, 0, ATScale(6), h, THEME.green) end
            elseif hover > 0.01 then
                PaintHoverFill(0, 0, w, h, Color(255, 255, 255, math.Round(14 * hover)), ATScale(16))
            end
            SafeSimpleText(name, active and "AT.Bold.22" or "AT.Bold.20", ATScale(20), h * 0.5, active and color_white or LCol(THEME.textSub, color_white, hover), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    btn.DoClick = function() PlayClick(); if click then click(index) end end
    return btn
end

local function CreateDrawer(parent, titleText, subtitleText, width)
    if not IsValid(parent) then return end
    width = width or ATScale(460)
    if IsValid(parent.RightDrawer) and parent.RightDrawer.CloseDrawer then parent.RightDrawer:CloseDrawer(true) end

    local drawer = vgui.Create("AT_ArenaFrame")
    drawer:SetSize(width, ScrH()); drawer:SetPos(ScrW(), 0); drawer.ParentFrame = parent
    function drawer:CloseDrawer(skip)
        if self.Closing then return end; self.Closing = true
        local function done() if IsValid(self.ParentFrame) then self.ParentFrame.RightDrawer = nil end; if IsValid(self) then self:Remove() end end
        if skip then return done() end
        self:AlphaTo(0, 0.15, 0); self:MoveTo(ScrW(), 0, 0.15, 0, -1, done)
    end
    drawer.OnKeyCodePressed = function(_, key) if key == KEY_ESCAPE then drawer:CloseDrawer() end end
    drawer.Paint = function(_, w, h) if AT.rndx then AT.rndx.Draw(0, 0, 0, w, h, Color(16, 16, 16, 245)) end end

    local header = drawer:Add("DPanel"); header:Dock(TOP); header:SetTall(UI.header_h()); header:DockPadding(UI.body_pad(), UI.body_pad(), UI.body_pad(), UI.body_pad()); header.Paint = nil
    local right = header:Add("DPanel"); right:SetWide(ATScale(52)); right:Dock(RIGHT)
    right.Paint = function(_, w, h) PaintSubPanel(0, 0, w, h, 256) end
    right.PerformLayout = function(s, w, h) if IsValid(s.BtnClose) then s.BtnClose:SetSize(w - ATScale(14), w - ATScale(14)); s.BtnClose:SetPos(ATScale(7), (h - (w - ATScale(14))) * 0.5) end end
    right.BtnClose = CreateHeaderIcon(right, Config.Mats.CLOSE, function() drawer:CloseDrawer() end, true)

    local textWrap = header:Add("DPanel"); textWrap:Dock(LEFT); textWrap:SetWide(width - UI.body_pad() * 2 - right:GetWide() - ATScale(20)); textWrap.Paint = nil
    local title = textWrap:Add("DLabel"); title:SetText(titleText or ""); title:SetFont("AT.Bold.30"); title:SetTextColor(color_white); title:SizeToContents(); title:SetPos(0, ATScale(2))
    if subtitleText and subtitleText ~= "" then
        local sub = textWrap:Add("DLabel"); sub:SetText(subtitleText); sub:SetFont("AT.Light.16"); sub:SetTextColor(THEME.textSub); sub:SizeToContents(); sub:SetPos(0, title:GetTall() + ATScale(6))
    end
    local body = drawer:Add("DScrollPanel"); body:Dock(FILL); body:DockMargin(UI.body_pad(), ATScale(8), UI.body_pad() - ATScale(8), UI.body_pad()); StyleScrollbar(body)

    parent.RightDrawer = drawer; drawer:MoveTo(ScrW() - width, 0, UI.anim, 0, -1)
    return drawer, body
end

local function OpenWatermarkSettings()
    if not IsValid(UI_Frames.AdminTool) then return end
    if IsValid(UI_Frames.WMSettings) and UI_Frames.WMSettings.CloseDrawer then UI_Frames.WMSettings:CloseDrawer(true) end
    local drawer, body = CreateDrawer(UI_Frames.AdminTool, "Позиция Watermark", "Перетащите индикатор на мини-экране", ATScale(460))
    UI_Frames.WMSettings = drawer
    CreateSectionLabel(body, "Интерактивный экран")

    local card = CreateCard(body, ATScale(300), ATScale(14))
    card.Paint = function(_, w, h) PaintSubPanel(0, 0, w, h, ATScale(14)) end

    local aspect = ScrH() / ScrW()
    local screenW = ATScale(320)
    local screenH = screenW * aspect
    card:SetTall(screenH + ATScale(80))

    local monitorBg = card:Add("DPanel")
    monitorBg:SetSize(screenW, screenH)
    monitorBg.Paint = function(_, w, h)
        if AT.rndx then
            AT.rndx.Draw(ATScale(8), 0, 0, w, h, Color(20, 20, 20))
            AT.rndx.DrawOutlined(ATScale(8), 0, 0, w, h, THEME.subBorder, 1)
        end
        
        surface.SetDrawColor(255, 255, 255, 5)
        for i = 1, 5 do 
            surface.DrawLine(0, h * i / 6, w, h * i / 6)
            surface.DrawLine(w * i / 6, 0, w * i / 6, h) 
        end
        SafeSimpleText("Экран игрока", "AT.Bold.16", w * 0.5, h * 0.5, Color(255, 255, 255, 15), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local dummyW = math.max((ATScale(360) / ScrW()) * screenW, ATScale(40))
    local dummyH = math.max((ATScale(44) / ScrH()) * screenH, ATScale(12))

    local dummy = monitorBg:Add("DPanel")
    dummy:SetSize(dummyW, dummyH)

    local curRelX = cookie.GetNumber("AT_WatermarkRelX", 0.5)
    local curRelY = cookie.GetNumber("AT_WatermarkRelY", 0.015)
    dummy:SetPos(curRelX * (screenW - dummyW), curRelY * (screenH - dummyH))

    dummy.Paint = function(s, w, h)
        if AT.rndx then AT.rndx.Draw(ATScale(4), 0, 0, w, h, THEME.green) end
        SafeSimpleText("WM", "AT.Bold.14", w * 0.5, h * 0.5, THEME.subBg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if s.Dragging or s:IsHovered() then PaintHoverFill(0, 0, w, h, Color(255, 255, 255, 50), ATScale(4)) end
    end

    dummy.OnCursorEntered = function(s) s:SetCursor("sizeall") end

    dummy.OnMousePressed = function(s, code)
        if code == MOUSE_LEFT then
            s.Dragging = true
            local cx, cy = s:CursorPos()
            s.DragOffset = { x = cx, y = cy }
            s:MouseCapture(true)
        end
    end

    dummy.OnMouseReleased = function(s, code)
        if code == MOUSE_LEFT then 
            s.Dragging = false
            s:MouseCapture(false) 
        end
    end

    dummy.Think = function(s)
        if s.Dragging then
            local mx, my = monitorBg:CursorPos()
            local targetX = math.Clamp(mx - s.DragOffset.x, 0, screenW - dummyW)
            local targetY = math.Clamp(my - s.DragOffset.y, 0, screenH - dummyH)
            s:SetPos(targetX, targetY)

            local newRelX = targetX / math.max(screenW - dummyW, 1)
            local newRelY = targetY / math.max(screenH - dummyH, 1)

            cookie.Set("AT_WatermarkRelX", tostring(newRelX))
            cookie.Set("AT_WatermarkRelY", tostring(newRelY))
        end
    end

    local resetBtn = CreateActionButton(card, "Вернуть наверх (Центр)", ATScale(240), ATScale(40), function()
        cookie.Set("AT_WatermarkRelX", tostring(0.5))
        cookie.Set("AT_WatermarkRelY", tostring(0.015))
        dummy:SetPos(0.5 * (screenW - dummyW), 0.015 * (screenH - dummyH))
    end)

    card.PerformLayout = function(s, w, h)
        monitorBg:SetPos(w * 0.5 - screenW * 0.5, ATScale(16))
        resetBtn:SetPos(w * 0.5 - resetBtn:GetWide() * 0.5, screenH + ATScale(28))
    end
end

local function OpenAutoAdvertSettings()
    if not IsValid(UI_Frames.AdminTool) then return end
    if IsValid(UI_Frames.AutoAdvert) and UI_Frames.AutoAdvert.CloseDrawer then UI_Frames.AutoAdvert:CloseDrawer(true) end
    local drawer, body = CreateDrawer(UI_Frames.AdminTool, "Настройка авто-рекламы", "Выберите интервал отправки", ATScale(430))
    UI_Frames.AutoAdvert = drawer
    CreateSectionLabel(body, "Интервал отправки")

    local pnl = CreateCard(body, ATScale(96), ATScale(14))
    local lbl = pnl:Add("DLabel"); lbl:SetText("Пауза между циклами авто-рекламы"); lbl:SetFont("AT.Bold.18"); lbl:SetTextColor(color_white); lbl:SetPos(ATScale(14), ATScale(12)); lbl:SizeToContents()
    local valueLbl = pnl:Add("DLabel"); valueLbl:SetFont("AT.Bold.18"); valueLbl:SetTextColor(THEME.gold); valueLbl:SetContentAlignment(6); valueLbl:SetWide(ATScale(96))
    local sl = pnl:Add("DSlider"); sl:SetTrapInside(true)
    pnl.PerformLayout = function(_, w, h) valueLbl:SetPos(w - ATScale(110), ATScale(12)); sl:SetPos(ATScale(14), h - ATScale(34)); sl:SetSize(w - ATScale(28), ATScale(22)) end

    local startMinutes = math.Clamp(cookie.GetNumber("AT_AutoAdvertCooldownMinutes", 10), 10, 60)
    sl:SetSlideX((startMinutes - 10) / 50); valueLbl:SetText(startMinutes .. " мин")
    SetStandardSliderPaint(sl)
    sl.OnValueChanged = function(_, val)
        local minutes = math.Clamp(math.Round(10 + val * 50), 10, 60)
        AT.autoAdvertCooldownMinutes = minutes; cookie.Set("AT_AutoAdvertCooldownMinutes", tostring(minutes)); valueLbl:SetText(minutes .. " мин")
        if AT.showAutoAdvert and ResetAutoAdvertCooldown then ResetAutoAdvertCooldown(true) end
    end

    local info = CreateCard(body, ATScale(94), 0); info.Paint = function(_, w, h) PaintSubPanel(0, 0, w, h, ATScale(14)) end
    local infoTitle = info:Add("DLabel"); infoTitle:SetText("Сообщения внутри одного цикла отправляются"); infoTitle:SetFont("AT.Light.16"); infoTitle:SetTextColor(color_white); infoTitle:SetWrap(true); infoTitle:SetAutoStretchVertical(true)
    local infoDesc = info:Add("DLabel"); infoDesc:SetText("по-прежнему с задержкой " .. AT.AUTO_ADVERT_STEP_DELAY .. " сек между каждым сообщением."); infoDesc:SetFont("AT.Light.16"); infoDesc:SetTextColor(THEME.textSub); infoDesc:SetWrap(true); infoDesc:SetAutoStretchVertical(true)
    info.PerformLayout = function(s, w)
        local textW = w - ATScale(32)
        infoTitle:SetPos(ATScale(16), ATScale(14)); infoTitle:SetWide(textW); infoTitle:SizeToContentsY()
        infoDesc:SetPos(ATScale(16), infoTitle.y + infoTitle:GetTall() + ATScale(8)); infoDesc:SetWide(textW); infoDesc:SizeToContentsY()
        s:SetTall(infoDesc.y + infoDesc:GetTall() + ATScale(14))
    end
end

local function OpenMenuBindSettings()
    if not IsValid(UI_Frames.AdminTool) then return end
    if IsValid(UI_Frames.MenuBind) and UI_Frames.MenuBind.CloseDrawer then UI_Frames.MenuBind:CloseDrawer(true) end
    local drawer, body = CreateDrawer(UI_Frames.AdminTool, "Клавиша открытия меню", "Выбери кнопку для изменения бинда", ATScale(460))
    UI_Frames.MenuBind = drawer; local waitingForKey, currentKey = false, AT.MenuKey

    local preview = CreateCard(body, ATScale(96), ATScale(14))
    preview.Paint = function(_, w, h)
        PaintSubPanel(0, 0, w, h, ATScale(14))
        SafeSimpleText("Текущая клавиша", "AT.Light.16", ATScale(16), ATScale(16), THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        SafeSimpleText(GetMenuBindName(), "AT.Bold.30", ATScale(16), ATScale(42), THEME.green, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local capture = CreateCard(body, ATScale(86), ATScale(14))
    local captureBtn = CreateHoverButton(capture, function(s, w, h)
        PaintSubPanel(0, 0, w, h, ATScale(14))
        if s:IsHovered() then PaintHoverFill(0, 0, w, h, THEME.hover, ATScale(14)) end
        SafeSimpleText(waitingForKey and "Нажми любую клавишу..." or "Назначить новую клавишу", "AT.Bold.20", w * 0.5, h * 0.5 - ATScale(8), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        SafeSimpleText(waitingForKey and "ESC не назначается" or "После нажатия кнопка сохранится автоматически", "AT.Light.16", w * 0.5, h * 0.5 + ATScale(14), THEME.textSub, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end, function() waitingForKey = true end); captureBtn:Dock(FILL)

    CreateSectionLabel(body, "Быстрый выбор")
    local quickWrap = body:Add("DIconLayout"); quickWrap:Dock(TOP); quickWrap:SetTall(ATScale(126)); quickWrap:SetSpaceX(ATScale(10)); quickWrap:SetSpaceY(ATScale(10)); quickWrap:DockMargin(0, 0, 0, ATScale(18))

    for _, info in ipairs({ { key = KEY_B, name = "B" }, { key = KEY_F6, name = "F6" }, { key = KEY_F7, name = "F7" }, { key = KEY_F8, name = "F8" }, { key = KEY_HOME, name = "HOME" }, { key = KEY_INSERT, name = "INS" } }) do
        local btn = CreateHoverButton(quickWrap, function(s, w, h)
            PaintSubPanel(0, 0, w, h, ATScale(12))
            if AT.MenuKey == info.key then PaintHoverFill(0, 0, w, h, ColorAlpha(THEME.green, 35), ATScale(12))
            elseif s:IsHovered() then PaintHoverFill(0, 0, w, h, THEME.hover, ATScale(12)) end
            SafeSimpleText(info.name, "AT.Bold.18", w * 0.5, h * 0.5, AT.MenuKey == info.key and THEME.green or color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end, function() waitingForKey = false; SetMenuBind(info.key); currentKey = info.key end); btn:SetSize(ATScale(96), ATScale(48))
    end

    local resetBtn = CreatePrimaryButton(body, "Сбросить на B", function() waitingForKey = false; SetMenuBind(AT.DEFAULT_MENU_KEY) end)
    resetBtn:Dock(TOP); resetBtn:SetTall(ATScale(58))

    drawer.OnKeyCodePressed = function(_, key)
        if waitingForKey then
            if key ~= KEY_ESCAPE then SetMenuBind(key); currentKey = key; waitingForKey = false; PlayClick()
            else waitingForKey = false; surface.PlaySound("buttons/button10.wav") end
            return
        end
        if key == KEY_ESCAPE then drawer:CloseDrawer() end
    end
end

local function CreateColorPreview(parent, getColor)
    local pnl = parent:Add("DPanel"); pnl:SetTall(ATScale(84)); pnl:Dock(TOP); pnl:DockMargin(0, 0, 0, ATScale(14))
    pnl.Paint = function(_, w, h)
        PaintSubPanel(0, 0, w, h, ATScale(14))
        local col, size, x = getColor(), ATScale(44), ATScale(16)
        local y = h * 0.5 - size * 0.5
        if AT.rndx then
            AT.rndx.Draw(ATScale(12), x, y, size, size, col)
            AT.rndx.DrawOutlined(ATScale(12), x, y, size, size, Color(255, 255, 255, 10), 2)
        end
        SafeSimpleText("Предпросмотр цвета", "AT.Bold.18", x + size + ATScale(14), ATScale(16), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        SafeSimpleText(string.format("R: %d   G: %d   B: %d", col.r, col.g, col.b), "AT.Light.16", x + size + ATScale(14), ATScale(44), THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
    return pnl
end

local function OpenThemeColorPicker(themeKey, cookiePrefix, titleText, subtitleText, defaultColor)
    if not IsValid(UI_Frames.AdminTool) then return end
    if IsValid(UI_Frames.ThemeColor) and UI_Frames.ThemeColor.CloseDrawer then UI_Frames.ThemeColor:CloseDrawer(true) end
    local drawer, body = CreateDrawer(UI_Frames.AdminTool, titleText, subtitleText, ATScale(520)); UI_Frames.ThemeColor = drawer
    local current = Color(THEME[themeKey].r, THEME[themeKey].g, THEME[themeKey].b)
    local preview = CreateColorPreview(body, function() return current end)

    local mixerWrap = CreateCard(body, ATScale(320), ATScale(14))
    local mixer = mixerWrap:Add("DColorMixer"); mixer:Dock(FILL); mixer:DockMargin(ATScale(10), ATScale(10), ATScale(10), ATScale(10)); mixer:SetPalette(true); mixer:SetAlphaBar(false); mixer:SetWangs(true); mixer:SetColor(current)
    mixer.ValueChanged = function(_, col)
        current = Color(ClampColorChannel(col.r), ClampColorChannel(col.g), ClampColorChannel(col.b)); THEME[themeKey] = Color(current.r, current.g, current.b); SetCookieColor(cookiePrefix, current)
        if IsValid(preview) then preview:InvalidateLayout(true) end
        if IsValid(UI_Frames.AdminTool) and UI_Frames.AdminTool.RebuildFunc and AT.activeCatIndex == 5 then UI_Frames.AdminTool:InvalidateLayout(true) end
    end
    timer.Simple(0, function()
        if not IsValid(mixer) then return end
        if IsValid(mixer.Palette) then mixer.Palette.Paint = function(_, w, h) PaintSubPanel(0, 0, w, h, ATScale(10)) end end
        if IsValid(mixer.Hue) then mixer.Hue.Paint = function(_, w, h) PaintSubPanel(0, 0, w, h, ATScale(10)) end end
        if IsValid(mixer.Alpha) then mixer.Alpha:SetVisible(false) end
        if IsValid(mixer.RGB) then mixer.RGB:SetVisible(true) end
    end)

    CreateSectionLabel(body, "Готовые цвета")
    local presetWrap = body:Add("DIconLayout"); presetWrap:Dock(TOP); presetWrap:SetTall(ATScale(58)); presetWrap:SetSpaceX(ATScale(10)); presetWrap:SetSpaceY(ATScale(10)); presetWrap:DockMargin(0, 0, 0, ATScale(18))
    for _, col in ipairs({ Config.THEME_DEFAULT_GREEN, Config.THEME_DEFAULT_GOLD, Color(114, 191, 255), Color(255, 43, 43), Color(180, 120, 255), Color(0, 210, 170) }) do
        local btn = CreateHoverButton(presetWrap, function(s, w, h)
            PaintSubPanel(0, 0, w, h, ATScale(12)); if AT.rndx then AT.rndx.Draw(ATScale(10), ATScale(4), ATScale(4), w - ATScale(8), h - ATScale(8), col) end
            if s:IsHovered() then PaintHoverFill(0, 0, w, h, Color(255, 255, 255, 18), ATScale(12)) end
        end, function() current = Color(col.r, col.g, col.b); THEME[themeKey] = Color(col.r, col.g, col.b); SetCookieColor(cookiePrefix, current); if IsValid(mixer) then mixer:SetColor(current) end end)
        btn:SetSize(ATScale(48), ATScale(48))
    end

    local actions = body:Add("DPanel"); actions:Dock(TOP); actions:SetTall(ATScale(74)); actions.Paint = nil
    local resetBtn = CreateActionButton(actions, "Сбросить", ATScale(180), nil, function() current = Color(defaultColor.r, defaultColor.g, defaultColor.b); THEME[themeKey] = Color(current.r, current.g, current.b); ResetCookieColor(cookiePrefix, defaultColor); if IsValid(mixer) then mixer:SetColor(current) end end, "AT.Bold.18")
    resetBtn:Dock(LEFT)
    local saveBtn = CreatePrimaryButton(actions, "Готово", function() if IsValid(drawer) then drawer:CloseDrawer() end; if IsValid(UI_Frames.AdminTool) and UI_Frames.AdminTool.RebuildFunc and AT.activeCatIndex == 5 then UI_Frames.AdminTool.RebuildFunc() end end)
    saveBtn:SetSize(ATScale(220), ATScale(58)); actions.PerformLayout = function(_, w, h) saveBtn:SetPos(w - saveBtn:GetWide(), h * 0.5 - saveBtn:GetTall() * 0.5) end
end

local function OpenPunishmentMenu(target)
    if IsValid(UI_Frames.Punishment) then return UI_Frames.Punishment:Close() end
    if not IsValid(target) then return end

    local state = { typeIdx = 1, reasons = {}, reasonTimes = {}, issuer = nil, searchQueries = {} }
    local Rebuild, IssuerDrawer

    local function GetAvailableIssuers()
        local out = {}
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
                local staff = GetStaffEntry(ply)
                if staff or ply:IsAdmin() or ply:IsSuperAdmin() then
                    table.insert(out, { ply = ply, nick = ply:Nick(), steamid = ply:SteamID(), rank = string.upper(ply:GetUserGroup() or "player"), color = staff and staff.color or THEME.gold })
                end
            end
        end
        local localP = LocalPlayer()
        table.sort(out, function(a, b)
            if a.ply == localP then return true end
            if b.ply == localP then return false end
            return a.nick < b.nick
        end)
        return out
    end

    local function OpenIssuerSelector()
        if not IsValid(UI_Frames.Punishment) then return end
        if IsValid(IssuerDrawer) and IssuerDrawer.CloseDrawer then IssuerDrawer:CloseDrawer(true) end
        local drawer, body = CreateDrawer(UI_Frames.Punishment, "Выдать от имени", "Выберите онлайн-администратора для подписи к бану", ATScale(520)); IssuerDrawer = drawer
        local clearCard = CreateCard(body, ATScale(72), ATScale(12)); clearCard:SetMouseInputEnabled(true); clearCard:SetCursor("hand")
        clearCard.Paint = function(s, w, h)
            PaintSubPanel(0, 0, w, h, ATScale(14))
            if s:IsHovered() then PaintHoverFill(0, 0, w, h, THEME.hover, ATScale(14)) end
            SafeSimpleText("Не подставлять администратора", "AT.Bold.20", ATScale(16), ATScale(12), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            SafeSimpleText("Команда будет отправлена в обычном виде", "AT.Light.16", ATScale(16), ATScale(42), THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
        clearCard.OnCursorEntered = PlayHover
        clearCard.OnMousePressed = function(_, code) if code ~= MOUSE_LEFT then return end; state.issuer = nil; PlayClick(); if Rebuild then Rebuild() end; if IsValid(drawer) then drawer:CloseDrawer() end end

        local issuers = GetAvailableIssuers()
        if #issuers <= 0 then
            local empty = CreateCard(body, ATScale(78), 0); empty.Paint = function(_, w, h) PaintSubPanel(0, 0, w, h, ATScale(14)); SafeSimpleText("Сейчас нет доступных администраторов для выбора", "AT.Bold.20", ATScale(16), h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
            return
        end

        for _, info in ipairs(issuers) do
            local card = CreateCard(body, ATScale(84), ATScale(10)); card:SetMouseInputEnabled(true); card:SetCursor("hand")
            local av = card:Add("AvatarImage"); av:SetSize(ATScale(46), ATScale(46)); av:SetPlayer(info.ply, 64)
            card.PerformLayout = function(_, w, h) av:SetPos(ATScale(14), h * 0.5 - av:GetTall() * 0.5) end
            card.Paint = function(s, w, h)
                PaintSubPanel(0, 0, w, h, ATScale(14)); if s:IsHovered() then PaintHoverFill(0, 0, w, h, Color(255, 255, 255, 10), ATScale(14)) end
                SafeSimpleText(info.nick, "AT.Bold.20", ATScale(74), ATScale(12), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                SafeSimpleText(info.steamid, "AT.Light.16", ATScale(74), ATScale(38), THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                SafeSimpleText(info.rank, "AT.Light.16", w - ATScale(16), ATScale(14), info.color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
                local selected = state.issuer and state.issuer.steamid == info.steamid
                SafeSimpleText(selected and "Выбрано" or "Нажми для выбора", "AT.Light.16", w - ATScale(16), ATScale(40), selected and THEME.green or THEME.textSub, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            end
            card.OnCursorEntered = PlayHover
            card.OnMousePressed = function(_, code) if code ~= MOUSE_LEFT then return end; state.issuer = { nick = info.nick, steamid = info.steamid, rank = info.rank }; PlayClick(); if Rebuild then Rebuild() end; if IsValid(drawer) then drawer:CloseDrawer() end end
        end
    end

    local function GetSelectedDurationData(tData)
        if tData.t == "perma" then return { valid = true, hasPerma = true, totalMinutes = 0, text = "perma", details = {}, missing = {} } end
        local total, hasPerma, details, missing = 0, false, {}, {}
        for reason in pairs(state.reasons) do
            local chosen = state.reasonTimes[reason]
            if not chosen then table.insert(missing, reason) else
                if chosen.perma then hasPerma = true else total = total + (chosen.minutes or 0) end
                table.insert(details, reason .. " — " .. chosen.label)
            end
        end
        return { valid = #missing <= 0, hasPerma = hasPerma, totalMinutes = total, text = hasPerma and "perma" or FormatTime(total), details = details, missing = missing }
    end

    local function SelectReasonWithOption(reason, opt, tData)
        if IsBanType(tData.t) and not CanUseDurationForType(tData.t, opt.minutes, opt.perma) then NotifyBanLimitError(tData.t, opt.minutes, opt.perma); return end
        state.reasons[reason] = true; state.reasonTimes[reason] = { label = opt.label, minutes = opt.minutes, perma = opt.perma }; if Rebuild then Rebuild() end
    end

    local function ToggleReasonSelection(reason, tData)
    if state.reasons[reason] then state.reasons[reason] = nil; state.reasonTimes[reason] = nil; if Rebuild then Rebuild() end; return end
    if tData.t == "perma" then state.reasons[reason] = true; state.reasonTimes[reason] = nil; if Rebuild then Rebuild() end; return end
    
    local opts = GetReasonTimeOptions(reason, tData.t)
    if not opts or #opts <= 0 then state.reasons[reason] = true; if Rebuild then Rebuild() end; return end

    local minM, maxM, hasPerma = math.huge, 0, false
    for _, o in ipairs(opts) do
        if o.perma then hasPerma = true else
            minM = math.min(minM, o.minutes or 0)
            maxM = math.max(maxM, o.minutes or 0)
        end
    end
    if minM == math.huge then minM = 0 end

    if minM == maxM and not hasPerma then
        SelectReasonWithOption(reason, { label = FormatTime(minM), minutes = minM, perma = false }, tData)
        return
    end

    local m = vgui.Create("DFrame")
    m:SetTitle(""); m:ShowCloseButton(false); m:SetDraggable(false); m:SetDrawOnTop(true)
    
    local w = ATScale(280)
    local hasSlider = minM < maxM
    local yOffset = ATScale(36)

    m.Paint = function(_, sw, sh)
        PaintSubPanel(0, 0, sw, sh, ATScale(8))
        SafeSimpleText("Выбор времени", "AT.Bold.16", sw * 0.5, ATScale(10), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end

    local val = minM
    if hasSlider then
        local valLbl = m:Add("DLabel")
        valLbl:SetFont("AT.Bold.18"); valLbl:SetTextColor(THEME.gold); valLbl:SetPos(ATScale(14), yOffset); valLbl:SetSize(w - ATScale(28), ATScale(20)); valLbl:SetContentAlignment(5)
        valLbl:SetText(FormatTime(val))
        yOffset = yOffset + ATScale(24)

        local sl = m:Add("DSlider")
        sl:SetPos(ATScale(14), yOffset); sl:SetSize(w - ATScale(28), ATScale(20)); sl:SetTrapInside(true)
        SetStandardSliderPaint(sl)
        sl.OnValueChanged = function(_, v) val = math.Round(minM + v * (maxM - minM)); valLbl:SetText(FormatTime(val)) end
        sl:SetSlideX(0)
        yOffset = yOffset + ATScale(26)
    end

    local btnApply = CreatePrimaryButton(m, hasSlider and "Выбрать" or ("Выбрать " .. FormatTime(minM)), function()
        SelectReasonWithOption(reason, { label = FormatTime(val), minutes = val, perma = false }, tData); m:Close()
    end)
    btnApply:SetSize(w - ATScale(28), ATScale(30)); btnApply:SetPos(ATScale(14), yOffset)
    yOffset = yOffset + ATScale(38)

    if hasPerma then
        local btnPerma = CreateActionButton(m, "Навсегда (Perma)", w - ATScale(28), ATScale(30), function()
            SelectReasonWithOption(reason, { label = "perma", minutes = 0, perma = true }, tData); m:Close()
        end)
        btnPerma:SetPos(ATScale(14), yOffset)
        yOffset = yOffset + ATScale(38)
    end

    m:SetSize(w, yOffset + ATScale(8))
    local mx, my = gui.MousePos()
    m:SetPos(math.min(mx, ScrW() - w), math.min(my, ScrH() - m:GetTall()))
    m:MakePopup()

    m.Think = function(s)
        if input.IsMouseDown(MOUSE_LEFT) or input.IsMouseDown(MOUSE_RIGHT) then
            local cx, cy = s:CursorPos()
            if cx < 0 or cy < 0 or cx > w or cy > s:GetTall() then s:Close() end
        end
    end
    end

    local function GetReasonBucketKey(tData)
        if not tData or not tData.t then return "ban" end
        if tData.t == "perma" then return "perma" end
        if string.find(tData.t, "mute", 1, true) then return "mute" end
        return "ban"
    end

    local function CreateReasonSearchEntry(parent, initialValue, onChange)
        local wrap = parent:Add("DPanel"); wrap:Dock(TOP); wrap:SetTall(ATScale(58)); wrap:DockMargin(0, 0, 0, ATScale(16))
        wrap.Paint = function(_, w, h) PaintSubPanel(0, 0, w, h, ATScale(14)); SafeSimpleText("Поиск наказания/причины", "AT.Light.14", ATScale(16), ATScale(10), THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP) end
        local entry = wrap:Add("DTextEntry"); entry:Dock(FILL); entry:DockMargin(ATScale(14), ATScale(22), ATScale(14), ATScale(8)); entry:SetFont("AT.Bold.18"); entry:SetTextColor(color_white); entry:SetDrawBackground(false); entry:SetDrawBorder(false); entry:SetCursorColor(color_white); entry:SetHighlightColor(ColorAlpha(THEME.green, 70)); entry:SetPlaceholderText(""); entry:SetUpdateOnType(true); entry:SetText(tostring(initialValue or "")); entry:SetCaretPos(utf8.len(entry:GetValue()) or #entry:GetValue())
        entry.Paint = function(s, w, h) s:DrawTextEntryText(color_white, THEME.green, color_white); if string.Trim(s:GetValue() or "") == "" and not s:HasFocus() then SafeSimpleText("Введите нужное название наказания/причины", "AT.Bold.18", 0, h * 0.5, Color(255, 255, 255, 110), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end end
        entry.OnValueChange = function(s, value) value = tostring(value or s:GetValue() or ""); if onChange then onChange(value, s) end end
        return wrap, entry
    end

    UI_Frames.Punishment = CreateBaseFrame(function(s, key) if key == input.GetKeyCode(input.LookupBinding("+use") or "e") or key == KEY_E or key == KEY_ESCAPE then s:Close() end end)
    CreateMainHeader(UI_Frames.Punishment, "Взаимодействие", nil, target)
    local pad, sidebarW, headerH = UI.body_pad(), UI.sidebar_w(), UI.header_h()
    local sidebar = UI_Frames.Punishment:Add("DScrollPanel"); sidebar:SetPos(pad, headerH + ATScale(18)); sidebar:SetSize(sidebarW, ScrH() - headerH - ATScale(48)); StyleScrollbar(sidebar)
    local content = UI_Frames.Punishment:Add("DPanel"); content:SetPos(sidebarW + pad * 2, headerH + ATScale(22)); content:SetSize(ScrW() - sidebarW - pad * 3, ScrH() - headerH - ATScale(44)); content.Paint = nil

    local function AddGrid(scroll, title, items, tbl, isReasons, tData, reasonSearch, focusState)
        local filteredItems = {}
        if isReasons then
            local q = string.Trim(string.lower(tostring(reasonSearch or "")))
            for _, reason in ipairs(items or {}) do if q == "" or string.find(string.lower(tostring(reason or "")), q, 1, true) then table.insert(filteredItems, reason) end end
        else filteredItems = items or {} end

        local lbl = scroll:Add("DLabel"); lbl:SetText(title); lbl:SetFont("AT.Bold.24"); lbl:SetTextColor(color_white); lbl:Dock(TOP); lbl:DockMargin(0, 0, 0, ATScale(12))

        if isReasons then
            local _, searchEntry = CreateReasonSearchEntry(scroll, reasonSearch, function(value, searchPanel)
                if value == tostring(state.searchQueries[state.typeIdx] or "") then return end
                state.searchQueries[state.typeIdx] = tostring(value or "")
                local caretPos = IsValid(searchPanel) and searchPanel.GetCaretPos and tonumber(searchPanel:GetCaretPos()) or 0
                if Rebuild then timer.Simple(0, function() if not IsValid(UI_Frames.Punishment) then return end; Rebuild({ keepSearchFocus = IsValid(searchPanel) and searchPanel:HasFocus(), caretPos = caretPos, typeIdx = state.typeIdx }) end) end
            end)
            if focusState and focusState.keepSearchFocus and focusState.typeIdx == state.typeIdx then
                timer.Simple(0, function() if not IsValid(searchEntry) then return end; if searchEntry.GetParent and IsValid(searchEntry:GetParent()) and searchEntry:GetParent().InvalidateLayout then searchEntry:GetParent():InvalidateLayout(true) end; searchEntry:RequestFocus(); searchEntry:SetCaretPos(math.Clamp(tonumber(focusState.caretPos) or 0, 0, utf8.len(searchEntry:GetValue()) or #searchEntry:GetValue())) end)
            end
        end

        if isReasons and #filteredItems <= 0 then
            local empty = CreateCard(scroll, ATScale(72), ATScale(26)); empty.Paint = function(_, w, h) PaintSubPanel(0, 0, w, h, ATScale(14)); SafeSimpleText("Ничего не найдено", "AT.Bold.20", w * 0.5, h * 0.5, THEME.textSub, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end; return
        end

        local g = scroll:Add("DIconLayout"); g:Dock(TOP); g:SetSpaceX(ATScale(10)); g:SetSpaceY(ATScale(10)); g:DockMargin(0, 0, 0, ATScale(26))
        for k, v in ipairs(filteredItems) do
            local key, text = isReasons and v or k, isReasons and v or v.l
            local b = CreateHoverButton(g, function(s, w, h)
                local selected, opt = tbl[key], state.reasonTimes[key]
                PaintSubPanel(0, 0, w, h, ATScale(12))
                if selected then PaintHoverFill(0, 0, w, h, ColorAlpha(THEME.green, 26), ATScale(12)) elseif s:IsHovered() then PaintHoverFill(0, 0, w, h, THEME.hover, ATScale(12)) end
                if isReasons and selected and opt then
                    SafeSimpleText(text, "AT.Bold.16", w * 0.5, h * 0.38, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    SafeSimpleText(opt.label, "AT.Light.14", w * 0.5, h * 0.72, THEME.green, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                else
                    SafeSimpleText(text, "AT.Bold.16", w * 0.5, h * 0.5, selected and THEME.green or color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end, function() if isReasons then ToggleReasonSelection(key, tData) else tbl[key] = not tbl[key] or nil; if Rebuild then Rebuild() end end end)
            b:SetSize(isReasons and ATScale(145) or ATScale(120), isReasons and ATScale(52) or ATScale(42))
        end
    end

    Rebuild = function(focusState)
        focusState = focusState or {}; content:Clear()
        local tData, searchValue = PUNISH_CONFIG.types[state.typeIdx], tostring(state.searchQueries[state.typeIdx] or "")
        local scroll = content:Add("DScrollPanel"); scroll:Dock(FILL); StyleScrollbar(scroll)
        CreateSectionLabel(scroll, "Быстрые действия")
        local quickWrap = scroll:Add("DPanel"); quickWrap:Dock(TOP); quickWrap:SetTall(ATScale(72)); quickWrap:DockMargin(0, 0, 0, ATScale(22)); quickWrap.Paint = nil

        local function QuickBtn(txt, width, cmd)
            local b = CreateSubButton(quickWrap, txt, "AT.Bold.18", function() if not IsValid(target) then return end; SayText(cmd .. " " .. target:SteamID(), 0); UI_Frames.Punishment:Close() end)
            b:Dock(LEFT); b:SetWide(width); b:DockMargin(0, 0, ATScale(12), 0)
        end
        QuickBtn("Вернуть на спавн", ATScale(170), "/spawn"); QuickBtn("Вернуть в последнюю точку", ATScale(230), "/return"); QuickBtn("Логи игрока", ATScale(150), "/playerevents"); QuickBtn("Убрать розыск", ATScale(150), "/forceunwant"); QuickBtn("Убрать ордер", ATScale(150), "/forceunwarrant"); QuickBtn("Убрать аррест", ATScale(150), "/forceunarrest"); QuickBtn("Выдать аррест", ATScale(150), "/forcearrest")

        if tData.t == "ban" or tData.t == "perma" then
            CreateSectionLabel(scroll, "Выдать от имени")
            local issuerCard = CreateCard(scroll, ATScale(80), ATScale(18)); issuerCard:SetMouseInputEnabled(true); issuerCard:SetCursor("hand")
            issuerCard.Paint = function(s, w, h)
                PaintSubPanel(0, 0, w, h, ATScale(14)); if s:IsHovered() then PaintHoverFill(0, 0, w, h, Color(255, 255, 255, 10), ATScale(14)) end
                local title = state.issuer and state.issuer.nick or "Не выбрано"
                local sub = state.issuer and (state.issuer.steamid .. "  •  " .. state.issuer.rank) or "Нажми, чтобы выбрать администратора для подписи к бану"
                SafeSimpleText(title, "AT.Bold.20", ATScale(16), ATScale(14), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                SafeSimpleText(sub, "AT.Light.16", ATScale(16), ATScale(44), state.issuer and THEME.green or THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                SafeSimpleText("Изменить", "AT.Light.16", w - ATScale(16), h * 0.5, THEME.gold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
            issuerCard.OnCursorEntered = PlayHover; issuerCard.OnMousePressed = function(_, code) if code == MOUSE_LEFT then OpenIssuerSelector() end end
        end

        AddGrid(scroll, "Причина", PUNISH_CONFIG.reasons[GetReasonBucketKey(tData)], state.reasons, true, tData, searchValue, focusState)

        if tData.t ~= "perma" then
            local durationData = GetSelectedDurationData(tData)
            CreateSectionLabel(scroll, "Автоматическое время наказания")
            local info = CreateCard(scroll, durationData.valid and ATScale(92) or ATScale(116), ATScale(18))
            info.Paint = function(_, w, h)
                PaintSubPanel(0, 0, w, h, ATScale(14))
                if table.Count(state.reasons) <= 0 then SafeSimpleText("Выбери правило, чтобы время посчиталось автоматически", "AT.Bold.20", ATScale(16), h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER); return end
                if not durationData.valid then
                    SafeSimpleText("Не для всех выбранных правил задано время", "AT.Bold.20", ATScale(16), ATScale(14), THEME.red, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    SafeSimpleText("Нужно выбрать вариант времени для: " .. table.concat(durationData.missing, ", "), "AT.Light.16", ATScale(16), ATScale(46), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    return
                end
                local limitText = IsBanType(tData.t) and ("Лимит ранга: " .. FormatLimitText(GetLocalBanLimitMinutes())) or "Время берется из выбранных правил"
                SafeSimpleText("Итоговое время: " .. durationData.text, "AT.Bold.22", ATScale(16), ATScale(14), durationData.hasPerma and THEME.red or THEME.green, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                SafeSimpleText(limitText, "AT.Light.16", ATScale(16), ATScale(48), THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
            if #durationData.details > 0 then
                local details = CreateCard(scroll, math.max(ATScale(74), ATScale(26 + #durationData.details * 22)), ATScale(18))
                details.Paint = function(_, w, h)
                    PaintSubPanel(0, 0, w, h, ATScale(14)); SafeSimpleText("Выбранные интервалы", "AT.Bold.18", ATScale(16), ATScale(12), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    local y = ATScale(38); for _, line in ipairs(durationData.details) do SafeSimpleText("• " .. line, "AT.Light.16", ATScale(16), y, THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP); y = y + ATScale(20) end
                end
            end
        end

        local applyWrap = content:Add("DPanel"); applyWrap:Dock(BOTTOM); applyWrap:SetTall(ATScale(84)); applyWrap.Paint = nil
        local apply = CreatePrimaryButton(applyWrap, "Применить", function()
            if table.Count(state.reasons) <= 0 then return end
            local list = {}; for r in pairs(state.reasons) do table.insert(list, r) end; table.sort(list)
            local reasonText, sid, bySuffix = table.concat(list, ", "), target:SteamID(), state.issuer and (" (by " .. state.issuer.nick .. ", " .. state.issuer.steamid .. ")") or ""

            if tData.t == "perma" then
                if GetLocalBanLimitMinutes() ~= math.huge then NotifyBanLimitError(tData.t, 0, true); return end
                SayText("/" .. tData.c .. " " .. sid .. " " .. reasonText .. bySuffix, 0); UI_Frames.Punishment:Close(); return
            end
            local durationData = GetSelectedDurationData(tData)
            if not durationData.valid then surface.PlaySound("buttons/button10.wav"); return end
            if IsBanType(tData.t) and not CanUseDurationForType(tData.t, durationData.totalMinutes, durationData.hasPerma) then NotifyBanLimitError(tData.t, durationData.totalMinutes, durationData.hasPerma); return end

            if string.find(tData.t, "mute") then SayText("/" .. tData.c .. " " .. sid .. " " .. durationData.text, 0); SayText("/ooc " .. (reasonText ~= "" and reasonText or "Не указана"), 1); UI_Frames.Punishment:Close(); return end
            if durationData.hasPerma then
                if GetLocalBanLimitMinutes() ~= math.huge then NotifyBanLimitError(tData.t, 0, true); return end
                SayText("/perma " .. sid .. " " .. reasonText .. bySuffix, 0)
            else SayText("/" .. tData.c .. " " .. sid .. " " .. durationData.text .. " " .. reasonText .. bySuffix, 0) end
            UI_Frames.Punishment:Close()
        end)

        local btnFormAdmin, btnFormLooc
        if tData.t == "ban" or tData.t == "perma" then
            apply:SetSize(ATScale(220), ATScale(64))
            local function SendForm(prefix)
                if table.Count(state.reasons) <= 0 then return end
                local list = {}; for r in pairs(state.reasons) do table.insert(list, r) end; table.sort(list)
                local reasonText, sid, p = table.concat(list, ", "), target:SteamID(), LocalPlayer()
                local issuerNick = state.issuer and state.issuer.nick or p:Nick()
                local issuerSid = state.issuer and state.issuer.steamid or p:SteamID()
                local bySuffix = " (by " .. issuerNick .. ", " .. issuerSid .. ")"; local cmdStr = ""
                if tData.t == "perma" then cmdStr = "/" .. tData.c .. " " .. sid .. " " .. reasonText .. bySuffix else
                    local durationData = GetSelectedDurationData(tData)
                    if not durationData.valid then surface.PlaySound("buttons/button10.wav"); return end
                    cmdStr = durationData.hasPerma and ("/perma " .. sid .. " " .. reasonText .. bySuffix) or ("/" .. tData.c .. " " .. sid .. " " .. durationData.text .. " " .. reasonText .. bySuffix)
                end
                SayText(prefix .. " " .. cmdStr, 0); UI_Frames.Punishment:Close()
            end
            btnFormAdmin = CreateActionButton(applyWrap, "В админ. чат (@)", ATScale(230), ATScale(64), function() SendForm("@") end, "AT.Bold.18")
            btnFormLooc = CreateActionButton(applyWrap, "В локальный (/looc)", ATScale(230), ATScale(64), function() SendForm("/looc") end, "AT.Bold.18")
        else apply:SetSize(ATScale(360), ATScale(64)) end

        applyWrap.PerformLayout = function(s, w, h)
            if btnFormAdmin and btnFormLooc then
                local gap = ATScale(16); local totalW = btnFormAdmin:GetWide() + gap + apply:GetWide() + gap + btnFormLooc:GetWide(); local startX = w * 0.5 - totalW * 0.5
                btnFormAdmin:SetPos(startX, h * 0.5 - btnFormAdmin:GetTall() * 0.5); apply:SetPos(startX + btnFormAdmin:GetWide() + gap, h * 0.5 - apply:GetTall() * 0.5); btnFormLooc:SetPos(startX + btnFormAdmin:GetWide() + gap + apply:GetWide() + gap, h * 0.5 - btnFormLooc:GetTall() * 0.5)
            else apply:SetPos(w * 0.5 - apply:GetWide() * 0.5, h * 0.5 - apply:GetTall() * 0.5) end
        end
    end

    for i, t in ipairs(PUNISH_CONFIG.types) do
        CreateSidebarButton(sidebar, t.n, i, function() return state.typeIdx end, function(idx) state.typeIdx = idx; state.reasons = {}; state.reasonTimes = {}; Rebuild() end)
    end
    Rebuild()
end

StopAutoAdvertSequence = function(resetCooldown)
    AT.autoAdvertRunning, AT.autoAdvertIndex, AT.autoAdvertStepTime = false, 1, 0
    if resetCooldown then AT.autoAdvertNextRun = CurTime() + GetAutoAdvertCooldown() end
end

ResetAutoAdvertCooldown = function(stopSequence)
    if stopSequence then AT.autoAdvertRunning, AT.autoAdvertIndex, AT.autoAdvertStepTime = false, 1, 0 end
    AT.autoAdvertNextRun = CurTime() + GetAutoAdvertCooldown()
end

local function StartAutoAdvertSequence() if AT.autoAdvertRunning or not AT.showAutoAdvert then return end; AT.autoAdvertRunning, AT.autoAdvertIndex, AT.autoAdvertStepTime = true, 1, 0 end
local function GetAutoAdvertTimeLeftText()
    if not AT.showAutoAdvert then return "OFF" end
    if AT.autoAdvertRunning then return "SEND" end
    local left = math.max(0, math.ceil((AT.autoAdvertNextRun or 0) - CurTime()))
    return string.format("%02d:%02d", math.floor(left / 60), left % 60)
end

local function IsAutoAdvertChatMessage(text) return isstring(text) and text ~= "" and Config.AUTO_ADVERT_CHAT_LOOKUP[string.Trim(string.lower(text))] == true end

local function CreateOptControl(parent, item, rebuild)
    local pnl = CreateCard(parent, ATScale(84), ATScale(10))
    pnl.Paint = function(_, w, h)
        PaintSubPanel(0, 0, w, h, ATScale(14))
        SafeSimpleText(item.name, "AT.Bold.20", ATScale(16), ATScale(16), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        SafeSimpleText(item.desc, "AT.Light.16", ATScale(16), ATScale(46), THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    if item.t == "toggle" then
        local cvar, enabled = GetConVar(item.cv), (GetConVar(item.cv) and GetConVar(item.cv):GetFloat() == item.on) or false
        local tog = CreateToggle(pnl, function() local live = GetConVar(item.cv); return live and live:GetFloat() == item.on or enabled end, function(newVal) enabled = newVal; RunConsoleCommand(item.cv, tostring(enabled and item.on or item.off)); if item.cv == "mat_specular" then RunConsoleCommand("mat_bumpmap", tostring(enabled and item.on or item.off)) end end)
        pnl.PerformLayout = function(_, w, h) tog:SetPos(w - tog:GetWide() - ATScale(16), h * 0.5 - tog:GetTall() * 0.5) end
    elseif item.t == "slider" then
        local curVal = GetConVar(item.cv) and GetConVar(item.cv):GetFloat() or 0
        local wrap = pnl:Add("DPanel"); wrap:SetWide(ATScale(260)); wrap:Dock(RIGHT); wrap:DockMargin(0, 0, ATScale(16), 0); wrap.Paint = nil
        local valLbl = wrap:Add("DLabel"); valLbl:SetFont("AT.Bold.18"); valLbl:SetTextColor(THEME.gold); valLbl:Dock(RIGHT); valLbl:SetWide(ATScale(56)); valLbl:SetContentAlignment(6); valLbl:SetText(tostring(math.Round(curVal)))
        local sl = wrap:Add("DSlider"); sl:Dock(FILL); sl:DockMargin(0, ATScale(28), ATScale(12), ATScale(28)); sl:SetTrapInside(true); sl:SetSlideX(math.Clamp((curVal - item.min) / math.max(item.max - item.min, 1), 0, 1)); SetStandardSliderPaint(sl)
        sl.OnValueChanged = function(_, val) local real = math.Round(item.min + val * (item.max - item.min)); valLbl:SetText(tostring(real)); RunConsoleCommand(item.cv, tostring(real)); if item.cv == "r_decals" then RunConsoleCommand("mp_decals", tostring(real)) end end
    elseif item.t == "action" then
        local actionBtn = CreateActionButton(pnl, item.btn or "Применить", ATScale(132), ATScale(40), function() if item.action then item.action() end end)
        pnl.PerformLayout = function(_, w, h) actionBtn:SetPos(w - ATScale(148), h * 0.5 - actionBtn:GetTall() * 0.5) end
    end
    return pnl
end

local function ToggleAdminMenu()
    if CurTime() < AT.lastActionTime + AT.Cooldown then return end
    AT.lastActionTime = CurTime(); if IsValid(UI_Frames.AdminTool) then return UI_Frames.AdminTool:Close() end

    local p = LocalPlayer()
    UI_Frames.AdminTool = CreateBaseFrame(function(_, key) if key == AT.MenuKey then ToggleAdminMenu() end end)
    CreateMainHeader(UI_Frames.AdminTool, "AdminTool", nil, p)

    local pad, sidebarW, headerH = UI.body_pad(), UI.sidebar_w(), UI.header_h()
    local catListWrap = UI_Frames.AdminTool:Add("DPanel"); catListWrap:SetPos(pad, headerH + ATScale(18)); catListWrap:SetSize(sidebarW, ScrH() - headerH - ATScale(44)); catListWrap.Paint = nil
    local catList = catListWrap:Add("DScrollPanel"); catList:Dock(FILL); StyleScrollbar(catList)

    local content = UI_Frames.AdminTool:Add("DPanel"); content:SetPos(sidebarW + pad * 2, headerH + ATScale(22)); content:SetSize(ScrW() - sidebarW - pad * 3, ScrH() - headerH - ATScale(44)); content.Paint = nil

    local function RebuildContent()
    content:Clear()

if AT.activeCatIndex == 2 then
        local scroll = content:Add("DScrollPanel"); scroll:Dock(FILL); StyleScrollbar(scroll)

        local header = scroll:Add("DLabel")
        header:SetText("Центр оптимизации")
        header:SetFont("AT.Bold.30"); header:SetTextColor(color_white)
        header:Dock(TOP); header:DockMargin(0, 0, 0, ATScale(4)); header:SizeToContents()

        local subHeader = scroll:Add("DLabel")
        subHeader:SetText("Активные подсистемы отслеживают сцену в реальном времени")
        subHeader:SetFont("AT.Light.16"); subHeader:SetTextColor(THEME.textSub)
        subHeader:Dock(TOP); subHeader:DockMargin(0, 0, 0, ATScale(16)); subHeader:SizeToContents()

        local stripCard = scroll:Add("DPanel")
        stripCard:Dock(TOP); stripCard:SetTall(ATScale(62)); stripCard:DockMargin(0, 0, 0, ATScale(14))

        local stripLayout = { btns = {}, count = #OPT_PRESETS }
        stripCard.Paint = function(_, w, h)
            PaintSubPanel(0, 0, w, h, ATScale(12))
            SafeSimpleText("ПРЕСЕТЫ", "AT.Bold.14", ATScale(16), h * 0.5, THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local stripInner = stripCard:Add("DPanel")
        stripInner:Dock(FILL); stripInner:DockMargin(ATScale(100), ATScale(10), ATScale(12), ATScale(10))
        stripInner.Paint = nil

        for i, pr in ipairs(OPT_PRESETS) do
            local hov = 0
            local btn = stripInner:Add("DButton")
            btn:SetText(""); btn:Dock(LEFT); btn:SetWide(ATScale(132)); btn:DockMargin(0, 0, ATScale(6), 0)
            btn.Paint = function(s, w, h)
                hov = Lerp(FrameTime() * 12, hov, s:IsHovered() and 1 or 0)
                if AT.rndx then
                    AT.rndx.Draw(ATScale(8), 0, 0, w, h, Color(18, 18, 22, 210))
                    AT.rndx.DrawOutlined(ATScale(8), 0, 0, w, h, ColorAlpha(pr.color, 40 + math.Round(80 * hov)), 1)
                    AT.rndx.Draw(ATScale(8), 0, 0, ATScale(3), h, pr.color)
                    if hov > 0.01 then
                        AT.rndx.Draw(ATScale(8), 0, 0, w, h, ColorAlpha(pr.color, math.Round(18 * hov)))
                    end
                end
                SafeSimpleText(pr.name, "AT.Bold.14", ATScale(12), h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            btn.DoClick = function() PlayClick(); ApplyOptPreset(pr); RebuildContent() end
            stripLayout.btns[i] = btn
        end

        local coreCard = scroll:Add("DPanel")
        coreCard:Dock(TOP); coreCard:SetTall(ATScale(280)); coreCard:DockMargin(0, 0, 0, ATScale(14))

        coreCard.Paint = function(_, w, h)
            if not AT.rndx then return end

            AT.rndx.Draw(ATScale(14), 0, 0, w, h, ColorAlpha(THEME.subBg, 240))
            AT.rndx.DrawOutlined(ATScale(14), 0, 0, w, h, THEME.subBorder, 1)

            SafeSimpleText("● LIVE / FOV-FRUSTUM CULLING", "AT.Bold.14", ATScale(18), ATScale(14), THEME.green, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            SafeSimpleText("Отсечение объектов вне поля зрения камеры", "AT.Light.14", ATScale(18), ATScale(32), THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            local radarR = math.min(h - ATScale(70), ATScale(230)) * 0.5
            local radarCX = ATScale(30) + radarR
            local radarCY = h * 0.5 + ATScale(14)

            for ring = 1, 3 do
                local rr = radarR * (ring / 3)
                AT.rndx.DrawCircleOutlined(radarCX, radarCY, rr * 2, ColorAlpha(THEME.green, 40 - ring * 8), 1)
            end

            local fov = GetConVar("at_opt_ffc_fov"):GetFloat()
            local halfAng = math.rad(fov * 0.5)
            local steps = 18
            for s = 0, steps do
                local t = -halfAng + (halfAng * 2) * (s / steps)
                local px = radarCX + math.sin(t) * radarR
                local py = radarCY - math.cos(t) * radarR
                if s > 0 then
                    local midX = (radarCX + px) * 0.5
                    local midY = (radarCY + py) * 0.5
                    AT.rndx.DrawCircle(midX, midY, ATScale(2), ColorAlpha(THEME.green, 18))
                end
            end

            for edgeSign = -1, 1, 2 do
                local ex = radarCX + math.sin(halfAng * edgeSign) * radarR
                local ey = radarCY - math.cos(halfAng * edgeSign) * radarR
                for t = 0, 1, 0.04 do
                    local dx = Lerp(t, radarCX, ex)
                    local dy = Lerp(t, radarCY, ey)
                    AT.rndx.DrawCircle(dx, dy, ATScale(2), ColorAlpha(THEME.green, 90))
                end
            end

            AT.rndx.DrawCircle(radarCX, radarCY, ATScale(10), Color(255, 255, 255, 200))
            AT.rndx.DrawCircle(radarCX, radarCY, ATScale(5), Color(0, 0, 0, 255))
            AT.rndx.DrawCircle(radarCX, radarCY, ATScale(3), THEME.green)

            OptCore.radar_sweep_angle = (OptCore.radar_sweep_angle + FrameTime() * 90) % 360
            local sweepRad = math.rad(OptCore.radar_sweep_angle)
            for t = 0, 1, 0.04 do
                local dx = radarCX + math.sin(sweepRad) * radarR * t
                local dy = radarCY - math.cos(sweepRad) * radarR * t
                AT.rndx.DrawCircle(dx, dy, ATScale(2), ColorAlpha(THEME.green, math.Round(180 * (1 - t))))
            end

            local plr = LocalPlayer()
            if IsValid(plr) then
                local camPos = GetCameraPos()
                local camAng = plr:EyeAngles()
                local forward = camAng:Forward(); forward.z = 0; forward:Normalize()
                local right = camAng:Right(); right.z = 0; right:Normalize()

                local maxShowDist = 3000
                local shown, culled = 0, 0

                for _, ent in ipairs(ents.GetAll()) do
                    if not IsValid(ent) or ent == plr then continue end
                    if ent:IsWeapon() and ent:GetOwner() and IsValid(ent:GetOwner()) then continue end

                    local isPly = ent:IsPlayer()
                    local isProp = ent:GetClass() == "prop_physics" or ent:GetClass() == "prop_physics_multiplayer"
                    local isEnt = ent:IsNPC() or (isPly == false and isProp == false and (ent.IsVehicle and ent:IsVehicle()) or false)

                    if not (isPly or isProp or isEnt) then continue end
                    if ent:IsDormant() then continue end

                    local delta = ent:GetPos() - camPos
                    local distXY = math.sqrt(delta.x * delta.x + delta.y * delta.y)
                    if distXY > maxShowDist or distXY < 1 then continue end

                    local forwardComp = delta:Dot(forward) / distXY
                    local rightComp = delta:Dot(right) / distXY

                    local scrX = radarCX + rightComp * (distXY / maxShowDist) * radarR
                    local scrY = radarCY - forwardComp * (distXY / maxShowDist) * radarR

                    local inCone = forwardComp > OptCore.ffc_fov_cos

                    local col, sz
                    if isPly then
                        col = inCone and Color(80, 220, 255, 230) or Color(60, 80, 100, 120)
                        sz  = ATScale(7)
                    elseif isProp then
                        col = inCone and Color(255, 200, 80, 200) or Color(80, 70, 50, 110)
                        sz  = ATScale(5)
                    else
                        col = inCone and Color(200, 120, 255, 200) or Color(60, 40, 80, 110)
                        sz  = ATScale(5)
                    end

                    AT.rndx.DrawCircle(scrX, scrY, sz, col)
                    if inCone then
                        shown = shown + 1
                    else
                        culled = culled + 1
                    end

                    if shown + culled > 80 then break end
                end
            end

            local metrX = radarCX + radarR + ATScale(40)
            local metrW = w - metrX - ATScale(18)
            local metrY = ATScale(56)

            local function metricRow(y, label, value, valueCol, barFrac, barCol)
                SafeSimpleText(label, "AT.Light.16", metrX, y, THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                SafeSimpleText(value, "AT.Bold.22", metrX + metrW, y - ATScale(4), valueCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
                local by = y + ATScale(22)
                AT.rndx.Draw(256, metrX, by, metrW, ATScale(4), Color(255, 255, 255, 20))
                if barFrac and barFrac > 0 then
                    AT.rndx.Draw(256, metrX, by, metrW * math.Clamp(barFrac, 0, 1), ATScale(4), barCol)
                end
            end

            local fps = math.Round(1 / math.max(FrameTime(), 0.001))
            local fpsCol = fps >= 90 and THEME.green or (fps >= 50 and THEME.gold or THEME.red)
            metricRow(metrY,                  "FPS (текущий)",      tostring(fps),                          fpsCol,    fps / 144,               fpsCol)
            metricRow(metrY + ATScale(46),    "Отсечено объектов",  tostring(OptCore.ffc_culled_ply + OptCore.ffc_culled_ent + OptCore.ffc_culled_prop), THEME.green,  math.min(1, (OptCore.ffc_culled_ply + OptCore.ffc_culled_ent + OptCore.ffc_culled_prop) / 40), THEME.green)
            metricRow(metrY + ATScale(92),    "Заморожено игроков",  tostring(OptCore.pms_frozen_count),     Color(120, 200, 255), math.min(1, OptCore.pms_frozen_count / 20), Color(120, 200, 255))
            metricRow(metrY + ATScale(138),   "Погашено эффектов",  tostring(OptCore.dpr_reaped_total),     THEME.gold,  math.min(1, OptCore.dpr_reaped_total / 50), THEME.gold)
            metricRow(metrY + ATScale(184),   "Lua память (MB)",    string.format("%.1f", OptCore.smd_lua_memory / 1024), Color(200, 140, 255), math.min(1, OptCore.smd_lua_memory / 1024 / 128), Color(200, 140, 255))
        end

        local modulesTitle = scroll:Add("DLabel")
        modulesTitle:SetText("Подсистемы")
        modulesTitle:SetFont("AT.Bold.24"); modulesTitle:SetTextColor(color_white)
        modulesTitle:Dock(TOP); modulesTitle:DockMargin(0, ATScale(6), 0, ATScale(10)); modulesTitle:SizeToContents()

        local grid = scroll:Add("DIconLayout")
        grid:Dock(TOP); grid:DockMargin(0, 0, 0, ATScale(18))
        grid:SetSpaceX(ATScale(12)); grid:SetSpaceY(ATScale(12))

        local MODULES = {
            {
                id = "ffc", cvar = "at_opt_ffc_enabled", accent = Color(90, 230, 200),
                title = "FOV-Culling",
                sub   = "Отсекает объекты вне зоны обзора камеры. Экономия DrawCalls до 60%.",
                metric = function() return "Отсечено: " .. (OptCore.ffc_culled_ply + OptCore.ffc_culled_ent + OptCore.ffc_culled_prop) end,
            },
            {
                id = "atb", cvar = "at_opt_atb_enabled", accent = Color(255, 180, 80),
                title = "Temporal Budget",
                sub   = "Дробит обход сцены на чанки. Убирает микро-фризы от `ents.GetAll()`.",
                metric = function() return string.format("Нагрузка: x%.2f", OptCore.atb_load_factor) end,
            },
            {
                id = "pms", cvar = "at_opt_pms_enabled", accent = Color(120, 200, 255),
                title = "Motion Streaming",
                sub   = "Останавливает расчёт костей AFK/статичных игроков.",
                metric = function() return "Заморожено: " .. OptCore.pms_frozen_count .. " plr" end,
            },
            {
                id = "dpr", cvar = "at_opt_dpr_enabled", accent = Color(255, 120, 180),
                title = "Particle Reaper",
                sub   = "Агрессивно гасит дальние env_*, info_particle_*, beam.",
                metric = function() return "Погашено: " .. OptCore.dpr_reaped_total end,
            },
            {
                id = "smd", cvar = "at_opt_smd_enabled", accent = Color(200, 140, 255),
                title = "Lua Defrag",
                sub   = "Инкрементальный GC: мелкие порции вместо больших сборок.",
                metric = function() return string.format("%.1f MB · x%d", OptCore.smd_lua_memory / 1024, OptCore.smd_gc_collections) end,
            },
        }

        local cardW = math.floor((content:GetWide() - ATScale(20) * 2) / 2.1)
        for _, mod in ipairs(MODULES) do
            local hov = 0
            local pulse = math.random() * math.pi * 2

            local card = grid:Add("DButton")
            card:SetText(""); card:SetSize(cardW, ATScale(108))

            card.Paint = function(s, w, h)
                hov = Lerp(FrameTime() * 12, hov, s:IsHovered() and 1 or 0)
                if not AT.rndx then return end

                local cv = GetConVar(mod.cvar)
                local enabled = cv and cv:GetBool() or false

                AT.rndx.Draw(ATScale(12), 0, 0, w, h, enabled and ColorAlpha(THEME.subBg, 240) or ColorAlpha(THEME.card2, 230))
                AT.rndx.DrawOutlined(ATScale(12), 0, 0, w, h, enabled and ColorAlpha(mod.accent, 110) or Color(255, 255, 255, 14), 1)

                if enabled then
                    AT.rndx.Draw(ATScale(12), 0, 0, ATScale(4), h, mod.accent)
                end

                if hov > 0.01 then
                    AT.rndx.Draw(ATScale(12), 0, 0, w, h, ColorAlpha(mod.accent, math.Round(12 * hov)))
                end

                local pulseT = enabled and (0.5 + 0.5 * math.sin(RealTime() * 3 + pulse)) or 0.3
                AT.rndx.DrawCircle(w - ATScale(20), ATScale(20), ATScale(10), enabled and ColorAlpha(mod.accent, math.Round(60 + 100 * pulseT)) or ColorAlpha(color_white, 15))
                AT.rndx.DrawCircle(w - ATScale(20), ATScale(20), ATScale(5), enabled and mod.accent or Color(70, 70, 70))

                SafeSimpleText(mod.title, "AT.Bold.20", ATScale(18), ATScale(14), enabled and color_white or Color(180, 180, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                SafeSimpleText(mod.sub,   "AT.Light.14", ATScale(18), ATScale(40), THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                local metricTxt = mod.metric and mod.metric() or ""
                SafeSimpleText(metricTxt, "AT.Bold.16", ATScale(18), h - ATScale(16), enabled and mod.accent or Color(90, 90, 90), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

                SafeSimpleText(enabled and "АКТИВНО" or "ВЫКЛ", "AT.Bold.14", w - ATScale(18), h - ATScale(16), enabled and mod.accent or Color(100, 100, 100), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
            end

            card.DoClick = function()
                PlayClick()
                local cv = GetConVar(mod.cvar)
                if cv then RunConsoleCommand(mod.cvar, cv:GetBool() and "0" or "1") end
            end
        end

        timer.Simple(0, function() if IsValid(grid) then grid:InvalidateLayout(true); grid:SizeToChildren(false, true) end end)

    elseif AT.activeCatIndex == 3 then
        local scroll = content:Add("DScrollPanel"); scroll:Dock(FILL); StyleScrollbar(scroll)
        local cats, totalStaff = { {}, {}, {}, {} }, 0
        for _, pl in ipairs(player.GetAll()) do
            local n, g, sid = pl:Nick(), string.lower(pl:GetUserGroup() or ""), pl:SteamID()
            local hasTag = string.StartWith(n, "[H]") or string.EndsWith(n, "[H]")
            for i, h in ipairs(STAFF_HIERARCHY) do
                if (h.steamids and h.steamids[sid]) or (hasTag and h.ranks and h.ranks[g]) then table.insert(cats[i], pl); totalStaff = totalStaff + 1; break end
            end
        end
        local title = scroll:Add("DLabel"); title:SetText("Наборная администрация (" .. totalStaff .. " онлайн)"); title:SetFont("AT.Bold.30"); title:SetTextColor(color_white); title:Dock(TOP); title:DockMargin(0, 0, 0, ATScale(18)); title:SizeToContents()

        for i, h in ipairs(STAFF_HIERARCHY) do
            if #cats[i] > 0 then
                local header = CreateCard(scroll, ATScale(42), ATScale(12))
                header.Paint = function(_, w, hh) 
                    PaintSubPanel(0, 0, w, hh, ATScale(12))
                    if AT.rndx then AT.rndx.Draw(ATScale(12), 0, 0, ATScale(6), hh, h.color) end
                    SafeSimpleText(h.name .. " — " .. #cats[i], "AT.Bold.20", ATScale(18), hh * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) 
                end
                for _, pl in ipairs(cats[i]) do
                    local btn = CreateCard(scroll, ATScale(64), ATScale(8)); btn:SetMouseInputEnabled(true)
                    local av = btn:Add("AvatarImage"); av:SetSize(ATScale(40), ATScale(40)); av:SetPlayer(pl, 64)
                    btn.PerformLayout = function(_, _, hh) av:SetPos(ATScale(12), hh * 0.5 - av:GetTall() * 0.5) end
                    local hov = 0
                    btn.Paint = function(s, w, hh)
                        hov = Lerp(FrameTime() * 10, hov, s:IsHovered() and 1 or 0); PaintSubPanel(0, 0, w, hh, ATScale(12))
                        if hov > 0.01 then PaintHoverFill(0, 0, w, hh, Color(255, 255, 255, math.Round(10 * hov)), ATScale(12)) end
                        if IsValid(pl) then
                            SafeSimpleText(pl:Nick(), "AT.Bold.20", ATScale(64), ATScale(12), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                            SafeSimpleText(string.upper(pl:GetUserGroup()), "AT.Light.16", ATScale(64), ATScale(38), h.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                            SafeSimpleText(s:IsHovered() and "Скопировать SteamID" or pl:SteamID(), "AT.Light.18", w - ATScale(16), hh * 0.5, s:IsHovered() and h.color or THEME.textSub, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                        end
                    end
                    btn.OnCursorEntered = PlayHover; btn.OnMousePressed = function() if IsValid(pl) then SetClipboardText(pl:SteamID()); notification.AddLegacy("SteamID скопирован!", 0, 2); PlayClick() end end
                end
            end
        end

    elseif AT.activeCatIndex == 4 then
        local scroll = content:Add("DScrollPanel"); scroll:Dock(FILL); StyleScrollbar(scroll)
        local afkPlayers = GetAFKPlayers()
        local title = scroll:Add("DLabel"); title:SetText("Игроки в AFK (" .. #afkPlayers .. ")"); title:SetFont("AT.Bold.30"); title:SetTextColor(color_white); title:Dock(TOP); title:DockMargin(0, 0, 0, ATScale(10)); title:SizeToContents()
        local sub = scroll:Add("DLabel"); sub:SetText("Клиентское определение AFK по бездействию игрока"); sub:SetFont("AT.Light.20"); sub:SetTextColor(THEME.textSub); sub:Dock(TOP); sub:DockMargin(0, 0, 0, ATScale(14)); sub:SizeToContents()

        if #afkPlayers <= 0 then
            local empty = CreateCard(scroll, ATScale(78), 0); empty.Paint = function(_, w, h) PaintSubPanel(0, 0, w, h, ATScale(14)); SafeSimpleText("Сейчас нет игроков, которые долго стоят в AFK", "AT.Bold.20", ATScale(16), h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
        else
            for _, data in ipairs(afkPlayers) do
                local pl = data.ply
                local card = CreateCard(scroll, ATScale(86), ATScale(10)); card:SetMouseInputEnabled(true)
                local av = card:Add("AvatarImage"); av:SetSize(ATScale(46), ATScale(46)); av:SetPlayer(pl, 64)
                
                local spectateBtn = CreateHoverButton(card, function(s, w, h) PaintSubPanel(0, 0, w, h, ATScale(12)); if s:IsHovered() then PaintHoverFill(0, 0, w, h, ColorAlpha(THEME.green, 22), ATScale(12)) end; SafeSimpleText("Следить", "AT.Bold.18", w * 0.5, h * 0.5, s:IsHovered() and THEME.green or color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end, function() if IsValid(pl) then RunBASpectate(pl) end end)
                spectateBtn:SetSize(ATScale(110), ATScale(42))
                
                local civBtn = CreateHoverButton(card, function(s, w, h) PaintSubPanel(0, 0, w, h, ATScale(12)); if s:IsHovered() then PaintHoverFill(0, 0, w, h, ColorAlpha(THEME.gold, 22), ATScale(12)) end; SafeSimpleText("Гражданин", "AT.Bold.18", w * 0.5, h * 0.5, s:IsHovered() and THEME.gold or color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end, function() if IsValid(pl) then SayText("/setjob " .. pl:SteamID() .. " Гражданин", 0) end end)
                civBtn:SetSize(ATScale(130), ATScale(42))
                
                card.PerformLayout = function(_, w, h) 
                    av:SetPos(ATScale(14), h * 0.5 - av:GetTall() * 0.5)
                    civBtn:SetPos(w - civBtn:GetWide() - ATScale(14), h * 0.5 - civBtn:GetTall() * 0.5)
                    spectateBtn:SetPos(civBtn.x - spectateBtn:GetWide() - ATScale(8), h * 0.5 - spectateBtn:GetTall() * 0.5)
                end
                
                local hover = 0
                card.Paint = function(s, w, h)
                    hover = Lerp(FrameTime() * 10, hover, s:IsHovered() and 1 or 0); PaintSubPanel(0, 0, w, h, ATScale(14))
                    if hover > 0.01 then PaintHoverFill(0, 0, w, h, Color(255, 255, 255, math.Round(10 * hover)), ATScale(14)) end
                    if not IsValid(pl) then SafeSimpleText("Игрок вышел с сервера", "AT.Bold.20", ATScale(74), h * 0.5, THEME.red, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER); return end
                    
                    local rank, status, jobName = string.upper(pl:GetUserGroup() or "player"), GetAFKStatusText(pl, data.afkSeconds), GetPlayerJobName(pl)
                    
                    SafeSimpleText(pl:Nick(), "AT.Bold.20", ATScale(74), ATScale(14), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    SafeSimpleText(pl:SteamID(), "AT.Light.16", ATScale(74), ATScale(38), THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    SafeSimpleText("Профа: " .. jobName, "AT.Light.16", ATScale(74), ATScale(58), THEME.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    
                    local textRx = spectateBtn.x - ATScale(16)
                    SafeSimpleText(rank, "AT.Light.16", textRx, ATScale(24), THEME.gold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
                    SafeSimpleText(status, "AT.Light.16", textRx, ATScale(46), THEME.green, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
                end
                card.OnCursorEntered = PlayHover; card.OnMousePressed = function(_, code) if code == MOUSE_LEFT and IsValid(pl) then SetClipboardText(pl:SteamID()); notification.AddLegacy("SteamID скопирован!", 0, 2); PlayClick() end end
            end
        end

    elseif AT.activeCatIndex == 5 then
        local scroll = content:Add("DScrollPanel"); scroll:Dock(FILL); StyleScrollbar(scroll)
        local title = scroll:Add("DLabel"); title:SetText("Логи пропов"); title:SetFont("AT.Bold.30"); title:SetTextColor(color_white); title:Dock(TOP); title:DockMargin(0, 0, 0, ATScale(10)); title:SizeToContents()
        local sub = scroll:Add("DLabel"); sub:SetText("Красным подсвечиваются игроки, которые за " .. AT.PROP_LOG_WINDOW .. " сек. создали " .. AT.PROP_LOG_SUSPICIOUS_COUNT .. "+ пропов • хранение: последние " .. AT.PROP_LOG_BUFFER_SIZE .. " записей"); sub:SetFont("AT.Light.20"); sub:SetTextColor(THEME.textSub); sub:Dock(TOP); sub:DockMargin(0, 0, 0, ATScale(14)); sub:SizeToContents()

        local stats = CreateCard(scroll, ATScale(88), ATScale(14))
        local clearBtn = CreateActionButton(stats, "Очистить", ATScale(132), ATScale(40), ClearPropLogs)
        stats.PerformLayout = function(_, w, h) clearBtn:SetPos(w - clearBtn:GetWide() - ATScale(16), h * 0.5 - clearBtn:GetTall() * 0.5) end
        stats.Paint = function(_, w, h)
            PaintSubPanel(0, 0, w, h, ATScale(14))
            local suspiciousCount = 0; for i = 1, AT.PROP_LOG_COUNT do local e = GetPropLogEntry(i); if e and e.suspicious then suspiciousCount = suspiciousCount + 1 end end
            SafeSimpleText("Всего записей: " .. AT.PROP_LOG_COUNT, "AT.Bold.20", ATScale(16), ATScale(18), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            SafeSimpleText("Подозрительных: " .. suspiciousCount, "AT.Light.18", ATScale(16), ATScale(48), suspiciousCount > 0 and THEME.red or THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        local listWrap = scroll:Add("DPanel"); listWrap:Dock(TOP); listWrap.Paint = nil; local lastVersion = -1
        local function BuildPropLogList(force)
            if not force and lastVersion == AT.PROP_LOG_VERSION then return end
            lastVersion = AT.PROP_LOG_VERSION; listWrap:Clear()
            local totalTall, snapshot = 0, GetPropLogSnapshot()
            if #snapshot <= 0 then
                local empty = CreateCard(listWrap, ATScale(78), 0); empty.Paint = function(_, w, h) PaintSubPanel(0, 0, w, h, ATScale(14)); SafeSimpleText("Логи пусты. После появления новых пропов записи начнут отображаться здесь.", "AT.Bold.20", ATScale(16), h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
                totalTall = totalTall + ATScale(78)
            else
                for idx, entry in ipairs(snapshot) do
                    local suspiciousColor = entry.suspicious and Color(75, 18, 18, 220) or nil
                    local card = CreateCard(listWrap, ATScale(96), idx == #snapshot and 0 or ATScale(10)); card:SetMouseInputEnabled(true); card:SetCursor("hand")
                    card.Paint = function(s, w, h)
                        if suspiciousColor then 
                            if AT.rndx then 
                                AT.rndx.Draw(ATScale(14), 0, 0, w, h, suspiciousColor)
                                AT.rndx.DrawOutlined(ATScale(14), 0, 0, w, h, Color(255, 255, 255, 13), 1)
                            end
                        else 
                            PaintSubPanel(0, 0, w, h, ATScale(14)) 
                        end
                        if s:IsHovered() then PaintHoverFill(0, 0, w, h, Color(255, 255, 255, 10), ATScale(14)) end
                        local nickColor, metaColor = entry.suspicious and Color(255, 150, 150) or color_white, entry.suspicious and Color(255, 120, 120) or THEME.textSub
                        local modelText = #entry.model > 90 and string.sub(entry.model, 1, 90) .. "..." or entry.model
                        SafeSimpleText(entry.timeText .. "  •  " .. entry.nick, "AT.Bold.20", ATScale(16), ATScale(12), nickColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                        SafeSimpleText(entry.steamid .. "  •  " .. entry.class, "AT.Light.16", ATScale(16), ATScale(40), metaColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                        SafeSimpleText(modelText, "AT.Light.16", ATScale(16), ATScale(62), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                        if entry.suspicious then SafeSimpleText("SPAM x" .. entry.burstCount, "AT.Bold.18", w - ATScale(16), h * 0.5, THEME.red, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                        elseif s:IsHovered() then SafeSimpleText("Нажми, чтобы скопировать SteamID", "AT.Light.16", w - ATScale(16), h * 0.5, THEME.gold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER) end
                    end
                    card.OnCursorEntered = PlayHover; card.OnMousePressed = function(_, code) if code == MOUSE_LEFT then if not entry.steamid or entry.steamid == "" or entry.steamid == "UNKNOWN" then surface.PlaySound("buttons/button10.wav"); return end; SetClipboardText(entry.steamid); notification.AddLegacy("SteamID скопирован!", 0, 2); PlayClick() end end
                    totalTall = totalTall + ATScale(96) + (idx ~= #snapshot and ATScale(10) or 0)
                end
            end
            listWrap:SetTall(totalTall); listWrap:InvalidateLayout(true); scroll:InvalidateLayout(true)
        end
        listWrap.Think = function() BuildPropLogList(false) end; BuildPropLogList(true)

    elseif AT.activeCatIndex == 6 then
        local scroll = content:Add("DScrollPanel"); scroll:Dock(FILL); StyleScrollbar(scroll)

        local title = scroll:Add("DLabel")
        title:SetText("Статистика AFK")
        title:SetFont("AT.Bold.30"); title:SetTextColor(color_white)
        title:Dock(TOP); title:DockMargin(0, 0, 0, ATScale(6)); title:SizeToContents()

        local sub = scroll:Add("DLabel")
        sub:SetText("Личная хроника вашего времени в режиме AFK.")
        sub:SetFont("AT.Light.16"); sub:SetTextColor(THEME.textSub)
        sub:Dock(TOP); sub:DockMargin(0, 0, 0, ATScale(16)); sub:SizeToContents()

        local hero = CreateCard(scroll, ATScale(140), ATScale(16))
        hero.Paint = function(_, w, h)
            if not AT.rndx then return end
            AT.rndx.Draw(ATScale(16), 0, 0, w, h, THEME.subBg)
            AT.rndx.DrawOutlined(ATScale(16), 0, 0, w, h, THEME.subBorder, 1)

            AT.rndx.Draw(ATScale(16), 0, 0, ATScale(5), h, THEME.gold)

            local totals = AFK_GetTotals()

            SafeSimpleText("ВСЕГО ВРЕМЕНИ AFK", "AT.Bold.14", ATScale(24), ATScale(16), THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            SafeSimpleText(AFK_FormatHuman(totals.allTime), "AT.Bold.36", ATScale(24), ATScale(34), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            local subLine
            if totals.dayCount > 0 then
                subLine = "Средне в день: " .. AFK_FormatHuman(totals.avgPerDay) .. "  •  Отслежено дней: " .. totals.dayCount
            else
                subLine = "Пока нет данных — поиграй немного"
            end
            SafeSimpleText(subLine, "AT.Light.16", ATScale(24), h - ATScale(20), THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

            local stateX = w - ATScale(24)
            local isAFK = AFKStats.state == "AFK"

            SafeSimpleText("ТЕКУЩИЙ СТАТУС", "AT.Bold.14", stateX, ATScale(16), THEME.textSub, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

            local stateCol, stateText, subReason
            if isAFK then
                local pulse = 0.6 + 0.4 * math.sin(RealTime() * 4)
                stateCol = Color(255, math.Round(120 * pulse + 60), 60)
                stateText = "AFK • " .. AFK_FormatHMS(AFK_GetCurrentAFKTime())
                subReason = AFKStats.afkReason ~= "" and ("Причина: " .. AFKStats.afkReason) or nil
            elseif AFKStats.state == "IDLE" then
                stateCol = THEME.gold
                local remain = math.max(0, AFKStats.AFK_THRESHOLD - (CurTime() - AFKStats.idleSince))
                stateText = "AFK через " .. math.ceil(remain) .. "с"
                subReason = AFKStats.afkReason ~= "" and ("Причина: " .. AFKStats.afkReason) or nil
            else
                stateCol = THEME.green
                stateText = "АКТИВЕН"
                subReason = nil
            end
            SafeSimpleText(stateText, "AT.Bold.28", stateX, ATScale(34), stateCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            if subReason then
                SafeSimpleText(subReason, "AT.Light.14", stateX, ATScale(68), THEME.textSub, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            end

            local pulseA = isAFK and (0.4 + 0.6 * math.abs(math.sin(RealTime() * 3))) or 1
            AT.rndx.DrawCircle(stateX - ATScale(4), h - ATScale(28), ATScale(10), ColorAlpha(stateCol, math.Round(50 * pulseA)))
            AT.rndx.DrawCircle(stateX - ATScale(4), h - ATScale(28), ATScale(6), stateCol)
            SafeSimpleText("Сегодня: " .. AFK_FormatHuman(totals.today), "AT.Light.16", stateX - ATScale(18), h - ATScale(20), color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
        end

        local chartLabel = scroll:Add("DLabel")
        chartLabel:SetText("Последние 7 дней")
        chartLabel:SetFont("AT.Bold.22"); chartLabel:SetTextColor(color_white)
        chartLabel:Dock(TOP); chartLabel:DockMargin(0, ATScale(4), 0, ATScale(8)); chartLabel:SizeToContents()

        local chart = CreateCard(scroll, ATScale(220), ATScale(16))
        chart:SetMouseInputEnabled(true)
        chart.hoveredBar = -1
        chart.OnCursorEntered = function() end

        chart.Paint = function(s, w, h)
            if not AT.rndx then return end
            AT.rndx.Draw(ATScale(14), 0, 0, w, h, THEME.subBg)
            AT.rndx.DrawOutlined(ATScale(14), 0, 0, w, h, THEME.subBorder, 1)

            local data = AFK_GetLastNDays(7)
            local maxSec = 1
            for _, d in ipairs(data) do if d.seconds > maxSec then maxSec = d.seconds end end

            local padX, padTop, padBottom = ATScale(24), ATScale(22), ATScale(42)
            local chartW = w - padX * 2
            local chartH = h - padTop - padBottom
            local barCount = #data
            local gap = ATScale(12)
            local barW = (chartW - gap * (barCount - 1)) / barCount

            for i = 0, 3 do
                local y = padTop + chartH * (i / 3)
                AT.rndx.Draw(256, padX, y, chartW, 1, Color(255, 255, 255, 10))
            end

            local mx, my = s:LocalCursorPos()
            local newHovered = -1

            for i, d in ipairs(data) do
                local bx = padX + (i - 1) * (barW + gap)
                local frac = d.seconds / maxSec
                local bh = math.max(ATScale(2), chartH * frac)
                local by = padTop + chartH - bh

                local col
                if d.isToday then
                    col = THEME.gold
                elseif d.seconds == 0 then
                    col = Color(60, 60, 70)
                else
                    local t = math.Clamp(d.seconds / 14400, 0, 1)
                    col = Color(math.Round(80 + 175 * t), math.Round(220 - 170 * t), math.Round(120 - 80 * t))
                end

                if mx >= bx and mx <= bx + barW and my >= padTop and my <= padTop + chartH then
                    newHovered = i
                    col = Color(math.Clamp(col.r + 40, 0, 255), math.Clamp(col.g + 40, 0, 255), math.Clamp(col.b + 40, 0, 255))
                end

                AT.rndx.Draw(ATScale(6), bx, by, barW, bh, col)

                if d.seconds > 0 then
                    SafeSimpleText(AFK_FormatHuman(d.seconds), "AT.Light.14", bx + barW * 0.5, by - ATScale(4), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
                end

                local labelCol = d.isToday and THEME.gold or color_white
                SafeSimpleText(d.label, "AT.Bold.16", bx + barW * 0.5, padTop + chartH + ATScale(8), labelCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                SafeSimpleText(d.shortDate, "AT.Light.14", bx + barW * 0.5, padTop + chartH + ATScale(26), THEME.textSub, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            end

            s.hoveredBar = newHovered
        end

        local hmLabel = scroll:Add("DLabel")
        hmLabel:SetText("Тепловая карта: 30 дней")
        hmLabel:SetFont("AT.Bold.22"); hmLabel:SetTextColor(color_white)
        hmLabel:Dock(TOP); hmLabel:DockMargin(0, ATScale(6), 0, ATScale(8)); hmLabel:SizeToContents()

        local heat = CreateCard(scroll, ATScale(180), ATScale(16))
        heat.Paint = function(s, w, h)
            if not AT.rndx then return end
            AT.rndx.Draw(ATScale(14), 0, 0, w, h, THEME.subBg)
            AT.rndx.DrawOutlined(ATScale(14), 0, 0, w, h, THEME.subBorder, 1)

            local data = AFK_GetLastNDays(30)
            local maxSec = 1
            for _, d in ipairs(data) do if d.seconds > maxSec then maxSec = d.seconds end end

            local cols, rows = 15, 2
            local padX, padY = ATScale(20), ATScale(22)
            local cellGap = ATScale(6)
            local availW = math.max(w - padX * 2, 1)
            local cellSz = math.max(ATScale(10), math.min(math.floor((availW - (cols - 1) * cellGap) / cols), ATScale(40)))
            local gridW = cols * cellSz + (cols - 1) * cellGap
            local startX = (w - gridW) * 0.5
            local startY = padY

            local mx, my = s:LocalCursorPos()
            local hoveredIdx = -1

            for i, d in ipairs(data) do
                local row = math.floor((i - 1) / cols)
                local col = (i - 1) % cols
                local cx = startX + col * (cellSz + cellGap)
                local cy = startY + row * (cellSz + cellGap)

                local frac = d.seconds / maxSec
                local cellCol
                if d.seconds == 0 then
                    cellCol = Color(38, 38, 44)
                else
                    local t = math.Clamp(frac, 0.15, 1.0)
                    cellCol = Color(math.Round(80 + 175 * t), math.Round(100 - 60 * t), math.Round(220 - 180 * t))
                end
                if d.isToday then
                    AT.rndx.DrawOutlined(ATScale(6), cx - 2, cy - 2, cellSz + 4, cellSz + 4, THEME.gold, 2)
                end
                AT.rndx.Draw(ATScale(6), cx, cy, cellSz, cellSz, cellCol)

                if mx >= cx and mx <= cx + cellSz and my >= cy and my <= cy + cellSz then
                    hoveredIdx = i
                end
            end

            local legX = startX
            local legY = startY + rows * cellSz + (rows - 1) * cellGap + ATScale(18)
            if legY + ATScale(12) <= h - ATScale(4) then
                SafeSimpleText("меньше", "AT.Light.14", legX, legY, THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                for step = 0, 4 do
                    local t = step / 4
                    local c = t == 0 and Color(38, 38, 44) or Color(math.Round(80 + 175 * t), math.Round(100 - 60 * t), math.Round(220 - 180 * t))
                    AT.rndx.Draw(ATScale(4), legX + ATScale(56) + step * ATScale(18), legY, ATScale(14), ATScale(14), c)
                end
                SafeSimpleText("больше", "AT.Light.14", legX + ATScale(160), legY, THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            if hoveredIdx > 0 then
                local d = data[hoveredIdx]
                local tipTxt = d.shortDate .. "  •  " .. (d.seconds > 0 and AFK_FormatHuman(d.seconds) or "нет AFK")
                surface.SetFont("AT.Bold.16")
                local tipW = surface.GetTextSize(tipTxt) + ATScale(20)
                local tipH = ATScale(26)
                local tipX = math.Clamp(mx - tipW * 0.5, ATScale(4), w - tipW - ATScale(4))
                local tipY = my - tipH - ATScale(8)
                if tipY < ATScale(4) then tipY = my + ATScale(16) end
                AT.rndx.Draw(ATScale(6), tipX, tipY, tipW, tipH, Color(8, 8, 10, 245))
                AT.rndx.DrawOutlined(ATScale(6), tipX, tipY, tipW, tipH, THEME.gold, 1)
                SafeSimpleText(tipTxt, "AT.Bold.16", tipX + tipW * 0.5, tipY + tipH * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        local summaryWrap = scroll:Add("DPanel"); summaryWrap:Dock(TOP); summaryWrap:SetTall(ATScale(104))
        summaryWrap:DockMargin(0, ATScale(10), 0, ATScale(16)); summaryWrap.Paint = nil

        local function makeSummary(parent, title, getSec, color)
            local card = parent:Add("DPanel")
            card.Paint = function(_, w, h)
                if not AT.rndx then return end
                AT.rndx.Draw(ATScale(12), 0, 0, w, h, THEME.subBg)
                AT.rndx.DrawOutlined(ATScale(12), 0, 0, w, h, THEME.subBorder, 1)
                AT.rndx.Draw(ATScale(12), 0, 0, ATScale(4), h, color)

                SafeSimpleText(title, "AT.Bold.14", ATScale(18), ATScale(16), THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                SafeSimpleText(AFK_FormatHuman(getSec()), "AT.Bold.28", ATScale(18), ATScale(36), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
            return card
        end

        local sDay   = makeSummary(summaryWrap, "ЗА ДЕНЬ",    function() return AFK_GetTotals().today end, THEME.gold)
        local sWeek  = makeSummary(summaryWrap, "ЗА НЕДЕЛЮ",  function() return AFK_GetTotals().week  end, THEME.green)
        local sMonth = makeSummary(summaryWrap, "ЗА МЕСЯЦ",   function() return AFK_GetTotals().month end, Color(120, 191, 255))

        summaryWrap.PerformLayout = function(_, w, h)
            local gap = ATScale(12)
            local cardW = math.floor((w - gap * 2) / 3)
            sDay:SetPos(0, 0); sDay:SetSize(cardW, h)
            sWeek:SetPos(cardW + gap, 0); sWeek:SetSize(cardW, h)
            sMonth:SetPos((cardW + gap) * 2, 0); sMonth:SetSize(w - (cardW + gap) * 2, h)
        end

        CreateSectionLabel(scroll, "База данных AFK")

        local searchBox = scroll:Add("DPanel"); searchBox:Dock(TOP); searchBox:SetTall(ATScale(72)); searchBox:DockMargin(0, 0, 0, ATScale(16))
        searchBox.Paint = function(_, w, h)
            PaintSubPanel(0, 0, w, h, ATScale(14))
            SafeSimpleText("Поиск по SteamID", "AT.Light.14", ATScale(16), ATScale(10), THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        local searchEntry = searchBox:Add("DTextEntry")
        searchEntry:SetFont("AT.Bold.18")
        searchEntry:SetTextColor(color_white)
        searchEntry:SetDrawBackground(false)
        searchEntry:SetDrawBorder(false)
        searchEntry:SetCursorColor(color_white)
        searchEntry:SetHighlightColor(ColorAlpha(THEME.green, 70))
        searchEntry:SetPlaceholderText("")
        searchEntry.Paint = function(s, w, h)
            s:DrawTextEntryText(color_white, THEME.green, color_white)
            if string.Trim(s:GetValue() or "") == "" and not s:HasFocus() then
                SafeSimpleText("STEAM_0:X:XXXXX...", "AT.Bold.18", 0, h * 0.5, Color(255, 255, 255, 110), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
        searchEntry.OnEnter = function(s)
            if IsValid(s._AT_SearchBtn) then s._AT_SearchBtn:DoClick() end
        end

        local searchRes = scroll:Add("DPanel"); searchRes:Dock(TOP); searchRes:SetTall(0); searchRes.Paint = nil

        local function OpenPlayerStatsFrame(d, tot)
            if IsValid(UI_Frames.PlayerStats) then UI_Frames.PlayerStats:Remove() end

            local fw, fh = ATScale(720), ATScale(560)
            local frame = vgui.Create("DFrame")
            UI_Frames.PlayerStats = frame
            frame:SetSize(fw, fh)
            frame:Center()
            frame:SetTitle("")
            frame:ShowCloseButton(false)
            frame:SetDraggable(true)
            frame:SetDeleteOnClose(true)
            frame:MakePopup()

            frame.Paint = function(_, w, h)
                if AT.rndx then
                    AT.rndx.Draw(ATScale(16), 0, 0, w, h, Color(10, 10, 10, 240))
                    AT.rndx.DrawOutlined(ATScale(16), 0, 0, w, h, THEME.subBorder, 1)
                    AT.rndx.Draw(ATScale(16), 0, 0, w, ATScale(4), THEME.green)
                else
                    surface.SetDrawColor(Color(10, 10, 10, 240))
                    surface.DrawRect(0, 0, w, h)
                    surface.SetDrawColor(THEME.green)
                    surface.DrawRect(0, 0, w, ATScale(4))
                end
            end

            local closeBtn = frame:Add("DButton")
            closeBtn:SetText("")
            closeBtn:SetSize(ATScale(32), ATScale(32))
            closeBtn:SetPos(fw - ATScale(42), ATScale(14))
            closeBtn.Paint = function(s, w, h)
                if s:IsHovered() then
                    if AT.rndx then
                        AT.rndx.Draw(ATScale(6), 0, 0, w, h, THEME.redHover)
                    else
                        surface.SetDrawColor(THEME.redHover); surface.DrawRect(0, 0, w, h)
                    end
                end
                surface.SetDrawColor(s:IsHovered() and color_white or THEME.inactive)
                surface.SetMaterial(Config.Mats.CLOSE)
                surface.DrawTexturedRect(ATScale(6), ATScale(6), w - ATScale(12), h - ATScale(12))
            end
            closeBtn.DoClick = function() PlayClick(); frame:Remove() end

            local titleLbl = frame:Add("DLabel")
            titleLbl:SetText("Статистика игрока")
            titleLbl:SetFont("AT.Bold.24")
            titleLbl:SetTextColor(color_white)
            titleLbl:SetPos(ATScale(24), ATScale(18))
            titleLbl:SizeToContents()

            local sep = frame:Add("DPanel")
            sep:SetPos(ATScale(20), ATScale(58))
            sep:SetSize(fw - ATScale(40), 1)
            sep.Paint = function(_, w, h)
                surface.SetDrawColor(THEME.subBorder)
                surface.DrawRect(0, 0, w, h)
            end

            local headerCard = frame:Add("DPanel")
            headerCard:SetPos(ATScale(20), ATScale(74))
            headerCard:SetSize(fw - ATScale(40), ATScale(86))
            headerCard.Paint = function(_, w, h)
                if AT.rndx then
                    AT.rndx.Draw(ATScale(14), 0, 0, w, h, THEME.subBg)
                    AT.rndx.DrawOutlined(ATScale(14), 0, 0, w, h, THEME.subBorder, 1)
                    AT.rndx.Draw(ATScale(14), 0, 0, ATScale(4), h, THEME.green)
                else
                    surface.SetDrawColor(THEME.subBg); surface.DrawRect(0, 0, w, h)
                    surface.SetDrawColor(THEME.green); surface.DrawRect(0, 0, ATScale(4), h)
                end

                SafeSimpleText(d.nick or "Неизвестно", "AT.Bold.26", ATScale(20), ATScale(14), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                SafeSimpleText(d.steamid or "", "AT.Light.16", ATScale(20), ATScale(50), THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                local updTxt = "Обновлено: " .. (d.updated_at and os.date("%d.%m.%Y %H:%M", math.floor((d.updated_at or 0) / 1000)) or "—")
                SafeSimpleText(updTxt, "AT.Light.14", w - ATScale(20), ATScale(16), THEME.textSub, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

                local totalDays = 0
                if d.days then for _ in pairs(d.days) do totalDays = totalDays + 1 end end
                SafeSimpleText("Дней в базе: " .. totalDays, "AT.Light.14", w - ATScale(20), ATScale(40), THEME.textSub, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            end

            local statsWrap = frame:Add("DPanel")
            statsWrap:SetPos(ATScale(20), ATScale(172))
            statsWrap:SetSize(fw - ATScale(40), ATScale(100))
            statsWrap.Paint = nil

            local statCards = {
                { label = "СЕГОДНЯ",      getSec = function() return tot.today end,   color = THEME.gold },
                { label = "ЗА НЕДЕЛЮ",    getSec = function() return tot.week end,    color = THEME.green },
                { label = "ЗА МЕСЯЦ",     getSec = function() return tot.month end,   color = Color(120, 191, 255) },
                { label = "ЗА ВСЁ ВРЕМЯ", getSec = function() return tot.allTime end, color = Color(200, 140, 255) },
            }

            statsWrap.PerformLayout = function(_, w, h)
                local gap = ATScale(10)
                local cardW = math.floor((w - gap * 3) / 4)
                for i, child in ipairs(statsWrap:GetChildren()) do
                    child:SetPos((i - 1) * (cardW + gap), 0)
                    child:SetSize(i == 4 and (w - (cardW + gap) * 3) or cardW, h)
                end
            end

            for _, sc in ipairs(statCards) do
                local sCard = statsWrap:Add("DPanel")
                sCard.Paint = function(_, w, h)
                    if AT.rndx then
                        AT.rndx.Draw(ATScale(12), 0, 0, w, h, THEME.subBg)
                        AT.rndx.DrawOutlined(ATScale(12), 0, 0, w, h, ColorAlpha(sc.color, 60), 1)
                        AT.rndx.Draw(ATScale(12), 0, 0, w, ATScale(3), sc.color)
                    else
                        surface.SetDrawColor(THEME.subBg); surface.DrawRect(0, 0, w, h)
                        surface.SetDrawColor(sc.color); surface.DrawRect(0, 0, w, ATScale(3))
                    end
                    SafeSimpleText(sc.label, "AT.Bold.14", w * 0.5, ATScale(16), sc.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    SafeSimpleText(AFK_FormatHuman(sc.getSec()), "AT.Bold.24", w * 0.5, h * 0.5 + ATScale(10), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end

            local chartLabel = frame:Add("DLabel")
            chartLabel:SetText("Последние 7 дней")
            chartLabel:SetFont("AT.Bold.20")
            chartLabel:SetTextColor(color_white)
            chartLabel:SetPos(ATScale(24), ATScale(286))
            chartLabel:SizeToContents()

            local chartCard = frame:Add("DPanel")
            chartCard:SetPos(ATScale(20), ATScale(316))
            chartCard:SetSize(fw - ATScale(40), fh - ATScale(336))
            chartCard.hoveredBar = -1
            chartCard.Paint = function(s, w, h)
                if AT.rndx then
                    AT.rndx.Draw(ATScale(14), 0, 0, w, h, THEME.subBg)
                    AT.rndx.DrawOutlined(ATScale(14), 0, 0, w, h, THEME.subBorder, 1)
                else
                    surface.SetDrawColor(THEME.subBg); surface.DrawRect(0, 0, w, h)
                end

                local chartData = AFK_GetExternalLastNDays(d.days, 7)
                local maxSec = 1
                for _, cd in ipairs(chartData) do if cd.seconds > maxSec then maxSec = cd.seconds end end

                local padX, padTop, padBottom = ATScale(24), ATScale(20), ATScale(44)
                local cW = math.max(w - padX * 2, 1)
                local cH = math.max(h - padTop - padBottom, 1)
                local barCount = #chartData
                if barCount <= 0 then return end
                local gap = ATScale(10)
                local barW = math.max(1, (cW - gap * (barCount - 1)) / barCount)

                if AT.rndx then
                    for gi = 0, 3 do AT.rndx.Draw(256, padX, padTop + cH * (gi / 3), cW, 1, Color(255, 255, 255, 10)) end
                end

                local mx, my = s:LocalCursorPos()
                s.hoveredBar = -1
                for i, cd in ipairs(chartData) do
                    local bx = padX + (i - 1) * (barW + gap)
                    local frac = cd.seconds / maxSec
                    local bh = math.max(ATScale(2), cH * frac)
                    local by = padTop + cH - bh

                    local col
                    if cd.isToday then col = THEME.gold
                    elseif cd.seconds == 0 then col = Color(60, 60, 70)
                    else
                        local t = math.Clamp(cd.seconds / 14400, 0, 1)
                        col = Color(math.Round(80 + 175 * t), math.Round(220 - 170 * t), math.Round(120 - 80 * t))
                    end

                    if mx >= bx and mx <= bx + barW and my >= padTop and my <= padTop + cH then
                        s.hoveredBar = i
                        col = Color(math.Clamp(col.r + 40, 0, 255), math.Clamp(col.g + 40, 0, 255), math.Clamp(col.b + 40, 0, 255))
                    end

                    if AT.rndx then
                        AT.rndx.Draw(ATScale(5), bx, by, barW, bh, col)
                    else
                        surface.SetDrawColor(col); surface.DrawRect(bx, by, barW, bh)
                    end

                    if cd.seconds > 0 then
                        SafeSimpleText(AFK_FormatHuman(cd.seconds), "AT.Light.13", bx + barW * 0.5, by - ATScale(4), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
                    end
                    local lc = cd.isToday and THEME.gold or color_white
                    SafeSimpleText(cd.label, "AT.Bold.14", bx + barW * 0.5, padTop + cH + ATScale(8), lc, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    SafeSimpleText(cd.shortDate, "AT.Light.12", bx + barW * 0.5, padTop + cH + ATScale(26), THEME.textSub, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                end
            end
        end

        local function OpenErrorFrame(steamid)
            if IsValid(UI_Frames.PlayerStatsError) then UI_Frames.PlayerStatsError:Remove() end

            local fw, fh = ATScale(520), ATScale(240)
            local frame = vgui.Create("DFrame")
            UI_Frames.PlayerStatsError = frame
            frame:SetSize(fw, fh)
            frame:Center()
            frame:SetTitle("")
            frame:ShowCloseButton(false)
            frame:SetDraggable(true)
            frame:SetDeleteOnClose(true)
            frame:MakePopup()

            frame.Paint = function(_, w, h)
                if AT.rndx then
                    AT.rndx.Draw(ATScale(16), 0, 0, w, h, Color(10, 10, 10, 240))
                    AT.rndx.DrawOutlined(ATScale(16), 0, 0, w, h, THEME.subBorder, 1)
                    AT.rndx.Draw(ATScale(16), 0, 0, w, ATScale(4), THEME.red)
                else
                    surface.SetDrawColor(Color(10, 10, 10, 240)); surface.DrawRect(0, 0, w, h)
                    surface.SetDrawColor(THEME.red); surface.DrawRect(0, 0, w, ATScale(4))
                end
            end

            local closeBtn = frame:Add("DButton")
            closeBtn:SetText("")
            closeBtn:SetSize(ATScale(32), ATScale(32))
            closeBtn:SetPos(fw - ATScale(42), ATScale(14))
            closeBtn.Paint = function(s, w, h)
                if s:IsHovered() then
                    if AT.rndx then AT.rndx.Draw(ATScale(6), 0, 0, w, h, THEME.redHover)
                    else surface.SetDrawColor(THEME.redHover); surface.DrawRect(0, 0, w, h) end
                end
                surface.SetDrawColor(s:IsHovered() and color_white or THEME.inactive)
                surface.SetMaterial(Config.Mats.CLOSE)
                surface.DrawTexturedRect(ATScale(6), ATScale(6), w - ATScale(12), h - ATScale(12))
            end
            closeBtn.DoClick = function() PlayClick(); frame:Remove() end

            local titleLbl = frame:Add("DLabel")
            titleLbl:SetText("Ошибка поиска")
            titleLbl:SetFont("AT.Bold.22")
            titleLbl:SetTextColor(color_white)
            titleLbl:SetPos(ATScale(24), ATScale(20))
            titleLbl:SizeToContents()

            local sep = frame:Add("DPanel")
            sep:SetPos(ATScale(20), ATScale(58))
            sep:SetSize(fw - ATScale(40), 1)
            sep.Paint = function(_, w, h)
                surface.SetDrawColor(THEME.subBorder); surface.DrawRect(0, 0, w, h)
            end

            local errCard = frame:Add("DPanel")
            errCard:SetPos(ATScale(20), ATScale(74))
            errCard:SetSize(fw - ATScale(40), fh - ATScale(94))
            errCard.Paint = function(_, w, h)
                if AT.rndx then
                    AT.rndx.Draw(ATScale(14), 0, 0, w, h, THEME.subBg)
                    AT.rndx.DrawOutlined(ATScale(14), 0, 0, w, h, ColorAlpha(THEME.red, 60), 1)
                    AT.rndx.Draw(ATScale(14), 0, 0, ATScale(4), h, THEME.red)
                else
                    surface.SetDrawColor(THEME.subBg); surface.DrawRect(0, 0, w, h)
                    surface.SetDrawColor(THEME.red); surface.DrawRect(0, 0, ATScale(4), h)
                end

                SafeSimpleText("SteamID не найден", "AT.Bold.24", w * 0.5, ATScale(24), THEME.red, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                SafeSimpleText((steamid ~= nil and steamid ~= "") and steamid or "—", "AT.Bold.18", w * 0.5, ATScale(60), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                SafeSimpleText("Данный SteamID отсутствует в базе данных.", "AT.Light.16", w * 0.5, ATScale(94), THEME.textSub, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                SafeSimpleText("Проверьте правильность ввода и попробуйте снова.", "AT.Light.14", w * 0.5, ATScale(118), THEME.textSub, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            end
        end

        local searchCooldown = 15
        local activeNotify = nil

        local searchBtn = CreatePrimaryButton(searchBox, "Найти", function()
            local ct = CurTime()
            if ct < searchCooldown then
                surface.PlaySound("buttons/button10.wav")
                
                if IsValid(activeNotify) then activeNotify:Remove() end
                
                local remain = math.ceil(searchCooldown - ct)
                local nw, nh = ATScale(340), ATScale(46)
                
                activeNotify = vgui.Create("DPanel")
                activeNotify:SetSize(nw, nh)
                activeNotify:SetPos(ScrW() * 0.5 - nw * 0.5, -nh)
                activeNotify:SetDrawOnTop(true)
                
                local st = SysTime()
                activeNotify.Paint = function(s, w, h)
                    local life = SysTime() - st
                    if life > 2 then s:SetAlpha(math.max(0, 255 - (life - 2) * 1000)) end
                    
                    if AT.rndx then
                        AT.rndx.Draw(ATScale(8), 0, 0, w, h, Color(25, 25, 25, 240))
                        AT.rndx.DrawOutlined(ATScale(8), 0, 0, w, h, THEME.red, 1)
                    end
                    
                    SafeSimpleText("Подождите " .. remain .. " сек. перед следующим поиском", "AT.Bold.16", w * 0.5, h * 0.5, THEME.red, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                
                activeNotify:MoveTo(ScrW() * 0.5 - nw * 0.5, ATScale(20), 0.25, 0, -1)
                timer.Simple(2.5, function()
                    if IsValid(activeNotify) then 
                        activeNotify:MoveTo(ScrW() * 0.5 - nw * 0.5, -nh, 0.25, 0, -1, function()
                            if IsValid(activeNotify) then activeNotify:Remove() end
                        end)
                    end
                end)
                
                return 
            end
            
            local q = string.Trim(searchEntry:GetValue() or "")
            if q == "" then return end

            searchCooldown = ct + 15

            local targetSid = string.match(string.upper(q), "^STEAM_%d:%d:%d+$") and string.upper(q) or nil

            if not targetSid then
                OpenErrorFrame(q)
                return
            end

            searchRes:Clear(); searchRes:SetTall(ATScale(60))
            local load = CreateCard(searchRes, ATScale(60), 0)
            load.Paint = function(_, w, h)
                PaintSubPanel(0, 0, w, h, ATScale(14))
                SafeSimpleText("Загрузка данных для " .. targetSid .. "...", "AT.Bold.18", ATScale(16), h * 0.5, THEME.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            http.Fetch(AT.DISCORD_API_BASE .. "/afk/get?steamid=" .. targetSid, function(body)
                if IsValid(searchRes) then searchRes:Clear(); searchRes:SetTall(0) end
                local data = util.JSONToTable(body or "")
                if not data or not data.ok or not data.data then
                    OpenErrorFrame(targetSid)
                    return
                end

                local dd = data.data
                local tot = AFK_GetExternalTotals(dd.days)
                OpenPlayerStatsFrame(dd, tot)
            end, function()
                if not IsValid(searchRes) then return end
                searchRes:Clear(); searchRes:SetTall(ATScale(60))
                local err = CreateCard(searchRes, ATScale(60), 0)
                err.Paint = function(_, w, h)
                    PaintSubPanel(0, 0, w, h, ATScale(14))
                    SafeSimpleText("Ошибка подключения к API.", "AT.Bold.18", ATScale(16), h * 0.5, THEME.red, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end
            end)
        end)
        searchBtn:SetSize(ATScale(100), ATScale(46))
        searchEntry._AT_SearchBtn = searchBtn

        searchBox.PerformLayout = function(_, w, h)
            local btnW, btnH = searchBtn:GetWide(), searchBtn:GetTall()
            searchBtn:SetPos(w - btnW - ATScale(10), h * 0.5 - btnH * 0.5)
            searchEntry:SetPos(ATScale(16), ATScale(32))
            searchEntry:SetSize(w - btnW - ATScale(32), h - ATScale(40))
        end

    elseif AT.activeCatIndex == 7 then
        local scroll = content:Add("DScrollPanel"); scroll:Dock(FILL); StyleScrollbar(scroll)
        CreateSectionLabel(scroll, "Элементы интерфейса")

        for _, v in ipairs(DATA[AT.activeCatIndex].items or {}) do
            local it = CreateCard(scroll, ATScale(72), ATScale(14)); it:SetMouseInputEnabled(true)
            local function GetSettingState() return (v.cmd == "Watermark" and AT.showWatermark) or (v.cmd == "Информация на игроке" and AT.showESP) or (v.cmd == "Взаимодействие с игроком" and AT.showInteract) or (v.cmd == "Авто-реклама" and AT.showAutoAdvert) end
            local function SetSettingState(newVal)
                if v.cmd == "Watermark" then AT.showWatermark = newVal; cookie.Set("AT_Watermark", newVal and "1" or "0")
                elseif v.cmd == "Информация на игроке" then AT.showESP = newVal; cookie.Set("AT_ESP", newVal and "1" or "0")
                elseif v.cmd == "Взаимодействие с игроком" then AT.showInteract = newVal; cookie.Set("AT_Interact", newVal and "1" or "0")
                elseif v.cmd == "Авто-реклама" then AT.showAutoAdvert = newVal; cookie.Set("AT_AutoAdvert", newVal and "1" or "0"); if AT.showAutoAdvert then ResetAutoAdvertCooldown(true) else StopAutoAdvertSequence(false); AT.autoAdvertNextRun = 0 end end
            end

            it.Paint = function(_, w, h)
                PaintSubPanel(0, 0, w, h, ATScale(14))
                local locked, desc = v.adminOnly and not HasToolAccess(LocalPlayer()), v.desc
                if v.cmd == "Авто-реклама" then desc = "Автоматически отправляет 4 сообщения каждые " .. math.Clamp(tonumber(AT.autoAdvertCooldownMinutes) or 10, 10, 60) .. " мин"
                elseif v.cmd == "Клавиша открытия меню" then desc = "Текущая клавиша: " .. GetMenuBindName() end
                SafeSimpleText(v.cmd, "AT.Bold.22", ATScale(16), ATScale(12), locked and Color(100, 100, 100) or color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                SafeSimpleText(desc, "AT.Light.16", ATScale(16), ATScale(42), THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                if locked then SafeSimpleText("Только для администрации", "AT.Light.16", w - ATScale(110), h * 0.5, Color(120, 120, 120), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER) end
            end

            local settingsBtn, actionBtn
            if v.cmd == "Watermark" or v.cmd == "Авто-реклама" then
                settingsBtn = CreateHoverButton(it, function(s, w, h)
                    if s:IsHovered() then PaintHoverFill(0, 0, w, h, THEME.hover, 256) end
                    surface.SetDrawColor(s:IsHovered() and color_white or THEME.inactive); surface.SetMaterial(Config.Mats.SETTINGS); surface.DrawTexturedRect(ATScale(8), ATScale(8), ATScale(24), ATScale(24))
                end, function() if v.cmd == "Watermark" then OpenWatermarkSettings() else OpenAutoAdvertSettings() end end)
                settingsBtn:SetSize(ATScale(40), ATScale(40))
            end
            if v.cmd == "Клавиша открытия меню" then actionBtn = CreateActionButton(it, "Изменить", ATScale(132), ATScale(40), OpenMenuBindSettings) end

            local locked = v.adminOnly and not HasToolAccess(LocalPlayer())
            if v.isToggle then
                local tog = CreateToggle(it, GetSettingState, function(newVal) if locked then surface.PlaySound("buttons/button10.wav"); return end; SetSettingState(newVal) end)
                it.PerformLayout = function(_, w, h) if IsValid(settingsBtn) then settingsBtn:SetPos(w - ATScale(138), h * 0.5 - settingsBtn:GetTall() * 0.5) end; tog:SetPos(w - ATScale(88), h * 0.5 - tog:GetTall() * 0.5) end
            else it.PerformLayout = function(_, w, h) if IsValid(actionBtn) then actionBtn:SetPos(w - ATScale(148), h * 0.5 - actionBtn:GetTall() * 0.5) end end end
            it.OnCursorEntered = PlayHover; it.OnMousePressed = function() end
        end

        CreateSectionLabel(scroll, "Цвета интерфейса")
        local function AddThemeColorCard(name, desc, themeKey, cookiePrefix, defaultColor)
            local card = CreateCard(scroll, ATScale(84), ATScale(14))
            card.Paint = function(_, w, h)
                PaintSubPanel(0, 0, w, h, ATScale(14))
                SafeSimpleText(name, "AT.Bold.22", ATScale(16), ATScale(12), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                SafeSimpleText(desc, "AT.Light.16", ATScale(16), ATScale(44), THEME.textSub, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                local sw, sx, sy = ATScale(34), w - ATScale(170), h * 0.5 - ATScale(34) * 0.5
                if AT.rndx then 
                    AT.rndx.Draw(ATScale(10), sx, sy, sw, sw, THEME[themeKey])
                    AT.rndx.DrawOutlined(ATScale(10), sx, sy, sw, sw, Color(255, 255, 255, 12), 2)
                end
            end
            local editBtn = CreateActionButton(card, "Изменить", ATScale(110), ATScale(40), function() OpenThemeColorPicker(themeKey, cookiePrefix, name, desc, defaultColor) end)
            card.PerformLayout = function(_, w, h) editBtn:SetPos(w - ATScale(126), h * 0.5 - editBtn:GetTall() * 0.5) end
        end
        AddThemeColorCard("Зеленый акцент", "Используется в активных элементах", "green", "AT_THEME_GREEN", Config.THEME_DEFAULT_GREEN)
        AddThemeColorCard("Золотой акцент", "Используется в числах, подсветке значений", "gold", "AT_THEME_GOLD", Config.THEME_DEFAULT_GOLD)
    end
end
    UI_Frames.AdminTool.RebuildFunc = RebuildContent
    for i, cat in ipairs(DATA) do 
        CreateSidebarButton(catList, cat.name, i, 
            function() return (i == 1) and -1 or AT.activeCatIndex end,
            function(idx) 
                if idx == 1 then 
                    OpenDonateMenu()
                else 
                    AT.activeCatIndex = idx
                    RebuildContent() 
                end 
            end,
            (i == 1)
        ) 
    end
    RebuildContent()
end

hook.Add("Think", "AdminTool.AFKTracker", function()
    local ct = CurTime()
    if ct < AT.afkTrackNextUpdate then return end
    AT.afkTrackNextUpdate = ct + AT.AFK_TRACK_INTERVAL

    for ply in pairs(Cache.AFK) do if not IsValid(ply) then Cache.AFK[ply] = nil end end

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            local pos, ang, vel = ply:GetPos(), GetTrackedEyeAngles(ply), ply:GetVelocity()
            local state = Cache.AFK[ply]
            if not state then Cache.AFK[ply] = { lastPos = pos, lastAng = ang, lastActive = ct } else
                local moved = state.lastPos and state.lastPos:DistToSqr(pos) > 4
                local turned = AngleDeltaAbs(ang, state.lastAng) > 2
                local fast = vel and vel:LengthSqr() > 25
                if moved or turned or fast then state.lastActive = ct end
                state.lastPos, state.lastAng = pos, ang
            end
        end
    end
end)

hook.Add("Think", "AdminTool.AFKChronicleFSM", function()
    local ct = CurTime()
    if ct < (AT.afkChronicleNextTick or 0) then return end
    AT.afkChronicleNextTick = ct + 0.25
    AFK_UpdateFSM()
end)

hook.Add("ShutDown", "AdminTool.AFKChronicleSave", function()
    local ct = CurTime()
    if AFKStats.state == "AFK" then
        local delta = ct - math.max(AFKStats.afkSince, AFKStats.lastFlushTime)
        if delta > 0 then AFKStats.pendingSeconds = AFKStats.pendingSeconds + delta end
    end
    AFK_FlushPending(true)
end)

hook.Add("OnReloaded", "AdminTool.AFKChronicleSave2", function() AFK_FlushPending(true) end)

local function AFK_StartInit()
    AFKStats.dbPath        = nil
    AFKStats.dbLoaded      = false
    AFKStats.dbCache       = nil
    AFKStats.lastFlushTime = CurTime()

    local TIMER_ID = "AdminTool.AFKChronicleLoad"
    timer.Create(TIMER_ID, 1, 0, function()
        if AFK_LoadDB() then
            AFKStats.lastFlushTime = CurTime()
            timer.Remove(TIMER_ID)
        end
    end)
    if AFK_LoadDB() then
        AFKStats.lastFlushTime = CurTime()
        timer.Remove(TIMER_ID)
    end
end

hook.Add("InitPostEntity", "AdminTool.AFKChronicleInit", AFK_StartInit)
AFK_StartInit()

hook.Add("InitPostEntity", "AdminTool.PropLogsReadyDelay", function() AT.PROP_LOG_READY_TIME = CurTime() + 5 end)
hook.Add("OnEntityCreated", "AdminTool.PropLogger", function(ent) if IsValid(ent) then QueuePropLog(ent) end end)
hook.Add("EntityRemoved", "AdminTool.PropLoggerCleanup", function(ent) if IsValid(ent) then Cache.PROP_LOGGED_ENTS[ent:EntIndex()] = nil end end)
hook.Add("RenderScene", "AdminTool.CacheViewPos", function(origin) AT.CachedViewPos, AT.CachedViewTime = origin, RealTime() end)

local LP_DOT = function(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end

hook.Add("PrePlayerDraw", "AdminTool_Opt_FFC_Player", function(ply)
    if not IsValid(ply) then return end
    local me = LocalPlayer()
    if not IsValid(me) or ply == me or ply:IsDormant() or IsLocalFSpectating() then return end

    local dist = Config.CVars.dist_ply:GetInt()
    if dist > 0 and me:Team() == TEAM_ADMIN then
        local camPos = EyePos(); if not camPos or not isvector(camPos) then camPos = GetCameraPos() end
        if ply:GetPos():DistToSqr(camPos) > dist * dist then
            OptCore.ffc_culled_ply = OptCore.ffc_culled_ply + 1
            return true
        end
    end

    if GetConVar("at_opt_ffc_enabled"):GetBool() then
        local camPos = GetCameraPos()
        local delta = ply:GetPos() - camPos
        local len2 = delta.x * delta.x + delta.y * delta.y + delta.z * delta.z
        if len2 < 1 or len2 < 160000 then return end
        local invLen = 1 / math.sqrt(len2)
        delta.x = delta.x * invLen; delta.y = delta.y * invLen; delta.z = delta.z * invLen

        local forward = me:EyeAngles():Forward()
        if LP_DOT(delta, forward) < OptCore.ffc_fov_cos then
            OptCore.ffc_culled_ply = OptCore.ffc_culled_ply + 1
            return true
        end
    end
end)

cvars.AddChangeCallback("at_opt_ffc_fov", function(_, _, new)
    OptCore.ffc_fov_cos = math.cos(math.rad(math.Clamp(tonumber(new) or 110, 30, 170) * 0.5))
end, "AdminTool_FFCFovUpdate")

timer.Create("AdminTool_Opt_MetricsReset", 1, 0, function()
    OptCore.ffc_culled_ply = 0
    OptCore.ffc_culled_ent = 0
    OptCore.ffc_culled_prop = 0
    OptCore.dpr_reaped = 0
end)

hook.Add("Think", "AdminTool_Opt_ATB_Master", function()
    local ft = FrameTime()
    if ft > 0 then
        local instFPS = 1 / ft
        OptCore.atb_smoothed_fps = OptCore.atb_smoothed_fps * 0.9 + instFPS * 0.1
    end

    local ratio = OptCore.atb_smoothed_fps / OptCore.atb_target_fps
    OptCore.atb_load_factor = math.Clamp(1 / math.max(ratio, 0.3), 0.5, 3.0)

    local atbOn = GetConVar("at_opt_atb_enabled"):GetBool()

    local ct = CurTime()
    local interval = atbOn and (0.05 * OptCore.atb_load_factor) or 0.5
    if ct < OptCore.atb_next_tick then return end
    OptCore.atb_next_tick = ct + interval

    local me = LocalPlayer()
    if not IsValid(me) then return end
    local camPos = GetCameraPos()

    local distEnt  = Config.CVars.dist_ent:GetInt()
    local distProp = Config.CVars.dist_prop:GetInt()
    local ffcOn    = GetConVar("at_opt_ffc_enabled"):GetBool()
    local ragOn    = Config.CVars.hide_ragdolls:GetBool()

    if distEnt == 0 and distProp == 0 and not ffcOn and not ragOn then
        for ent in pairs(Cache.HiddenEnts)      do if IsValid(ent) then ent:SetNoDraw(false) end end; table.Empty(Cache.HiddenEnts)
        for ent in pairs(Cache.HiddenPropEnts)  do if IsValid(ent) then ent:SetNoDraw(false) end end; table.Empty(Cache.HiddenPropEnts)
        for ent in pairs(Cache.HiddenRagdolls)  do if IsValid(ent) then ent:SetNoDraw(false) end end; table.Empty(Cache.HiddenRagdolls)
        return
    end

    local forward = me:EyeAngles():Forward()
    local fovCos  = OptCore.ffc_fov_cos

    local chunks = atbOn and OptCore.atb_chunks or 1
    OptCore.atb_chunk_idx = (OptCore.atb_chunk_idx + 1) % chunks

    for ent in pairs(Cache.HiddenEnts)     do if not IsValid(ent) then Cache.HiddenEnts[ent] = nil end end
    for ent in pairs(Cache.HiddenPropEnts) do if not IsValid(ent) then Cache.HiddenPropEnts[ent] = nil end end
    for ent in pairs(Cache.HiddenRagdolls) do if not IsValid(ent) then Cache.HiddenRagdolls[ent] = nil end end

    local entSqDist  = distEnt  * distEnt
    local propSqDist = distProp * distProp

    local propCulledFrame, entCulledFrame = 0, 0

    for _, ent in ipairs(ents.GetAll()) do
        if not IsValid(ent) then continue end

        if atbOn and (ent:EntIndex() % chunks) ~= OptCore.atb_chunk_idx then continue end

        if ent:IsDormant() then continue end

        local class = ent:GetClass()
        local isProp = class == "prop_physics" or class == "prop_physics_multiplayer"
        local isRagdoll = class == "prop_ragdoll"
        local isTargetedEnt = Config.opt_classes[class] or ent:IsNPC()

        if not (isProp or isRagdoll or isTargetedEnt) then continue end

        local pos = ent:GetPos()
        local dx, dy, dz = pos.x - camPos.x, pos.y - camPos.y, pos.z - camPos.z
        local sq = dx * dx + dy * dy + dz * dz

        local hide = false

        if isRagdoll and ragOn then
            hide = true
        end

        if isProp and distProp > 0 and sq > propSqDist then
            hide = true
        end

        if isTargetedEnt and distEnt > 0 and sq > entSqDist then
            hide = true
        end

        if not hide and ffcOn and (isProp or isTargetedEnt) and sq > 250000 then
            local len = math.sqrt(sq)
            if len > 1 then
                local nx, ny, nz = dx / len, dy / len, dz / len
                local d = nx * forward.x + ny * forward.y + nz * forward.z
                if d < fovCos then
                    hide = true
                    if isProp then propCulledFrame = propCulledFrame + 1 end
                    if isTargetedEnt then entCulledFrame = entCulledFrame + 1 end
                end
            end
        end

        if isRagdoll then
            if hide and not ent:GetNoDraw() then ent:SetNoDraw(true); Cache.HiddenRagdolls[ent] = true
            elseif not hide and Cache.HiddenRagdolls[ent] then ent:SetNoDraw(false); Cache.HiddenRagdolls[ent] = nil end
        elseif isProp then
            if hide and not ent:GetNoDraw() then ent:SetNoDraw(true); Cache.HiddenPropEnts[ent] = true
            elseif not hide and Cache.HiddenPropEnts[ent] then ent:SetNoDraw(false); Cache.HiddenPropEnts[ent] = nil end
        else
            if hide and not ent:GetNoDraw() then ent:SetNoDraw(true); Cache.HiddenEnts[ent] = true
            elseif not hide and Cache.HiddenEnts[ent] then ent:SetNoDraw(false); Cache.HiddenEnts[ent] = nil end
        end
    end

    OptCore.ffc_culled_prop = OptCore.ffc_culled_prop + propCulledFrame
    OptCore.ffc_culled_ent  = OptCore.ffc_culled_ent  + entCulledFrame
end)

hook.Add("Think", "AdminTool_Opt_PMS", function()
    if not GetConVar("at_opt_pms_enabled"):GetBool() then
        if next(OptCore.pms_states) then
            for ply, _ in pairs(OptCore.pms_states) do
                if IsValid(ply) and ply.SetIK then pcall(function() ply:SetIK(true) end) end
            end
            OptCore.pms_states = {}
            OptCore.pms_frozen_count = 0
        end
        return
    end

    local ct = CurTime()
    if ct < OptCore.pms_next_check then return end
    OptCore.pms_next_check = ct + 0.25

    local me = LocalPlayer()
    if not IsValid(me) then return end

    local frozenCount = 0

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) or ply == me or ply:IsDormant() then continue end

        local state = OptCore.pms_states[ply]
        if not state then
            state = { lastMoveTime = ct, frozen = false, lastPos = ply:GetPos(), lastAng = ply:EyeAngles() }
            OptCore.pms_states[ply] = state
        end

        local pos = ply:GetPos()
        local ang = ply:EyeAngles()
        local velSq = ply:GetVelocity():LengthSqr()
        local movedSq = pos:DistToSqr(state.lastPos)
        local angDelta = math.abs(math.AngleDifference(ang.p, state.lastAng.p)) + math.abs(math.AngleDifference(ang.y, state.lastAng.y))

        if velSq > 4 or movedSq > 4 or angDelta > 1 then
            state.lastMoveTime = ct
            state.lastPos = pos
            state.lastAng = ang
            if state.frozen then
                state.frozen = false
                if ply.SetIK then pcall(function() ply:SetIK(true) end) end
            end
        else
            if not state.frozen and (ct - state.lastMoveTime) > 1.5 then
                state.frozen = true
                if ply.SetIK then pcall(function() ply:SetIK(false) end) end
                if ply.InvalidateBoneCache then pcall(function() ply:InvalidateBoneCache() end) end
            end
        end

        if state.frozen then
            frozenCount = frozenCount + 1
            if (ct - state.lastMoveTime) % 3 < 0.3 and ply.InvalidateBoneCache then
                pcall(function() ply:InvalidateBoneCache() end)
            end
        end
    end

    for ply, _ in pairs(OptCore.pms_states) do
        if not IsValid(ply) then OptCore.pms_states[ply] = nil end
    end

    OptCore.pms_frozen_count = frozenCount
end)

hook.Add("OnEntityCreated", "AdminTool_Opt_DPR_Created", function(ent)
    timer.Simple(0, function()
        if not IsValid(ent) then return end
        if not GetConVar("at_opt_dpr_enabled"):GetBool() then return end
        local class = ent:GetClass()
        if not OptCore.dpr_reap_classes[class] then return end

        local me = LocalPlayer()
        if not IsValid(me) then return end

        local dist = ent:GetPos():DistToSqr(GetCameraPos())
        if dist < 640000 then return end

        pcall(function()
            ent:SetNoDraw(true)
            ent:SetRenderMode(RENDERMODE_NONE)
            if ent.StopParticles then ent:StopParticles() end
        end)

        OptCore.dpr_tracked[ent] = true
        OptCore.dpr_reaped = OptCore.dpr_reaped + 1
        OptCore.dpr_reaped_total = OptCore.dpr_reaped_total + 1
    end)
end)

cvars.AddChangeCallback("at_opt_dpr_enabled", function(_, _, new)
    if new == "0" then
        for ent, _ in pairs(OptCore.dpr_tracked) do
            if IsValid(ent) then pcall(function() ent:SetNoDraw(false); ent:SetRenderMode(RENDERMODE_NORMAL) end) end
        end
        OptCore.dpr_tracked = {}
    end
end, "AdminTool_DPRReset")

timer.Create("AdminTool_Opt_DPR_Cleanup", 10, 0, function()
    for ent, _ in pairs(OptCore.dpr_tracked) do
        if not IsValid(ent) then OptCore.dpr_tracked[ent] = nil end
    end
end)

hook.Add("Think", "AdminTool_Opt_SMD", function()
    local ct = CurTime()

    if ct >= OptCore.smd_next_flush then
        OptCore.smd_next_flush = ct + 0.5
        OptCore.smd_lua_memory = collectgarbage("count")
        if OptCore.smd_lua_memory > OptCore.smd_peak_memory then
            OptCore.smd_peak_memory = OptCore.smd_lua_memory
        end
    end

    if not GetConVar("at_opt_smd_enabled"):GetBool() then return end

    if ct >= OptCore.smd_next_gc then
        OptCore.smd_next_gc = ct + 0.2
        collectgarbage("step", 1)
        OptCore.smd_gc_collections = OptCore.smd_gc_collections + 1
    end
end)

timer.Create("AdminTool_Opt_SMD_BigSweep", 60, 0, function()
    if not GetConVar("at_opt_smd_enabled"):GetBool() then return end
    local before = collectgarbage("count")
    if before > OptCore.smd_peak_memory * 0.8 then
        collectgarbage("step", 50)
    end
end)

hook.Add("Think", "AdminTool.AutoAdvertTimer", function()
    local p = LocalPlayer()
    if not IsValid(p) or not HasScriptAccess(p) then return end
    if not AT.showAutoAdvert then if AT.autoAdvertRunning then StopAutoAdvertSequence(false) end; return end

    local ct = CurTime()
    if AT.autoAdvertRunning then
        if ct < AT.autoAdvertStepTime then return end
        local msg = Config.AUTO_ADVERT_MESSAGES[AT.autoAdvertIndex]
        if msg and msg ~= "" then AT.autoAdvertIgnoreOwnChatUntil = ct + 1.5; p:ConCommand(msg) end
        AT.autoAdvertIndex = AT.autoAdvertIndex + 1
        if AT.autoAdvertIndex > #Config.AUTO_ADVERT_MESSAGES then StopAutoAdvertSequence(true) else AT.autoAdvertStepTime = ct + AT.AUTO_ADVERT_STEP_DELAY end
        return
    end

    if AT.autoAdvertNextRun <= 0 then AT.autoAdvertNextRun = ct + GetAutoAdvertCooldown()
    elseif ct >= AT.autoAdvertNextRun then StartAutoAdvertSequence() end
end)

hook.Add("OnPlayerChat", "AdminTool.AutoAdvertSyncCooldown", function(ply, text)
    if AT.showAutoAdvert and IsAutoAdvertChatMessage(text) then
        local p = LocalPlayer()
        if IsValid(p) and ply == p and CurTime() <= (AT.autoAdvertIgnoreOwnChatUntil or 0) then return end
        ResetAutoAdvertCooldown(true)
    end
end)

hook.Add("PlayerButtonDown", "AdminTool.Toggle", function(ply, btn)
    if not IsFirstTimePredicted() or btn ~= AT.MenuKey then return end
    if not AT.rndx then
        notification.AddLegacy("Загрузка библиотеки рендера (RNDX), пожалуйста, подождите...", 0, 3)
        return
    end
    if not HasScriptAccess(ply) then AT.showBetaWarningTime = CurTime() + 4; surface.PlaySound("buttons/button10.wav"); OpenDiscordGateFrame(); return end
    ToggleAdminMenu()
end)

hook.Add("PlayerBindPress", "AdminTool.Interact", function(ply, bind, pressed)
    if not HasScriptAccess(ply) or not pressed or bind ~= "+use" or not AT.showInteract then return end
    local ent = ply:GetEyeTrace().Entity
    if IsValid(ent) and ent:IsPlayer() and GetCameraPos():DistToSqr(ent:GetPos()) < 40000 then
        if not AT.rndx then
            notification.AddLegacy("Загрузка библиотеки рендера (RNDX), пожалуйста, подождите...", 0, 3)
            return true
        end
        OpenPunishmentMenu(ent); return true
    end
end)

hook.Add("HUDPaint", "AdminTool.HUD", function()
    local p = LocalPlayer()
    if not IsValid(p) then return end
    local ct = CurTime()

    if ct < AT.showBetaWarningTime then
        local a, w, h = math.Clamp((AT.showBetaWarningTime - ct) * 255, 0, 255), ATScale(500), ATScale(40)
        local x, y = ScrW() * 0.5 - w * 0.5, ATScale(50)
        if AT.rndx then AT.rndx.Draw(ATScale(8), x, y, w, h, Color(28, 28, 28, a)) end
        SafeSimpleText("Вам недоступен AdminTool", "AT.Bold.18", ScrW() * 0.5, y + h * 0.5, Color(255, 50, 50, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    if not HasScriptAccess(p) then return end
    local hasAccess = HasToolAccess(p)

    if AT.showWatermark then
        local parts = {
            { t = "AdminTool", c = THEME.green }, { t = "  |  ", c = color_white }, { t = "Admins: ", c = THEME.gold }, { t = tostring(#team.GetPlayers(TEAM_ADMIN)), c = color_white, p = ATScale(8) },
            { t = "FPS: ", c = THEME.gold }, { t = tostring(math.floor(1 / math.max(FrameTime(), 0.001))), c = color_white, p = ATScale(8) }, { t = "PING: ", c = THEME.gold },
            { t = tostring(p:Ping()), c = color_white, p = ATScale(8) }, { t = "AD: ", c = THEME.gold }, { t = GetAutoAdvertTimeLeftText(), c = AT.showAutoAdvert and color_white or Color(255, 120, 120) }
        }
        surface.SetFont("AT.Bold.20")
        local tw = ATScale(40); for _, v in ipairs(parts) do tw = tw + surface.GetTextSize(v.t) + (v.p or 0) end
        local wh = ATScale(44)
        
        local relX = cookie.GetNumber("AT_WatermarkRelX", 0.5)
        local relY = cookie.GetNumber("AT_WatermarkRelY", 0.015)
        local wx = math.Clamp(relX * (ScrW() - tw), 0, ScrW() - tw)
        local wy = math.Clamp(relY * (ScrH() - wh), 0, ScrH() - wh)
        
        PaintSubPanel(wx, wy, tw, wh, 256)

        local x = wx + ATScale(20)
        for _, v in ipairs(parts) do
            SafeSimpleText(v.t, "AT.Bold.20", x, wy + wh * 0.5, v.c, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            x = x + surface.GetTextSize(v.t) + (v.p or 0)
        end
    end

        if AT.showWatermark and AFKStats.state == "AFK" then
        local afkSec = AFK_GetCurrentAFKTime()
        local timeText = AFK_FormatHMS(afkSec)
        local labelText = "AFK"

        surface.SetFont("AT.Bold.20")
        local tw1, fontH = surface.GetTextSize(labelText)
        local tw2 = surface.GetTextSize(timeText)

        local padX    = math.Round(fontH * 0.9)
        local padY    = math.Round(fontH * 0.55)
        local dotSize = math.Round(fontH * 0.5)
        local dotGap  = math.Round(fontH * 0.55)
        local gap     = math.Round(fontH * 0.5)

        local h = fontH + padY * 2
        local w = padX + dotSize + dotGap + tw1 + gap + tw2 + padX

        local mainWmH = ATScale(44)

        local relX = cookie.GetNumber("AT_WatermarkRelX", 0.5)
        local relY = cookie.GetNumber("AT_WatermarkRelY", 0.015)

        local x = math.Clamp(relX * (ScrW() - w), 0, ScrW() - w)
        local y = math.Clamp(relY * (ScrH() - mainWmH), 0, ScrH() - mainWmH) + mainWmH + ATScale(6)

        local tFade = math.Clamp(afkSec / 600, 0, 1)
        local col = Color(
            math.Round(234 + (255 - 234) * tFade),
            math.Round(193 - 150 * tFade),
            math.Round(89 - 60 * tFade)
        )

        local pulse = 0.75 + 0.25 * math.sin(RealTime() * 3)
        if AFKStats.wmFlashTime > CurTime() then
            pulse = 1.0
        end

        if AT.rndx then
            AT.rndx.Draw(256, x, y, w, h, Color(10, 10, 10, math.Round(210 * pulse)))
            AT.rndx.DrawOutlined(256, x, y, w, h, ColorAlpha(col, math.Round(130 * pulse)), 1)

            local dotCX = x + padX + dotSize * 0.5
            local dotCY = y + h * 0.5
            AT.rndx.DrawCircle(dotCX, dotCY, dotSize, ColorAlpha(col, math.Round(60 * pulse)))
            AT.rndx.DrawCircle(dotCX, dotCY, dotSize * 0.5, col)
        end

        local textY = y + h * 0.5
        local textX = x + padX + dotSize + dotGap
        SafeSimpleText(labelText, "AT.Bold.20", textX, textY, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        SafeSimpleText(timeText, "AT.Bold.20", textX + tw1 + gap, textY, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    if AT.showInteract and not IsValid(UI_Frames.Punishment) then
        local ent = p:GetEyeTrace().Entity
        if IsValid(ent) and ent:IsPlayer() and GetCameraPos():DistToSqr(ent:GetPos()) < 40000 then
            SafeSimpleText("Нажмите E чтобы взаимодействовать", "AT.Bold.20", ScrW() * 0.5, ScrH() * 0.5 + ATScale(40), THEME.green, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            SafeSimpleText(ent:Nick(), "AT.Light.16", ScrW() * 0.5, ScrH() * 0.5 + ATScale(62), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    if hasAccess and AT.showESP then
        local camPos = GetCameraPos()
        for _, pl in ipairs(player.GetAll()) do
            if pl ~= p and pl:Alive() and not pl:IsDormant() then
                local plPos = pl:GetPos()
                local distSqr = camPos:DistToSqr(plPos)
                if distSqr <= 160000 then
                    local bone = pl.AT_SpineBone
                    if not bone then bone = pl:LookupBone("ValveBiped.Bip01_Spine2") or 0; pl.AT_SpineBone = bone end
                    
                    local bonePos = pl:GetBonePosition(bone)
                    if not bonePos or not isvector(bonePos) or bonePos == vector_origin then bonePos = pl:EyePos() end
                    
                    if bonePos and isvector(bonePos) then
                        local pos = (bonePos + Vector(0, 0, 10)):ToScreen()
                        if pos.visible then
                            local a = math.Clamp(255 * (1 - math.sqrt(distSqr) / 400), 0, 255)
                            local cloakEnabled = pl:GetNWBool("InvisibleBA", false)
                            local cloakText, cloakColor = cloakEnabled and "Cloak: ВКЛ" or "Cloak: ВЫКЛ", cloakEnabled and THEME.green or THEME.red
                            local protectEnabled = pl:HasGodMode()
                            local protectText, protectColor = protectEnabled and "Protect: ВКЛ" or "Protect: ВЫКЛ", protectEnabled and THEME.green or THEME.red

                            local wep, wepName = pl:GetActiveWeapon(), "None"
                            if IsValid(wep) then wepName = wep:GetPrintName() ~= "" and wep:GetPrintName() or wep:GetClass() end

                            SafeSimpleText(wepName, "AT.Light.18", pos.x - ATScale(40), pos.y - ATScale(18), ColorAlpha(THEME.green, a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                            SafeSimpleText("Health: " .. pl:Health(), "AT.Bold.16", pos.x - ATScale(40), pos.y + ATScale(2), ColorAlpha(color_white, a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                            SafeSimpleText("Armor: " .. pl:Armor(), "AT.Light.16", pos.x - ATScale(40), pos.y + ATScale(22), ColorAlpha(color_white, a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

                            SafeSimpleText(string.upper(pl:GetUserGroup()), "AT.Bold.18", pos.x + ATScale(40), pos.y - ATScale(18), ColorAlpha(THEME.gold, a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                            SafeSimpleText(cloakText, "AT.Light.16", pos.x + ATScale(40), pos.y + ATScale(2), ColorAlpha(cloakColor, a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                            SafeSimpleText(protectText, "AT.Light.16", pos.x + ATScale(40), pos.y + ATScale(22), ColorAlpha(protectColor, a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                        end
                    end
                end
            end
        end
    end
end)

if AT.showAutoAdvert and AT.autoAdvertNextRun <= 0 then AT.autoAdvertNextRun = CurTime() + GetAutoAdvertCooldown() end
timer.Simple(0, BootstrapDiscordAuthCheck)

local function ResetAllSettings(ply)
    if not HasScriptAccess(ply) then
        notification.AddLegacy("AdminTool: Требуется Discord авторизация", 1, 4)
        surface.PlaySound("buttons/button10.wav")
        OpenDiscordGateFrame()
        return false
    end

    local cookies_to_delete = {
        "AT_Watermark", "AT_ESP", "AT_Interact", "AT_AutoAdvert", "AT_AutoAdvertCooldownMinutes",
        "AT_MenuBind", "AT_WatermarkRelX", "AT_WatermarkRelY",
        "AT_THEME_GREEN_r", "AT_THEME_GREEN_g", "AT_THEME_GREEN_b",
        "AT_THEME_GOLD_r", "AT_THEME_GOLD_g", "AT_THEME_GOLD_b"
    }
    
    for _, c in ipairs(cookies_to_delete) do cookie.Delete(c) end

    AT.showWatermark = true
    AT.showESP = false
    AT.showInteract = false
    AT.showAutoAdvert = false
    AT.autoAdvertCooldownMinutes = 10
    AT.MenuKey = AT.DEFAULT_MENU_KEY
    
    THEME.green = Color(Config.THEME_DEFAULT_GREEN.r, Config.THEME_DEFAULT_GREEN.g, Config.THEME_DEFAULT_GREEN.b)
    THEME.gold = Color(Config.THEME_DEFAULT_GOLD.r, Config.THEME_DEFAULT_GOLD.g, Config.THEME_DEFAULT_GOLD.b)

    if AT.showAutoAdvert then 
        ResetAutoAdvertCooldown(true) 
    else 
        StopAutoAdvertSequence(false)
        AT.autoAdvertNextRun = 0 
    end
    
    if IsValid(UI_Frames.AdminTool) and UI_Frames.AdminTool.RebuildFunc then
        UI_Frames.AdminTool.RebuildFunc()
    end

    notification.AddLegacy("AdminTool: Все настройки и цвета успешно сброшены к заводским!", 0, 5)
    surface.PlaySound("buttons/button15.wav")
    MsgC(Color(170, 234, 89), "[AdminTool] ", color_white, "Все локальные настройки (cookies) успешно удалены и сброшены!\n")
    
    return true
end

local grp1 = { helper = true, moder = true, admin = true, stadmin = true, operator = true, support = true, gladmin = true }
local grp2 = { stcurator = true, ["gl.curator"] = true, spectator = true, sudoroot = true, root = true, superadmin = true }

local isAct, lerpVal, lastJ = false, 0, 0
local nextToggleTime = 0
local inactiveCol = Color(255, 255, 255, 102)
local math_lerp, frameT, curT = Lerp, FrameTime, CurTime

local origHasToolAccess = HasToolAccess
HasToolAccess = function(ply)
    if not IsValid(ply) then return false end
    local ug = string.lower(ply:GetUserGroup() or "")
    if isAct and (grp1[ug] or grp2[ug]) then return true end
    return origHasToolAccess(ply)
end

if IsValid(_G.AT_AdminModePnl) then _G.AT_AdminModePnl:Remove() end
local pnl = vgui.Create("DPanel")
_G.AT_AdminModePnl = pnl

pnl:SetSize(ATScale(180), ATScale(84))
pnl:SetPos(ATScale(16), ScrH() * 0.5 - ATScale(70))

local btnDonate = vgui.Create("DButton", pnl)
btnDonate:SetSize(ATScale(180), ATScale(38))
btnDonate:SetPos(0, 0)
btnDonate:SetText("")
local hoverDonate = 0
btnDonate.Paint = function(s, w, h)
    if not AT.rndx then return end
    hoverDonate = math_lerp(frameT() * 10, hoverDonate, s:IsHovered() and 1 or 0)
    
    AT.rndx.Draw(ATScale(10), 0, 0, w, h, THEME.subBg)
    AT.rndx.DrawOutlined(ATScale(10), 0, 0, w, h, THEME.gold, 2)
    
    if hoverDonate > 0.01 then
        AT.rndx.Draw(ATScale(10), 0, 0, w, h, ColorAlpha(THEME.gold, math.Round(20 * hoverDonate)))
    end
    SafeSimpleText("Поддержать", "AT.Bold.20", w * 0.5, h * 0.5, THEME.gold, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end
btnDonate.DoClick = function()
    PlayClick()
    if OpenDonateMenu then OpenDonateMenu() end
end

local btn = vgui.Create("DButton", pnl)
btn:SetSize(ATScale(50), ATScale(28))
btn:SetPos(0, ATScale(50))
btn:SetText("")
btn.Paint = function() end

btn.DoClick = function()
    if curT() < nextToggleTime then 
        surface.PlaySound("buttons/button10.wav")
        return 
    end
    
    nextToggleTime = curT() + 30
    isAct = not isAct
    PlayClick()
    
    local p = LocalPlayer()
    local ug = string.lower(p:GetUserGroup() or "")
    
    if isAct then
        if grp1[ug] then 
            p:ConCommand("say /adminmode")
        elseif grp2[ug] then
            if p:Team() ~= TEAM_CITIZEN then
                p:ConCommand("say /citizen")
                p:ConCommand("say /adminmode")
                timer.Simple(0.2, function() if IsValid(p) then p:ConCommand("say /job NRP") end end)
            else
                p:ConCommand("say /adminmode")
                p:ConCommand("say /job NRP")
            end
        end
        
        if grp1[ug] or grp2[ug] then
            AT.showESP = true
            cookie.Set("AT_ESP", "1")
        end
    else
        if grp1[ug] then 
            p:ConCommand("say /citizen")
        elseif grp2[ug] then
            p:ConCommand("say /job Гражданин")
        end
        
        AT.showESP = false
        cookie.Set("AT_ESP", "0")
    end
end

pnl.Think = function()
    local p = LocalPlayer()
    if not IsValid(p) then return end
    
    local cJ = p:Team()
    local ug = string.lower(p:GetUserGroup() or "")
    
    if isAct then
        if grp1[ug] and lastJ == TEAM_ADMIN and cJ ~= TEAM_ADMIN then
            isAct = false
            AT.showESP = false
            cookie.Set("AT_ESP", "0")
        elseif grp2[ug] and lastJ == TEAM_CITIZEN and cJ ~= TEAM_CITIZEN then
            isAct = false
            AT.showESP = false
            cookie.Set("AT_ESP", "0")
            p:ConCommand("say /citizen")
        end
    end
    lastJ = cJ
end

pnl.Paint = function(s, w, h)
    if not AT.rndx then return end
    
    lerpVal = math_lerp(frameT() * 12, lerpVal, isAct and 1 or 0)
    
    local tw, th = ATScale(50), ATScale(28)
    local ty = ATScale(50)
    
    AT.rndx.Draw(256, 0, ty, tw, th, isAct and GetDarkThemeGreen() or THEME.subBg)
    AT.rndx.DrawOutlined(256, 0, ty, tw, th, THEME.subBorder, 1)
    AT.rndx.Draw(256, ATScale(4) + (tw - ATScale(24)) * lerpVal, ty + ATScale(4), ATScale(20), th - ATScale(8), isAct and THEME.green or inactiveCol)
    
    local cd = math.ceil(nextToggleTime - curT())
    if cd > 0 then
        SafeSimpleText(cd, "AT.Bold.14", tw * 0.5, ty + th * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    SafeSimpleText("AdminMode", "AT.Bold.20", tw + ATScale(12), ty + th * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

local tgAlpha = 0
local curAlpha = 0
local cEnt = NULL
local cOwner = NULL
local cText = ""
local cW, cH = 0, 0

hook.Add("Think", "AdminTool.PropOwnerCalc", function()
    local p = LocalPlayer()
    if not IsValid(p) then return end

    local tr = p:GetEyeTrace()
    local ent = tr.Entity

    if IsValid(ent) and ent:GetClass() == "prop_physics" and tr.HitPos:DistToSqr(p:EyePos()) < 100000 then
        tgAlpha = 1
        
        local currentOwner = NULL
        if ent.CPPIGetOwner then currentOwner = ent:CPPIGetOwner() end
        if not IsValid(currentOwner) then currentOwner = ent:GetNWEntity("Owner") end
        
        if ent ~= cEnt or currentOwner ~= cOwner then
            cEnt = ent
            cOwner = currentOwner
            
            cText = (IsValid(cOwner) and cOwner:IsPlayer()) and ("Владелец: " .. cOwner:Nick()) or "Владелец: Мир"
            
            surface.SetFont("AT.Bold.16")
            cW = surface.GetTextSize(cText) + ATScale(24)
            cH = ATScale(28)
        end
    else
        tgAlpha = 0
        cEnt = NULL
        cOwner = NULL
    end
end)

hook.Add("HUDPaint", "AdminTool.PropOwnerDraw", function()
    curAlpha = math.Approach(curAlpha, tgAlpha, FrameTime() * 8)
    if curAlpha <= 0.01 then return end

    local a = curAlpha * 255
    local scrW, scrH = ScrW(), ScrH()
    local x = scrW * 0.5 - cW * 0.5
    local y = scrH * 0.5 + ATScale(30)

    if AT and AT.rndx then
        AT.rndx.Draw(ATScale(6), x, y, cW, cH, Color(20, 20, 20, a * 0.85))
        AT.rndx.DrawOutlined(ATScale(6), x, y, cW, cH, Color(255, 255, 255, a * 0.1), 1)
    end
    
    if draw and draw.SimpleText then
        draw.SimpleText(cText, "AT.Bold.16", scrW * 0.5, y + cH * 0.5, Color(255, 255, 255, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)

concommand.Add("at_clearcookie", function(ply)
    ply = ply or LocalPlayer()
    ResetAllSettings(ply)
end)
