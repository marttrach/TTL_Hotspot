# LuCI App ??ttl-hotspot-changer

`ttl-hotspot-changer` ?¯ä?å¥?LuCI ä»‹é¢?‡å?ç«¯è…³?¬ç??ˆï??¯åœ¨ OpenWrt ç³»çµ±ä¸­å??‹èª¿??TTL/Hop-Limitï¼Œæ”¯?´è‡ª?•æ?æ¨¸åµæ¸¬ã€ä?è³´å?ä»¶å?è£ã€æ—¥èªŒæª¢è¦–è??å??§åˆ¶?‚LuCI ä»‹é¢?ƒå? `enable`?`mode`?`ttl_mode`?`custom_ttl`?`smart` ç­?UCI ?ƒæ•¸å¯«å…¥ `/etc/config/ttl-hotspot-changer`ï¼Œå???`/usr/libexec/ttl-hotspot-changer.sh` ?é? nftables å¥—ç”¨è¦å???
## ?Ÿèƒ½?¹è‰²
- ?°å? `LuCI > ç¶²è·¯ > ttl-hotspot-changer` ?é¢ï¼Œå¯?‹é??å?ä¸¦å??›ä¸»ï¼å?è·¯ç”±æ¨¡å???TTL æ¨¡å???- ?§å»º?¥è??é¢ï¼ˆè???`/tmp/ttl-hotspot-changer.log`ï¼‰è?ä¾è³´å®‰è??©æ?ï¼ˆå‘¼??`/usr/libexec/ttl-hotspot-changer-depctl.sh`ï¼‰ã€?- `/etc/init.d/ttl-hotspot-changer` ?å??¯æ´ `enable/disable/start/stop/status/log/install_deps/remove_deps`ï¼Œå¯?é? LuCI ??CLI ?ä???- ?è¨­è¨­å?æª”å???`enable=1`?`mode=sub`?`ttl_mode=custom`?`custom_ttl=65`?`smart=1`ï¼Œå¯ä¾é?æ±‚åœ¨ LuCI ??`uci` ä¸­èª¿?´ã€?
## å°ˆæ?çµæ?
```
luci-app-ttl-hotspot-changer/
 ?œâ? Makefile
 ?œâ? luasrc/
 ?? ?œâ? controller/ttl-hotspot-changer.lua
 ?? ?œâ? model/cbi/ttl-hotspot-changer.lua
 ?? ?”â? view/ttl-hotspot-changer/{logs.htm,depctl.htm}
 ?”â? root/
    ?œâ? etc/{config,init.d}/ttl-hotspot-changer
    ?”â? usr/libexec/{ttl-hotspot-changer.sh,ttl-hotspot-changer-depctl.sh}
```

## å»ºç½®?°å?æº–å?
1. **ä¸‹è??ˆé©??OpenWrt SDK**  
   ?å? [OpenWrt Downloads](https://downloads.openwrt.org/) ?–å?å°æ??ˆæœ¬ï¼ˆä?å¦?`23.05.3`ï¼‰è??®æ?å¹³å°??`openwrt-sdk-*.tar.xz`?? 
   ä¾‹ï?MT7981 å¹³å°?¯ä½¿??`openwrt-sdk-23.05.3-mediatek-filogic_gcc-12.3.0_musl.Linux-x86_64.tar.xz`??2. **å®‰è?ä¸»æ?ç«¯ä?è³´ï?Debian/Ubuntu ç¯„ä?ï¼?*
   ```sh
   sudo apt update
   sudo apt install build-essential gawk ccache git python3 unzip libncurses5-dev zlib1g-dev
   ```
3. **è§??ä¸¦å?å§‹å? SDK**
   ```sh
   tar xf openwrt-sdk-*.tar.xz
   cd openwrt-sdk-*
   ./scripts/feeds update -a
   ./scripts/feeds install -a
   ```
4. **å°å…¥å¥—ä»¶?Ÿå?ç¢?*  
   å°‡æœ¬å°ˆæ??¾å…¥ SDKï¼Œä?å¦‚ï?
   ```sh
   cp -a /path/to/luci-app-ttl-hotspot-changer package/
   ```
   ?¥é?ä¸­ç®¡?†å¯?¾åœ¨ `package/custom/` ä¸¦é€é? `ln -s` å¼•ç”¨??
## ç·¨è­¯ ttl-hotspot-changer ipk
1. **?é? `make menuconfig` ?¸å?**
   ```sh
   make menuconfig
   # LuCI -> Applications -> luci-app-ttl-hotspot-changer (??M ??<*>)
   make package/luci-app-ttl-hotspot-changer/compile V=s
   ```
   ç·¨è­¯çµæ??ƒè¼¸??`bin/packages/<arch>/luci/luci-app-ttl-hotspot-changer_*.ipk`??2. **?´æ¥ç·¨è­¯å¥—ä»¶**
   ```sh
   make package/luci-app-ttl-hotspot-changer/{clean,compile} V=s
   ```
   ?©å???CI ?–å¿«?Ÿé?è­‰æ?å¢ƒä?ä½¿ç”¨??
## å®‰è??‡æ¸¬è©¦æ?ç¨?1. **å°?ipk ?³åˆ°è·¯ç”±??*
   ```sh
   scp bin/packages/*/luci/luci-app-ttl-hotspot-changer_*.ipk root@192.168.1.1:/tmp/
   ```
2. **å®‰è?ä¸¦å??•æ???*
   ```sh
   ssh root@192.168.1.1
   opkg install /tmp/luci-app-ttl-hotspot-changer_*.ipk
   /etc/init.d/ttl-hotspot-changer enable
   /etc/init.d/ttl-hotspot-changer start
   ```
   å®‰è?å¾Œå³?¯åœ¨ LuCI?Œç¶²è·¯ã€é¸?®ä¸­?¾åˆ°?é¢??3. **å®‰è?ä¾è³´æ¨¡ç?**  
   ?¥é?é«”æœª?§å»º `kmod-nft-*`?`nftables`?`jsonfilter` ç­‰å?ä»¶ï??¯åŸ·è¡Œï?
   ```sh
   /etc/init.d/ttl-hotspot-changer install_deps
   ```
   ?–åœ¨ LuCI ?„ã€Œä?è³´å?ä»¶ã€å?å¡Šé??Šæ??•ã€?4. **æª¢æŸ¥?€?‹è??¥è?**
   ```sh
   /etc/init.d/ttl-hotspot-changer status
   /etc/init.d/ttl-hotspot-changer log
   tail -f /tmp/ttl-hotspot-changer.log
   ```
   LuCI Logs ?é¢?ƒæ? 5 ç§’è‡ª?•åˆ·?°æ???200 è¡Œè¼¸?ºã€?
## ?¶ä?èªªæ?
- ?€è¦å??›ä¸»ï¼å?è·¯ç”±?–è‡ªè¨?TTL ?‚ï??¯ä¿®??LuCI è¡¨å–®?–åŸ·è¡?`uci set ttl-hotspot-changer.config.<field>=...; uci commit`ï¼Œprocd è§¸ç™¼å¾Œæ??æ–°å¥—ç”¨è¦å???- ?¥å??´æ–°?–ç§»?¤è€Œå??¨æ??™ï??¯åŸ·è¡?`/etc/init.d/ttl-hotspot-changer remove_deps` æ¸…é™¤å·²å?è£ç? kmod??- ?‡åˆ° nftables è¦å??°å¸¸?‚ï?è«‹ä½¿??`nft list table inet ttlfix` ??`/usr/libexec/ttl-hotspot-changer.sh status` ?²ä?æ­¥æª¢?¥ã€?
