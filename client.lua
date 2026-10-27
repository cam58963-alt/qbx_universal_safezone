local insideZones = {}
local activeZones = {}
local debugBlips = {}
local zoneThreads = {}
local notificationCooldowns = {}
local weaponCooldowns = {}

-- ============================================================
--  ユーティリティ関数
-- ============================================================

local function DebugLog(message)
    if Config.Debug then
        print(('[qbx_universal_safezone] %s'):format(message))
    end
end

local function ShowNotification(message, msgType, zoneKey, duration)
    local key = zoneKey or 'global'
    local now = GetGameTimer()
    if notificationCooldowns[key] and now < notificationCooldowns[key] then return end
    notificationCooldowns[key] = now + 2000

    lib.notify({
        title = msgType == 'success' and '🛡️ 職務免除' or
                msgType == 'error' and '⚠️ 警告' or
                '🔒 セーフゾーン',
        description = message,
        type = msgType or 'info',
        duration = duration or 4000,
        position = 'top'  -- 見やすい位置に変更
    })
end

-- ============================================================
--  デバッグ判定ヘルパー
-- ============================================================

--- ゾーンのデバッグ表示が有効かどうかを判定
---@param zoneConfig table
---@return boolean
local function IsZoneDebugEnabled(zoneConfig)
    if not Config.Debug then return false end        -- マスターOFFなら全て無効
    if zoneConfig.debug == nil then return false end -- 未設定ならデフォルトOFF
    return zoneConfig.debug                          -- 個別設定を返す
end

-- ============================================================
--  設定解決ヘルパー（変更なし）
-- ============================================================

local function GetFacilityDefaults(zoneConfig)
    return Config.FacilityTypes[zoneConfig.facilityType] or Config.FacilityTypes['public']
end

local function GetRestrictionLevel(zoneConfig)
    return zoneConfig.restrictionLevel or GetFacilityDefaults(zoneConfig).restrictionLevel or 'strict'
end

local function GetIcon(zoneConfig)
    return zoneConfig.icon or GetFacilityDefaults(zoneConfig).icon or '🔒'
end

local function GetMessage(zoneConfig, msgKey)
    local defaults = GetFacilityDefaults(zoneConfig)
    local message = (zoneConfig.messages and zoneConfig.messages[msgKey]) or
                   (defaults.messages and defaults.messages[msgKey]) or ''
    return string.format(message, ('%s %s'):format(GetIcon(zoneConfig), zoneConfig.label))
end

local function GetBlipSettings(zoneConfig)
    return zoneConfig.blip or GetFacilityDefaults(zoneConfig).blip or { sprite = 1, color = 0, scale = 0.8 }
end

local function GetExemptJobs(zoneConfig)
    if not zoneConfig.exemptJobs then return Config.GlobalExemptJobs end
    if zoneConfig.useGlobalExempt == false then return zoneConfig.exemptJobs end
    
    local merged, seen = {}, {}
    for _, job in ipairs(Config.GlobalExemptJobs) do
        if not seen[job] then seen[job] = true; table.insert(merged, job) end
    end
    for _, job in ipairs(zoneConfig.exemptJobs) do
        if not seen[job] then seen[job] = true; table.insert(merged, job) end
    end
    return merged
end

-- ============================================================
--  ジョブ免除判定（変更なし）
-- ============================================================

local function CheckJobExemption(zoneConfig)
    local playerData = exports.qbx_core:GetPlayerData()
    if not playerData or not playerData.job then return false end

    local jobName = playerData.job.name
    local jobGrade = playerData.job.grade and playerData.job.grade.level or 0

    for _, exemptJob in ipairs(GetExemptJobs(zoneConfig)) do
        if jobName == exemptJob then
            local minGrade = Config.MinimumGrades and Config.MinimumGrades[jobName]
            if minGrade and jobGrade < minGrade then return false end
            DebugLog(('免除適用: %s (Gr:%d)'):format(jobName, jobGrade))
            return true
        end
    end
    return false
end

-- ============================================================
--  確実な武器収納システム（3段階フォールバック）
-- ============================================================

