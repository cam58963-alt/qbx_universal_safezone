Config = {}

-- ============================================================
--  デバッグ設定（マスタースイッチは維持）
-- ============================================================
Config.Debug = false-- 全体機能（コマンド・ログ）のON/OFF

-- ============================================================
--  グローバル免除ジョブ設定
--  全施設共通で制限を受けないジョブ
-- ============================================================
Config.GlobalExemptJobs = {
    'police',       -- 警察
    --'ambulance',    -- 救急隊員
    'admin'         -- 管理者
}

-- ============================================================
--  グレード別制限設定（オプション）
-- ============================================================
Config.MinimumGrades = {
    -- ['police'] = 2,   -- 警察はグレード2以上のみ免除
    -- ['ambulance'] = 0 -- 救急は全グレード免除
}

-- ============================================================
--  施設タイプ定義
--
--  制限レベル:
--  'strict'  : 武器取り出し・攻撃・発砲すべて禁止（強制収納）
--  'moderate': 発砲・攻撃のみ禁止（武器所持は許可）
--  'light'   : 発砲のみ禁止
-- ============================================================
Config.FacilityTypes = {
    
    hospital = {
        label = '病院',
        icon = '🏥',
        restrictionLevel = 'strict',
        blip = {
            sprite = 61,
            color = 2,
            scale = 0.8
        },
        messages = {
            enter = '%s セーフゾーンに入りました。',
            exit = '%s セーフゾーンから出ました。',
            weapon_blocked = '病院エリア内では武器を取り出すことはできません！',
            violation = '病院エリア内での暴力行為は禁止されています！'
        }
    },

    restaurant = {
        label = '飲食店',
        icon = '🍽️',
        restrictionLevel = 'strict',
        blip = {
            sprite = 93,
            color = 5,
            scale = 0.7
        },
        messages = {
            enter = '%s セーフゾーンに入りました。',
            exit = '%s セーフゾーンから出ました。',
            weapon_blocked = '店内では武器を取り出すことはできません！',
            violation = '店内での暴力行為は禁止されています！'
        }
    },

    public = {
        label = '共用施設',
        icon = '🏛️',
        restrictionLevel = 'strict',
        blip = {
            sprite = 408,
            color = 3,
            scale = 0.7
        },
        messages = {
            enter = '%s セーフゾーンに入りました。',
            exit = '%s セーフゾーンから出ました。',
            weapon_blocked = '施設内では武器を取り出すことはできません！',
            violation = '施設内での暴力行為は禁止されています！'
        }
    },

    shopping = {
        label = 'ショッピング施設',
        icon = '🛒',
        restrictionLevel = 'strict',
        blip = {
            sprite = 59,
            color = 4,
            scale = 0.7
        },
        messages = {
            enter = '%s セーフゾーンに入りました。発砲は禁止されています。',
            exit = '%s セーフゾーンから出ました。',
            weapon_blocked = 'ショッピングエリア内では武器を取り出すことはできません！',
            violation = 'ショッピングエリア内での発砲は禁止されています！'
        }
    }
}

-- ============================================================
--  セーフゾーン定義
-- ============================================================
Config.SafeZones = {
    
    -- 病院
    {
        name = 'pillbox_hospital',
        label = '石川病院',
        coords = vec3(1156.91, -1537.13, 33.84),
        radius = 75.0,
        facilityType = 'hospital',
        debug = false-- 本番では非表示
    },
    {
        name = 'paleto_hospital',
        label = '朝霧クリニック',
        coords = vec3(-248.46, 6331.73, 31.43),
        radius = 40.0,
        facilityType = 'hospital',
        debug = false  -- 本番では非表示
    },

    -- 飲食店（例）
    --[[{
        name = 'burger_shot_main',
        label = 'バーガーショット本店',
        coords = vec3(-1193.34, -892.24, 14.0),
        radius = 25.0,
        facilityType = 'restaurant',
        icon = '🍔',
        -- 個別免除設定の例
        exemptJobs = { 'police', 'admin' },
        useGlobalExempt = false.
        debug = true   -- ★調整中なので表示ON
    },
    {
        name = 'cluckin_bell',
        label = 'クラッキンベル',
        coords = vec3(-146.15, -256.59, 43.62),
        radius = 20.0,
        facilityType = 'restaurant',
        icon = '🍗',
        debug = true   -- ★調整中なので表示ON
    },

    -- 共用施設（例）
    {
        name = 'city_hall',
        label = '市役所',
        coords = vec3(-544.9, -204.4, 38.2),
        radius = 40.0,
        facilityType = 'public',
        debug = true   -- ★調整中なので表示ON
    },

    -- ショッピング施設（例）
    {
        name = 'suburban_main',
        label = 'サバーバン本店',
        coords = vec3(123.49, -220.38, 54.56),
        radius = 25.0,
        facilityType = 'shopping',
        debug = true   -- ★調整中なので表示ON
    }]]
}

-- ============================================================
--  武器制御設定
-- ============================================================
Config.WeaponControl = {
    forceHolster = true,        -- strict入場時の強制収納
    holsterCooldown = 2000      -- 武器警告通知のクールダウン
}

-- ============================================================
--  共通メッセージ
-- ============================================================
Config.CommonMessages = {
    exempt_job = {
        title = '🛡️ 職務免除',
        description = 'あなたの職業はセーフゾーンの制限が免除されています。',
        type = 'success',
        duration = 3000
    }
}

-- ============================================================
--  制御コントロール
-- ============================================================
Config.Controls = {
    attack = {
        24, 25, 47, 58, 140, 141, 142, 257, 263, 264
    },
    weaponSelect = {
        37, 157, 158, 159, 160, 161, 162, 163, 164, 165
    }
}
