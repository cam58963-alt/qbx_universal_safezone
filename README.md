# qbx_universal_safezone

病院・飲食店・共用施設・ショッピング施設などに「セーフゾーン」を設定し、エリア内での武器の取り出し・攻撃・発砲を制限する Qbox (qbx_core) 向けの汎用スクリプトです。

## 主な機能

- 球形ゾーン（`ox_lib` の `lib.zones.sphere`）によるセーフゾーン判定
- 施設タイプごとの制限レベル
  | レベル | 内容 |
  | --- | --- |
  | `strict` | 武器の取り出し・攻撃・発砲をすべて禁止（所持中の武器は強制収納） |
  | `moderate` | 攻撃・発砲を禁止（武器の所持は可） |
  | `light` | 発砲のみ禁止 |
- ジョブ単位の免除（全体共通 / ゾーン個別 / 最低グレード指定）
- ジョブ変更時に制限状態を自動で再判定
- 入退場・違反時の通知（`lib.notify`）
- ゾーン単位のデバッグ表示（範囲円・ブリップ）とデバッグ用コマンド

## 依存リソース

- [qbx_core](https://github.com/Qbox-project/qbx_core)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_inventory](https://github.com/overextended/ox_inventory)（任意。あれば `disarm` で武器を収納します）

## インストール

1. このリポジトリを `resources` フォルダに配置します（フォルダ名は `qbx_universal_safezone`）。
2. `server.cfg` に追加します。依存リソースより後に起動してください。
   ```cfg
   ensure ox_lib
   ensure qbx_core
   ensure qbx_universal_safezone
   ```
3. `config.lua` を編集してゾーンを設定します。

## 設定（`config.lua`）

| 項目 | 説明 |
| --- | --- |
| `Config.Debug` | デバッグ機能全体の ON/OFF。`true` のときだけデバッグ用コマンドとログ、デバッグブリップが有効になります |
| `Config.GlobalExemptJobs` | 全ゾーン共通で制限を受けないジョブ |
| `Config.MinimumGrades` | 免除に必要な最低グレード（例: `['police'] = 2`） |
| `Config.FacilityTypes` | 施設タイプの定義（ラベル、アイコン、制限レベル、ブリップ、メッセージ） |
| `Config.SafeZones` | セーフゾーンの一覧 |
| `Config.WeaponControl` | `forceHolster`: 入場時・ジョブ変更時の強制収納の ON/OFF（下記の補足参照）。`holsterCooldown` は現在使われていません |
| `Config.CommonMessages` | 免除時の通知など共通メッセージ |
| `Config.Controls` | 無効化する攻撃・武器選択のコントロール番号 |

### ゾーンの追加例

```lua
Config.SafeZones = {
    {
        name = 'pillbox_hospital',      -- 一意の名前
        label = '石川病院',              -- 通知に表示される名前
        coords = vec3(1156.91, -1537.13, 33.84),
        radius = 75.0,                  -- 半径（m）
        facilityType = 'hospital',      -- Config.FacilityTypes のキー
        restrictionLevel = 'strict',    -- 任意: 施設タイプの制限レベルを上書き
        icon = '🏥',                     -- 任意: 施設タイプのアイコンを上書き
        exemptJobs = { 'ambulance' },   -- 任意: このゾーンだけの免除ジョブ
        useGlobalExempt = true,         -- 任意: false なら GlobalExemptJobs を使わない
        debug = false                   -- 任意: このゾーンのデバッグ表示
    },
}
```

`exemptJobs` を指定した場合、通常は `GlobalExemptJobs` と合算されます。`useGlobalExempt = false` にするとゾーン個別の設定だけが使われます。

## デバッグ用コマンド

`Config.Debug = true` のときのみ登録されます。

| コマンド | 内容 |
| --- | --- |
| `/safezone_status` | 現在座標・ジョブ・入っているゾーン・適用中の制限を表示 |
| `/safezone_weapon` | 現在手に持っている武器を表示 |
| `/safezone_debug <ゾーン名>` | 指定ゾーンのデバッグ表示（ブリップ）を切り替え |

## 補足

- ブリップは `Config.Debug = true` かつそのゾーンの `debug = true` のときだけ表示されます。本番では `false` のままにしてください。
- `forceHolster = false` にしても、`strict` ゾーン内で武器を持った時点の自動収納は止まりません（止まるのは入場時・ジョブ変更時の収納だけです）。
- 武器警告通知のクールダウンは `client.lua` 内で 2000 ミリ秒に固定されており、`holsterCooldown` の値は反映されません。
- `strict` の武器収納は `ox_inventory` の `disarm` → ネイティブによる収納の順で試行します。1 秒後もまだ武器を持っている場合は、最終手段としてペッドの武器をすべて削除します。
