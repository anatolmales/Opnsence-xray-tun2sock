#!/bin/sh

# Устанавливаем переменные
TUN2SOCKS_DIR="/usr/local/etc/tun2socks"
XRAY_DIR="/usr/local/etc/xray-core"
RC_CONF_TUN="/etc/rc.conf.d/tun2socks"
RC_CONF_XRAY="/etc/rc.conf.d/xray"
SYS_HOOK_DIR="/usr/local/etc/rc.syshook.d/early"

echo "[*] Установка зависимостей и подготовка каталогов"
pkg install -y unzip wget xray-core || exit 1
mkdir -p $TUN2SOCKS_DIR $XRAY_DIR $SYS_HOOK_DIR /usr/local/opnsense/service/conf/actions.d /usr/local/etc/inc/plugins.inc.d

echo "[*] Загрузка файлов tun2socks"
fetch -o $TUN2SOCKS_DIR/config.yaml https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/tun2sock/config.yaml
fetch -o $TUN2SOCKS_DIR/tun2socks https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/tun2sock/tun2socks
fetch -o /usr/local/etc/inc/plugins.inc.d/tun2socks.inc https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/tun2sock/tun2socks.inc

chmod +x $TUN2SOCKS_DIR/tun2socks

echo "[*] Создание rc.d службы tun2socks"
cat > /usr/local/etc/rc.d/tun2socks << 'EOF'
#!/bin/sh
# PROVIDE: tun2socks
# REQUIRE: LOGIN
# KEYWORD: shutdown

. /etc/rc.subr
name="tun2socks"
rcvar="tun2socks_enable"
load_rc_config $name

: ${tun2socks_enable:=no}
: ${tun2socks_config:="/usr/local/etc/tun2socks/config.yaml"}

pidfile="/var/run/${name}.pid"
command="/usr/local/etc/tun2socks/tun2socks"
command_args="-config ${tun2socks_config} > /dev/null 2>&1 & echo \$! > ${pidfile}"
start_cmd="${name}_start"

tun2socks_start() {
    if [ ! -f ${tun2socks_config} ]; then
        echo "${tun2socks_config} not found."
        exit 1
    fi
    echo "Starting ${name}."
    /bin/sh -c "${command} ${command_args}"
}
run_rc_command "$1"
EOF

chmod +x /usr/local/etc/rc.d/tun2socks
echo 'tun2socks_enable="YES"' > $RC_CONF_TUN

cat > $SYS_HOOK_DIR/40-tun2socks << EOF
#!/bin/sh
/usr/local/etc/rc.d/tun2socks restart
EOF
chmod +x $SYS_HOOK_DIR/40-tun2socks

echo "[*] Настройка Web GUI tun2socks"
cat > /usr/local/opnsense/service/conf/actions.d/actions_tun2socks.conf << EOF
[start]
command:/usr/local/etc/rc.d/tun2socks start
parameters: type:script
message:starting tun2socks

[stop]
command:/usr/local/etc/rc.d/tun2socks stop
parameters: type:script
message:stopping tun2socks

[restart]
command:/usr/local/etc/rc.d/tun2socks restart
parameters: type:script
message:restarting tun2socks

[status]
command:/usr/local/etc/rc.d/tun2socks status; exit 0
parameters: type:script_output
message:request tun2socks status
EOF

echo "[*] Загрузка файлов xray"
fetch -o $XRAY_DIR/update-xray.sh https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/xray-core/update-xray.sh
fetch -o /usr/local/bin/xray https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/xray/xray
fetch -o /usr/local/etc/inc/plugins.inc.d/xray.inc https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/xray/xray.inc

chmod +x /usr/local/bin/xray $XRAY_DIR/update-xray.sh

echo "[*] Создание rc.d службы xray"
cat > /usr/local/etc/rc.d/xray << 'EOF'
#!/bin/sh
# PROVIDE: xray-core
# REQUIRE: LOGIN
# KEYWORD: shutdown

. /etc/rc.subr

name="xray"
rcvar="xray_enable"
: ${xray_enable="NO"}
: ${xray_config="/usr/local/etc/xray-core"}
: ${xray_logdir="/var/log/xray-core"}
: ${xray_env=""}
: ${xray_user="v2ray"}
: ${xray_group="v2ray"}

asset_env="XRAY_LOCATION_ASSET=/usr/local/share/xray-core"
pidfile="/var/run/$name.pid"
procname="/usr/local/bin/xray"
command="/usr/sbin/daemon"
command_args="-c -p ${pidfile} /usr/bin/env ${asset_env} ${xray_env} ${procname} -confdir ${xray_config}"
required_files="${xray_config}"

start_precmd="xray_startprecmd"
xray_startprecmd() {
    touch "${pidfile}"
    chown ${xray_user}:${xray_group} "${pidfile}"
    mkdir -p "${xray_logdir}"
    chown -R ${xray_user}:${xray_group} "${xray_logdir}"
}
load_rc_config "$name"
run_rc_command "$1"
EOF

chmod +x /usr/local/etc/rc.d/xray
echo 'xray_enable="YES"' > $RC_CONF_XRAY

cat > $SYS_HOOK_DIR/41-xray << EOF
#!/bin/sh
/usr/local/etc/rc.d/xray restart
EOF
chmod +x $SYS_HOOK_DIR/41-xray

echo "[*] Настройка Web GUI xray"
cat > /usr/local/opnsense/service/conf/actions.d/actions_xray.conf << EOF
[start]
command:/usr/local/etc/rc.d/xray start
parameters: type:script
message:starting xray

[stop]
command:/usr/local/etc/rc.d/xray stop
parameters: type:script
message:stopping xray

[restart]
command:/usr/local/etc/rc.d/xray restart
parameters: type:script
message:restarting xray

[update]
command:/usr/local/etc/xray-core/update-xray.sh; exit 0
parameters: type:script
description: Update xray GeoIP and GeoSite
message:request xray update database
EOF

echo "[*] Применение конфигурации"
pluginctl -s
service configd restart
