# LuCI App – ttl-hotspor-changer

`ttl-hotspor-changer` 是一套 LuCI 介面與後端腳本組合，可在 OpenWrt 系統中動態調整 TTL/Hop-Limit，支援自動拓樸偵測、依賴套件安裝、日誌檢視與服務控制。LuCI 介面會將 `enable`、`mode`、`ttl_mode`、`custom_ttl`、`smart` 等 UCI 參數寫入 `/etc/config/ttl-hotspor-changer`，再由 `/usr/libexec/ttl-hotspor-changer.sh` 透過 nftables 套用規則。

## 功能特色
- 新增 `LuCI > 網路 > ttl-hotspor-changer` 頁面，可開關服務並切換主／子路由模式與 TTL 模式。
- 內建日誌頁面（讀取 `/tmp/ttl-hotspor-changer.log`）與依賴安裝助手（呼叫 `/usr/libexec/ttl-hotspor-changer-depctl.sh`）。
- `/etc/init.d/ttl-hotspor-changer` 服務支援 `enable/disable/start/stop/status/log/install_deps/remove_deps`，可透過 LuCI 或 CLI 操作。
- 預設設定檔包含 `enable=1`、`mode=sub`、`ttl_mode=custom`、`custom_ttl=65`、`smart=1`，可依需求在 LuCI 或 `uci` 中調整。

## 專案結構
```
luci-app-ttl-hotspor-changer/
 ├─ Makefile
 ├─ luasrc/
 │  ├─ controller/ttl-hotspor-changer.lua
 │  ├─ model/cbi/ttl-hotspor-changer.lua
 │  └─ view/ttl-hotspor-changer/{logs.htm,depctl.htm}
 └─ root/
    ├─ etc/{config,init.d}/ttl-hotspor-changer
    └─ usr/libexec/{ttl-hotspor-changer.sh,ttl-hotspor-changer-depctl.sh}
```

## 建置環境準備
1. **下載合適的 OpenWrt SDK**  
   前往 [OpenWrt Downloads](https://downloads.openwrt.org/) 取得對應版本（例如 `23.05.3`）與目標平台的 `openwrt-sdk-*.tar.xz`。  
   例：MT7981 平台可使用 `openwrt-sdk-23.05.3-mediatek-filogic_gcc-12.3.0_musl.Linux-x86_64.tar.xz`。
2. **安裝主機端依賴（Debian/Ubuntu 範例）**
   ```sh
   sudo apt update
   sudo apt install build-essential gawk ccache git python3 unzip libncurses5-dev zlib1g-dev
   ```
3. **解壓並初始化 SDK**
   ```sh
   tar xf openwrt-sdk-*.tar.xz
   cd openwrt-sdk-*
   ./scripts/feeds update -a
   ./scripts/feeds install -a
   ```
4. **導入套件原始碼**  
   將本專案放入 SDK，例如：
   ```sh
   cp -a /path/to/luci-app-ttl-hotspor-changer package/
   ```
   若集中管理可放在 `package/custom/` 並透過 `ln -s` 引用。

## 編譯 ttl-hotspor-changer ipk
1. **透過 `make menuconfig` 選取**
   ```sh
   make menuconfig
   # LuCI -> Applications -> luci-app-ttl-hotspor-changer (選 M 或 <*>)
   make package/luci-app-ttl-hotspor-changer/compile V=s
   ```
   編譯結果會輸出 `bin/packages/<arch>/luci/luci-app-ttl-hotspor-changer_*.ipk`。
2. **直接編譯套件**
   ```sh
   make package/luci-app-ttl-hotspor-changer/{clean,compile} V=s
   ```
   適合在 CI 或快速驗證情境下使用。

## 安裝與測試流程
1. **將 ipk 傳到路由器**
   ```sh
   scp bin/packages/*/luci/luci-app-ttl-hotspor-changer_*.ipk root@192.168.1.1:/tmp/
   ```
2. **安裝並啟動服務**
   ```sh
   ssh root@192.168.1.1
   opkg install /tmp/luci-app-ttl-hotspor-changer_*.ipk
   /etc/init.d/ttl-hotspor-changer enable
   /etc/init.d/ttl-hotspor-changer start
   ```
   安裝後即可在 LuCI「網路」選單中找到頁面。
3. **安裝依賴模組**  
   若韌體未內建 `kmod-nft-*`、`nftables`、`jsonfilter` 等套件，可執行：
   ```sh
   /etc/init.d/ttl-hotspor-changer install_deps
   ```
   或在 LuCI 的「依賴套件」區塊點擊按鈕。
4. **檢查狀態與日誌**
   ```sh
   /etc/init.d/ttl-hotspor-changer status
   /etc/init.d/ttl-hotspor-changer log
   tail -f /tmp/ttl-hotspor-changer.log
   ```
   LuCI Logs 頁面會每 5 秒自動刷新最新 200 行輸出。

## 其他說明
- 需要切換主／子路由或自訂 TTL 時，可修改 LuCI 表單或執行 `uci set ttl-hotspor-changer.config.<field>=...; uci commit`，procd 觸發後會重新套用規則。
- 若因更新或移除而停用服務，可執行 `/etc/init.d/ttl-hotspor-changer remove_deps` 清除已安裝的 kmod。
- 遇到 nftables 規則異常時，請使用 `nft list table inet ttlfix` 或 `/usr/libexec/ttl-hotspor-changer.sh status` 進一步檢查。
