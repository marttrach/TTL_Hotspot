# LuCI App `ttl-hotspot-changer`

`ttl-hotspot-changer` 是一個 LuCI 介面與系統腳本的組合，協助在 OpenWrt 裝置上調整 TTL/Hop-Limit。它支援智慧偵測、依賴套件安裝、日誌檢視與完整的啟動腳本控制，可在 LuCI 中直接編輯 `enable`、`mode`、`ttl_mode`、`custom_ttl`、`smart` 等 UCI 參數；實際套用規則由 `/usr/libexec/ttl-hotspot-changer.sh` 透過 nftables 處理。

## 功能特色
- LuCI 介面：`LuCI > 網路 > ttl-hotspot-changer` 可切換主要/子路由模式、TTL 模式與自訂值。
- 日誌與依賴：內建日誌檢視（讀取 `/tmp/ttl-hotspot-changer.log`）與依賴管理頁面（呼叫 `ttl-hotspot-changer-depctl.sh`）。
- 服務控制：`/etc/init.d/ttl-hotspot-changer` 提供 `enable/disable/start/stop/status/log/install_deps/remove_deps` 指令，可在 LuCI 或 CLI 使用。
- 預設設定檔：`/etc/config/ttl-hotspot-changer` 內含 `enable=1`、`mode=sub`、`ttl_mode=custom`、`custom_ttl=65`、`smart=1` 等可調參數。
- nftables 規則：所有規則集中在 `inet ttlfix` 表，方便檢查與排錯。

## 專案結構
```
luci-app-ttl-hotspot-changer/
├── Makefile
├── luasrc/
│   ├── controller/ttl-hotspot-changer.lua
│   ├── model/cbi/ttl-hotspot-changer.lua
│   └── view/ttl-hotspot-changer/{logs.htm,depctl.htm}
└── root/
    ├── etc/{config,init.d}/ttl-hotspot-changer
    └── usr/libexec/{ttl-hotspot-changer.sh,ttl-hotspot-changer-depctl.sh}
```

## 建置前準備
1. **下載對應的 OpenWrt SDK** － 從 [OpenWrt Downloads](https://downloads.openwrt.org/) 取得目標韌體版本（例如 `23.05.3`）與平台（如 MT7981、Rockchip 等）的 `openwrt-sdk-*.tar.xz`。
2. **安裝主機依賴（Debian/Ubuntu 範例）**
   ```sh
   sudo apt update
   sudo apt install build-essential gawk ccache git python3 unzip libncurses5-dev zlib1g-dev
   ```
3. **初始化 SDK**
   ```sh
   tar xf openwrt-sdk-*.tar.xz
   cd openwrt-sdk-*
   ./scripts/feeds update -a
   ./scripts/feeds install -a
   ```
4. **導入套件來源** － 將本專案複製到 `package/`（或 `package/custom/` 後以 `ln -s` 引用）。

## 編譯 ttl-hotspot-changer ipk
1. **配置目標與套件**
   ```sh
   make menuconfig
   # LuCI -> Applications -> luci-app-ttl-hotspot-changer (選 M 或 <*>)
   ```

### 把 舊kernel 的 build dir 整個砍掉 (例rockchip)
   ```sh
   rm -rf build_dir/target-aarch64_generic_musl/linux-rockchip_armv8
   rm -rf build_dir/target-aarch64_generic_musl/root-rockchip
   ```
### 把 舊kernel package 的 "已安裝" 標記也刪掉(例rockchip)
   ```sh
   rm -f staging_dir/target-aarch64_generic_musl/stamp/.package_kernel_installed
   ```
## 先準備 + 編 kernel
   ```sh
   make target/linux/{prepare,compile} V=s -j$(nproc)
   ```

2. **編譯單一套件**
   ```sh
   make package/luci-app-ttl-hotspot-changer/compile V=s
   ```
   成品會出現在 `bin/packages/<arch>/luci/luci-app-ttl-hotspot-changer_*.ipk`。
3. **快速重編譯**（清除舊中介檔後再編譯）
   ```sh
   make package/luci-app-ttl-hotspot-changer/{clean,compile} V=s
   ```

## 安裝與測試
1. **複製 ipk 到裝置**
   ```sh
   scp bin/packages/*/luci/luci-app-ttl-hotspot-changer_*.ipk root@192.168.1.1:/tmp/
   ```
2. **安裝與啟動服務**
   ```sh
   ssh root@192.168.1.1
   opkg install /tmp/luci-app-ttl-hotspot-changer_*.ipk
   /etc/init.d/ttl-hotspot-changer enable
   /etc/init.d/ttl-hotspot-changer start
   ```
3. **安裝依賴模組**（若目標韌體未預建）
   ```sh
   /etc/init.d/ttl-hotspot-changer install_deps
   ```
4. **檢視狀態與日誌**
   ```sh
   /etc/init.d/ttl-hotspot-changer status
   /etc/init.d/ttl-hotspot-changer log
   tail -f /tmp/ttl-hotspot-changer.log
   ```
   在 LuCI Logs 頁面也可以看到最新 200 行並自動刷新。

## 疑難排解與注意事項
- 變更主要/次要路由模式或 TTL 後，可直接在 LuCI 表單儲存，或以 `uci set ttl-hotspot-changer.config.<field>=...; uci commit` 透過 CLI 操作。
- 若不再需要 nftables 規則，可執行 `/etc/init.d/ttl-hotspot-changer remove_deps` 移除自動安裝的 kmod。
- 檢查規則時，使用 `nft list table inet ttlfix` 或 `/usr/libexec/ttl-hotspot-changer.sh status` 進行逐步排查。
- 針對不同 CPU 平台請使用對應的 SDK 或在完整 OpenWrt 原始碼中重新設定 `Target System/Subtarget` 後再編譯，以確保輸出的 ipk 與目標架構相容。
