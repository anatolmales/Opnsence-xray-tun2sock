#!/bin/sh

# Убедимся, что скрипт выполняется от root
[ "$(id -u)" -ne 0 ] && echo "Must be run as root!" && exit 1

echo "[*] Installing dependencies..."
pkg install -y xray-core unzip wget || exit 1

echo "[*] Creating directories..."
mkdir -p /usr/local/etc/tun2socks /usr/local/tun2socks /usr/local/etc/xray-core \
         /usr/local/opnsense/service/conf/actions.d \
         /usr/local/etc/inc/plugins.inc.d \
         /usr/local/etc/rc.syshook.d/early

echo "[*] Downloading tun2socks files..."
fetch -o /usr/local/etc/tun2socks/tun2socks https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/tun2sock/tun2socks
chmod +x /usr/local/etc/tun2socks/tun2socks

fetch -o /usr/local/etc/tun2socks/config.yaml https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/tun2sock/config.yaml
fetch -o /usr/local/etc/rc.d/tun2socks https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/tun2sock/tun2socks.inc
chmod +x /usr/local/etc/rc.d/tun2socks

echo 'tun2socks_enable="YES"' > /etc/rc.conf.d/tun2socks

cat <<EOF > /usr/local/etc/rc.syshook.d/early/40-tun2socks
#!/bin/sh
/usr/local/etc/rc.d/tun2socks restart
EOF
chmod +x /usr/local/etc/rc.syshook.d/early/40-tun2socks

echo "[*] Integrating tun2socks into GUI..."
fetch -o /usr/local/opnsense/service/conf/actions.d/actions_tun2socks.conf https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/tun2sock/actions_tun2socks.conf
fetch -o /usr/local/etc/inc/plugins.inc.d/tuntosocks.inc https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/tun2sock/tun2socks.inc

echo "[*] Installing xray..."
# Установка уже выполнена выше через pkg

echo "[*] Installing xray service..."
fetch -o /usr/local/etc/rc.d/xray https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/xray/xray.inc
chmod +x /usr/local/etc/rc.d/xray

echo 'xray_enable="YES"' > /etc/rc.conf.d/xray

cat <<EOF > /usr/local/etc/rc.syshook.d/early/41-xray
#!/bin/sh
/usr/local/etc/rc.d/xray restart
EOF
chmod +x /usr/local/etc/rc.syshook.d/early/41-xray

echo "[*] Integrating xray into GUI..."
fetch -o /usr/local/opnsense/service/conf/actions.d/actions_xray.conf https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/xray/actions_xray.conf
fetch -o /usr/local/etc/inc/plugins.inc.d/xray.inc https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/xray/xray.inc
fetch -o /usr/local/etc/xray-core/update-xray.sh https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/xray/update-xray.sh
chmod +x /usr/local/etc/xray-core/update-xray.sh

echo "[*] Applying configuration..."
pluginctl -s
service configd restart

echo "[✓] Installation completed!"