--- 武器を確実に収納（ox_inventory対応 + フォールバック）
local function ForceHolsterWeapon(zoneName)
    local ped = cache.ped or PlayerPedId()
    local success = false
    
    -- 段階1: ox_inventory連携（推奨）
    if GetResourceState('ox_inventory') == 'started' then
        local oxSuccess = pcall(function()
            if exports.ox_inventory and exports.ox_inventory.disarm then
                exports.ox_inventory:disarm()
                return true
            end
        end)
        
        if oxSuccess then
            DebugLog(('ox_inventory:disarm成功: %s'):format(zoneName))
            success = true
        end
    end
    
    -- 段階2: ネイティブ収納（フォールバック）
    if not success then
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        DebugLog(('ネイティブ収納実行: %s'):format(zoneName))
        success = true
    end
    
    -- 段階3: 最終手段（緊急時のみ）
    CreateThread(function()
        Wait(1000)  -- 収納処理の完了を待つ
        if GetSelectedPedWeapon(ped) ~= `WEAPON_UNARMED` then
            RemoveAllPedWeapons(ped, true)
            DebugLog(('緊急武器削除実行: %s'):format(zoneName))
        end
    end)
    
    return success
end

-- ============================================================
--  毎フレーム制限処理（修正版）
-- ============================================================

local function ApplyRestrictions(zoneConfig)
    local ped = cache.ped or PlayerPedId()
    local level = GetRestrictionLevel(zoneConfig)

    -- 全レベル共通: 発砲禁止
    DisablePlayerFiring(ped, true)

    -- moderate・strict: 攻撃コントロール無効化
    if level == 'moderate' or level == 'strict' then
        for _, ctrl in ipairs(Config.Controls.attack) do
            DisableControlAction(0, ctrl, true)
        end

        if IsPedInMeleeCombat(ped) then
            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
            ShowNotification(GetMessage(zoneConfig, 'violation'), 'error', zoneConfig.name)
        end
    end

    -- strict: 武器制御（SetPedCanSwitchWeaponは使用しない）
    if level == 'strict' then
        -- ox_inventoryのショートカットキーを無効化
        DisableControlAction(0, 37, true)  -- TAB（武器ホイール）
        DisableControlAction(0, 157, true) -- 1キー
        DisableControlAction(0, 158, true) -- 2キー  
        DisableControlAction(0, 159, true) -- 3キー
        DisableControlAction(0, 160, true) -- 4キー
        DisableControlAction(0, 161, true) -- 5キー
        
        -- その他の武器選択コントロール
        for _, ctrl in ipairs(Config.Controls.weaponSelect) do
            DisableControlAction(0, ctrl, true)
        end

        -- 武器を持っていたら即座に収納
        local currentWeapon = GetSelectedPedWeapon(ped)
        if currentWeapon ~= `WEAPON_UNARMED` then
            local now = GetGameTimer()
            local cooldownKey = 'holster_' .. zoneConfig.name

            -- 収納処理は毎回実行、通知のみクールダウン管理
            ForceHolsterWeapon(zoneConfig.name)

            if not weaponCooldowns[cooldownKey] or now > weaponCooldowns[cooldownKey] then
                ShowNotification(GetMessage(zoneConfig, 'weapon_blocked'), 'error', zoneConfig.name)
                weaponCooldowns[cooldownKey] = now + 2000
            end
        end
    end
end

local function StartZoneThread(zoneConfig)
    local zoneName = zoneConfig.name
    if zoneThreads[zoneName] then return end

    zoneThreads[zoneName] = CreateThread(function()
        DebugLog(('制御スレッド開始: %s'):format(zoneName))
        while activeZones[zoneName] do
            Wait(0)
            ApplyRestrictions(zoneConfig)
        end
        zoneThreads[zoneName] = nil
        DebugLog(('制御スレッド終了: %s'):format(zoneName))
    end)
end

local function StopZoneThread(zoneName)
    activeZones[zoneName] = nil
end

-- ============================================================
--  ゾーンイベントハンドラ（修正版）
-- ============================================================

