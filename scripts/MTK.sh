# 添加其他仓库的插件
git clone --depth 1 -b main https://github.com/CC13594759/packages.git package/app
rm -rf package/app/luci-theme-argon
# 修改默认IP
sed -i 's/192.168.6.1/192.168.13.1/g' package/base-files/files/bin/config_generate
# 修改默认主题
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' $(find ./feeds/luci/collections/ -type f -name "Makefile")
# 修改luci首页显示
sed -i 's/ImmortalWrt/OpenWrt/gi' package/base-files/files/bin/config_generate
sed -i '/downloads\.immortalwrt\.org/!s/ImmortalWrt/OpenWrt/gi' include/version.mk
cp -f $GITHUB_WORKSPACE/scripts/index.js feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/index.js
sed -i -e '/"admin\/system\/plugins": {/,/"admin\/system\/startup": {/ { /"admin\/system\/startup": {/!d; }' feeds/luci/modules/luci-mod-system/root/usr/share/luci/menu.d/luci-mod-system.json
sed -i '/Target Platform/d' feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js
MJS=feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/20_memory.js; for p in "_('Buffered')" "_('Cached')" "_('Swap free')" "if (mem.buffered)" "if (mem.cached)" "if (swap.total > 0)"; do grep -qF "$p" "$MJS" || { echo "20_memory.js: pattern not found: $p"; exit 1; }; done; sed -i "/_('Buffered')/d; /_('Cached')/d; /_('Swap free')/d; /if (mem.buffered)/d; /if (mem.cached)/d; /if (swap.total > 0)/d" "$MJS"
rm -rf feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/{25_storage.js,50_dsl.js,60_wifi.js}
rm -rf feeds/luci/applications/luci-app-ddns/htdocs/luci-static/resources/view/status/include/70_ddns.js
# 删除ttyd
sed -i 's/luci-app-ttyd//g' target/linux/mediatek/Makefile
# 修改插件位置
sed -i 's/vpn/services/g' feeds/luci/applications/luci-app-zerotier/root/usr/share/luci/menu.d/luci-app-zerotier.json
# 计划任务
mkdir -p package/base-files/files/etc/crontabs && printf '%s\n' '# 定时重启（每周六凌晨3点33）' '#33 3 * * 6 sleep 66 && touch /etc/banner && reboot' > package/base-files/files/etc/crontabs/root
# 修改WIFI名称
sed -i 's/ImmortalWrt/OpenWrt/g' package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
# 修改WIFI加密
sed -i "s/encryption=.*/encryption='psk2+ccmp'/g" package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
# 修改WIFI密码
sed -i "/psk2+ccmp/a \\\t\t\t\t\t\set wireless.default_\${dev}.key='password'" package/mtk/applications/mtwifi-cfg/files/mtwifi.sh
# 修改最大连接数为65535
sed -i "s/conntrack_max=.*/conntrack_max=65535/g" package/kernel/linux/files/sysctl-nf-conntrack.conf

# ============================================================
# TAP200 DIY 注入（追加）
# ============================================================
set -e

OPENWRT_PATH="${OPENWRT_PATH:-$(pwd)}"
DTS_DIR="$OPENWRT_PATH/target/linux/mediatek/dts"
MK_FILE="$OPENWRT_PATH/target/linux/mediatek/image/filogic.mk"

echo "=== 注入 TAP200 设备树 ==="

cp -f "$GITHUB_WORKSPACE/mt7981b-h3c-tap200.dts" "$DTS_DIR/" 2>/dev/null || \
  echo "  警告：未找到 mt7981b-h3c-tap200.dts"
cp -f "$GITHUB_WORKSPACE/mt7981b-h3c-tap200-nmbm.dts" "$DTS_DIR/" 2>/dev/null || \
  echo "  警告：未找到 mt7981b-h3c-tap200-nmbm.dts"

ls -la "$DTS_DIR/" | grep tap200

echo "=== 追加设备定义到 filogic.mk ==="
if ! grep -q "h3c_tap200" "$MK_FILE"; then
  cat >> "$MK_FILE" << 'EOF'

define Device/h3c_tap200
  DEVICE_VENDOR := H3C
  DEVICE_MODEL := TAP200
  DEVICE_DTS := mt7981b-h3c-tap200-nmbm
  DEVICE_DTS_DIR := ../dts
  DEVICE_PACKAGES := kmod-mt7915e kmod-mt7981-firmware mt7981-wo-firmware
  UBINIZE_OPTS := -E 5
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  IMAGE_SIZE := 65536k
  KERNEL_IN_UBI := 1
  IMAGES += factory.bin
  IMAGE/factory.bin := append-ubi | check-size $$$$(IMAGE_SIZE)
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
  KERNEL = kernel-bin | lzma | \
	fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb
  KERNEL_INITRAMFS = kernel-bin | lzma | \
	fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb with-initrd
endef
TARGET_DEVICES += h3c_tap200
EOF
  echo "  已追加 h3c_tap200 设备定义"
else
  echo "  设备定义已存在，跳过"
fi

echo "=== 设置默认 IP ==="
sed -i 's/192\.168\.13\.1/192.168.1.1/g' "$OPENWRT_PATH/package/base-files/files/bin/config_generate" 2>/dev/null || true

echo "=== DIY 脚本完成 ==="