local function FindZoneConfig(name)
    for _, zone in ipairs(Config.SafeZones) do
        if zone.name == name then return zone end
    end
    return nil
end

local function OnEnterZone(self)
    local zoneConfig = FindZoneConfig(self.name)
    if not zoneConfig then return end

    insideZones[zoneConfig.name] = zoneConfig

    if CheckJobExemption(zoneConfig) then
        ShowNotification(Config.CommonMessages.exempt_job.description, 'success', zoneConfig.name, 3000)
        return
    end

    activeZones[zoneConfig.name] = zoneConfig

    -- strict入場時の即座収納（SetPedCanSwitchWeaponは使用しない）
    if GetRestrictionLevel(zoneConfig) == 'strict' and Config.WeaponControl.forceHolster then
        ForceHolsterWeapon(zoneConfig.name)
    end

    ShowNotification(GetMessage(zoneConfig, 'enter'), 'info', zoneConfig.name)
    StartZoneThread(zoneConfig)

    DebugLog(('ゾーン入場[%s]: %s'):format(GetRestrictionLevel(zoneConfig), zoneConfig.name))
end

local function OnExitZone(self)
    local zoneConfig = FindZoneConfig(self.name)
    if not zoneConfig then return end

    insideZones[zoneConfig.name] = nil

    if activeZones[zoneConfig.name] then
        StopZoneThread(zoneConfig.name)
        ShowNotification(GetMessage(zoneConfig, 'exit'), 'info', zoneConfig.name, 3000)
        DebugLog(('ゾーン退場: %s'):format(zoneConfig.name))
    end
end

-- ============================================================
--  ジョブ変更時のリアルタイム処理（修正版）
-- ============================================================

local function HandleJobChangeInZones()
    for zoneName, zoneConfig in pairs(insideZones) do
        local isNowExempt = CheckJobExemption(zoneConfig)
        local isCurrentlyRestricted = activeZones[zoneName] ~= nil

        if isNowExempt and isCurrentlyRestricted then
            StopZoneThread(zoneName)
            ShowNotification(Config.CommonMessages.exempt_job.description, 'success', zoneName, 4000)
            DebugLog(('ジョブ変更で制限解除: %s'):format(zoneName))

        elseif not isNowExempt and not isCurrentlyRestricted then
            activeZones[zoneName] = zoneConfig
            if GetRestrictionLevel(zoneConfig) == 'strict' and Config.WeaponControl.forceHolster then
                ForceHolsterWeapon(zoneName)
            end
            ShowNotification(GetMessage(zoneConfig, 'enter'), 'info', zoneName)
            StartZoneThread(zoneConfig)
            DebugLog(('ジョブ変更で制限適用: %s'):format(zoneName))
        end
    end
end

RegisterNetEvent('QBX:Client:OnJobUpdate', function(jobData)
    HandleJobChangeInZones()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    HandleJobChangeInZones()
end)

-- ============================================================
--  初期化・デバッグ・クリーンアップ（既存と同じ）
-- ============================================================

local function CreateDebugBlips()
    if not Config.Debug then return end

    for _, zone in ipairs(Config.SafeZones) do
        -- 個別デバッグ判定
        if not IsZoneDebugEnabled(zone) then
            DebugLog(('デバッグスキップ: %s'):format(zone.name))
            goto continue
        end

        local blipCfg = GetBlipSettings(zone)

        -- 範囲ブリップ
        local radiusBlip = AddBlipForRadius(
            zone.coords.x, zone.coords.y, zone.coords.z, zone.radius
        )
        SetBlipColour(radiusBlip, blipCfg.color)
        SetBlipAlpha(radiusBlip, 100)

        -- 中心ブリップ
        local centerBlip = AddBlipForCoord(
            zone.coords.x, zone.coords.y, zone.coords.z
        )
        SetBlipSprite(centerBlip, blipCfg.sprite)
        SetBlipColour(centerBlip, blipCfg.color)
        SetBlipScale(centerBlip, blipCfg.scale)
        SetBlipAsShortRange(centerBlip, true)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(
            ('[DEBUG] %s %s'):format(GetIcon(zone), zone.label)
        )
        EndTextCommandSetBlipName(centerBlip)

        table.insert(debugBlips, radiusBlip)
        table.insert(debugBlips, centerBlip)

        DebugLog(('デバッグブリップ作成: %s'):format(zone.name))

        ::continue::
    end

    DebugLog('個別デバッグブリップ作成完了')
end

local function RemoveDebugBlips()
    for _, blip in ipairs(debugBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    debugBlips = {}
end

CreateThread(function()
    CreateDebugBlips()

    for i, zoneConfig in ipairs(Config.SafeZones) do
        lib.zones.sphere({
            coords = zoneConfig.coords,
            radius = zoneConfig.radius,
            debug = IsZoneDebugEnabled(zoneConfig),  -- ★個別判定でox_libの円表示制御
            name = zoneConfig.name,
            onEnter = OnEnterZone,
            onExit = OnExitZone
        })

        DebugLog(('ゾーン作成: [%s] %s debug=%s'):format(
            zoneConfig.facilityType,
            zoneConfig.name,
            tostring(IsZoneDebugEnabled(zoneConfig))
        ))
    end

    DebugLog('汎用セーフゾーンシステム初期化完了')
end)

if Config.Debug then
    RegisterCommand('safezone_status', function()
        local ped = cache.ped or PlayerPedId()
        local coords = GetEntityCoords(ped)
        local playerData = exports.qbx_core:GetPlayerData()
        local jobName = playerData and playerData.job and playerData.job.name or 'Unknown'
        local jobGrade = playerData and playerData.job and playerData.job.grade and playerData.job.grade.level or 0

        local insideList, activeList = {}, {}
        for name, _ in pairs(insideZones) do table.insert(insideList, name) end
        for name, cfg in pairs(activeZones) do
            table.insert(activeList, ('%s[%s]'):format(name, GetRestrictionLevel(cfg)))
        end

        lib.notify({
            title = '🔍 セーフゾーン詳細状態',
            description = ('座標: (%.1f, %.1f, %.1f)\nジョブ: %s (Gr:%d)\n物理的内部: %s\n制限適用: %s'):format(
                coords.x, coords.y, coords.z, jobName, jobGrade,
                #insideList > 0 and table.concat(insideList, ', ') or 'なし',
                #activeList > 0 and table.concat(activeList, ', ') or 'なし'
            ),
            type = 'info',
            duration = 8000,
            position = 'top'
        })
    end, false)

    RegisterCommand('safezone_weapon', function()
        local ped = cache.ped or PlayerPedId()
        local weapon = GetSelectedPedWeapon(ped)
        lib.notify({
            title = '🔫 武器状態',
            description = ('現在武器: %s'):format(weapon == `WEAPON_UNARMED` and '素手' or tostring(weapon)),
            type = 'info',
            duration = 4000,
            position = 'top'
        })
    end, false)

    RegisterCommand('safezone_debug', function(source, args)
        local zoneName = args[1]
        if not zoneName or zoneName == '' then
            ShowNotification('使用方法: /safezone_debug <ゾーン名>', 'error')
            return
        end

        -- ゾーン検索
        local targetZone = nil
        for _, zone in ipairs(Config.SafeZones) do
            if zone.name == zoneName then
                targetZone = zone
                break
            end
        end

        if not targetZone then
            ShowNotification(('ゾーン "%s" が見つかりません'):format(zoneName), 'error')
            return
        end

        -- デバッグ状態を切り替え
        targetZone.debug = not (targetZone.debug or false)
        
        ShowNotification(
            ('ゾーン "%s" のデバッグ表示: %s'):format(
                zoneName, 
                targetZone.debug and 'ON' or 'OFF'
            ),
            'info'
        )

        -- ブリップを再生成
        RemoveDebugBlips()
        CreateDebugBlips()
        
        DebugLog(('ランタイムデバッグ切り替え: %s = %s'):format(zoneName, targetZone.debug))
    end, false)
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    RemoveDebugBlips()
    activeZones = {}
    insideZones = {}
end)
