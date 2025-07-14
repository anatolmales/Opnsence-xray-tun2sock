[size=5][b]1. tun2socks[/b][/size]
[code]mkdir -p /usr/local/tun2socks[/code]

[code]fetch -q -o /tmp/tun2socks.zip https://github.com/xjasonlyu/tun2socks/releases/download/v2.6.0/tun2socks-freebsd-amd64.zip
mkdir -p /usr/local/etc/tun2socks/
unzip -p /tmp/tun2socks.zip tun2socks-freebsd-amd64 > /usr/local/etc/tun2socks/tun2socks
chmod +x /usr/local/etc/tun2socks/tun2socks[/code]

[b]Создать новый файл конфигурации /usr/local/etc/tun2socks/config.yaml[/b]

[code]
# debug / info / warning / error / silent
loglevel: info
# URL format: [protocol://]host[:port]
proxy: socks5://192.168.3.10:7891
# URL format: [driver://]name
device: tun://tun2socks0
# Maximum transmission unit for each packet
mtu: 1500
# Timeout for each UDP session, default value: 60 seconds
udp-timeout: 120s[/code]

[b]Создайте файл /usr/local/etc/rc.d/tun2socks[/b]

[code]
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
tun2socks_start()
{
    if [ ! -f ${tun2socks_config} ]; then
        echo "${tun2socks_config} not found."
        exit 1
    fi
    echo "Starting ${name}."
    /bin/sh -c "${command} ${command_args}"
}
run_rc_command "$1"[/code]

[b]Разрешение на запуск[/b]
[code]
chmod +x /usr/local/etc/rc.d/tun2socks[/code]

[b]Добавить в автозагрузку:[/b]
[code]echo "tun2socks_enable="YES"" > /etc/rc.conf.d/tun2socks[/code]

Новый файл для добавление в GIU System: Diagnostics: Services
/usr/local/opnsense/service/conf/actions.d/actions_tun2socks.conf

[code]
[start]
command:/usr/local/etc/rc.d/tun2socks start
parameters:
type:script
message:starting tun2socks
[stop]
command:/usr/local/etc/rc.d/tun2socks stop
parameters:
type:script
message:stopping tun2socks
[restart]
command:/usr/local/etc/rc.d/tun2socks restart
parameters:
type:script
message:restarting tun2socks
[status]
command:/usr/local/etc/rc.d/tun2socks status; exit 0
parameters:
type:script_output
message:request tun2socks status[/code]

[b]Новый плагин[/b]
[url="https://docs.opnsense.org/development/backend/legacy.html"]Использование плагинов. Документация OPNsense[/url]
файл /usr/local/etc/inc/plugins.inc.d/tuntosocks.inc
Тут отображается криво. Прикрепил файл
В начале файла первой стройкой добавить "<?php"
[code]
/*
 * Copyright (C) 2017 EURO-LOG AG
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
/**
 * register service
 * @return array
 */
function tuntosocks_services()
{
    global $config;
    $services = array();
    $services[] = array(
        'description' => gettext('tun2socks gVisor TCP/IP stack'),
        'configd' => array(
            'restart' => array('tun2socks restart'),
            'start' => array('tun2socks start'),
            'stop' => array('tun2socks stop'),
        ),
        'name' => 'tun-socks',
        'pidfile' => '/var/run/tun2socks.pid'
    );
    return $services;
}
function tuntosocks_syslog()
{
    $logfacilities = array();
    $logfacilities['tun2socks'] = array(
        'facility' => array('tun2socks'),
    );
    return $logfacilities;
}[/code]

Для перезагрузки плагинов запустить
pluginctl -s

Служба появится в списке вывода и отобразится в Web GIU System: Diagnostics: Services

[b]Запуск службы при загрузке[/b]
Файл /usr/local/etc/rc.syshook.d/early/40-tun2socks
[code]
#!/bin/sh
# Start tun2socks service
/usr/local/etc/rc.d/tun2socks restart[/code]

[b]Переходим в GUI[/b]

[b]Настройка интерфейса[/b]
Добавить новый интерфейс в Interfaces: Assignments
                    
              
[table][tr][td]Enable[/td]
[td]Включить[/td]
[/tr]
[tr][td]Description[/td]
[td]tun2socks[/td]
[/tr]
[tr][td]IPv4 Configuration Type[/td]
[td]Static IPv4[/td]
[/tr]
[tr][td]IPv4 address[/td]
[td]10.0.0.1/24[/td]
[/tr]
[/table]

Применить.

Добавить шлюз в System: Gateways: Configuration
              
                
[table][tr][td]Disabled[/td]
[td]no[/td]
[/tr]
[tr][td]Name[/td]
[td]GW-tun2socks[/td]
[/tr]
[tr][td]Interface[/td]
[td]tun2socks[/td]
[/tr]
[tr][td]Address Family[/td]
[td]IPv4[/td]
[/tr]
[tr][td]IP Address[/td]
[td]10.0.0.2[/td]
[/tr]
[tr][td]Far Gateway[/td]
[td]yes[/td]
[/tr]
[tr][td]Disable Gateway Monitoring[/td]
[td]yes[/td]
[/tr]
[tr][td]Priority[/td]
[td]250[/td]
[/tr]
[/table]

Применить.
[hr]
[size=5][b]2. Настройка x2ray[/b][/size]

Установить x2ray-core

[code]pkg install xray-core[/code]

[b]Создайте файл /usr/local/etc/rc.d/xray[/b]
[code]#!/bin/sh
# PROVIDE: xray-core
# REQUIRE: LOGIN
# KEYWORD: shutdown
# Add these lines to /etc/rc.conf.local or /etc/rc.conf to enable `xray':
#
# xray_enable (bool):           Set to "NO" by default.
#                               Set it to "YES" to enable xray
# xray_config (path):           Set to "/usr/local/etc/xray-core" by default
#                               Set it to the xray server config
# xray_logdir (path):           Set to "/var/log/xray-core" by default.
#                               Set it to the directory of xray log files
# xray_env (str):               Set to "" by default.
#                               Set it to the desired environment variables
. /etc/rc.subr
name="xray"
rcvar="xray_enable"
: ${xray_enable="NO"}
: ${xray_config="/usr/local/etc/${name}-core"}
: ${xray_logdir="/var/log/${name}-core"}
: ${xray_env=""}
: ${xray_user="v2ray"}
: ${xray_group="v2ray"}
asset_env="XRAY_LOCATION_ASSET=/usr/local/share/${name}-core"
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
run_rc_command "$1"[/code]

[code]chmod +x /usr/local/etc/rc.d/xray[/code]

[b]Добавить в автозагрузку:[/b]
[code]echo "xray_enable="YES"" > /etc/rc.conf.d/xray[/code]

Файл /usr/local/etc/rc.syshook.d/early/41-xray
[code]
]
#!/bin/sh

# Start xray service
/usr/local/etc/rc.d/xray  restart
[/code]

Новый файл для добавление в GIU System: Diagnostics: Services и обновление по cron'у
/usr/local/opnsense/service/conf/actions.d/actions_xray.conf

[code]
[start]
command:/usr/local/etc/rc.d/xray start
parameters:
type:script
message:starting xray
[stop]
command:/usr/local/etc/rc.d/xray stop
parameters:
type:script
message:stopping xray
[restart]
command:/usr/local/etc/rc.d/xray restart
parameters:
type:script
message:restarting xray
[update]
command:/usr/local/etc/xray-core/update-xray.sh; exit 0
parameters:
type:script
description: Update xray GeoIP and GeoSite
message:request xray update database[/code]

Создать файл /usr/local/etc/xray-core/update-xray.sh для обновление GeoIP и GeoSite

[code]
#!/bin/sh
wget https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geoip.dat -O /usr/local/share/xray-core/geoip.dat
wget https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geosite.dat -O /usr/local/share/xray-core/geosite.dat
/usr/local/etc/rc.d/xray restart[/code]


Создать файл /usr/local/etc/inc/plugins.inc.d/xray.inc
В начале файла первой стройкой добавить "<?php"
[code]
/*
 * Copyright (C) 2017 EURO-LOG AG
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
/**
 * register service
 * @return array
 */
function xray_services()
{
    global $config;
    $services = array();
    $services[] = array(
        'description' => gettext('xray service'),
        'configd' => array(
            'restart' => array('xray restart'),
            'start' => array('xray start'),
            'stop' => array('xray stop'),
        ),
        'name' => 'xray',
        'pidfile' => '/var/run/xray.pid'
    );
    return $services;
}
function xray_syslog()
{
    $logfacilities = array();
    $logfacilities['xray'] = array(
        'facility' => array('xray'),
    );
    return $logfacilities;
}[/code]

Для перезагрузки плагинов запустить
pluginctl -s
Проверить в списке xray
Перегрузить GUI service configd restart

Настроить /usr/local/etc/xray-core/config.json для xray со своими параметрами.
запустить /usr/local/etc/xray-core/update-xray.sh  для обновления баз
[hr]
Идем в WebGUI [b]System: Settings: Cron[/b]
Добавляем новое задание по обновлению баз каждые 8 часов:
              
[table][tr][td]Enabled[/td]
[td]yes[/td]
[/tr]
[tr][td]Minutes[/td]
[td]0[/td]
[/tr]
[tr][td]Hours[/td]
[td]*/8[/td]
[/tr]
[tr][td]Day of the month[/td]
[td]*[/td]
[/tr]
[tr][td]Months[/td]
[td]*[/td]
[/tr]
[tr][td]Days of the week[/td]
[td]*[/td]
[/tr]
[tr][td]Command[/td]
[td]Update GeoIP and GeoSite[/td]
[/tr]
[tr][td]Parameters[/td]
[td][/td]
[/tr]
[tr][td]Description[/td]
[td]Update GeoIP & GeoSite for xray[/td]
[/tr]
[/table]
Сохранить - Применить

[list]
[li][b]Firewall: NAT: Outbound[/b][/li]
[li]Установить Гибридный режим: [b]Hybrid outbound NAT rule generation[/b] [/li]
[/list]


Добавить(если нет) новый интерфейс tun2socks
Interface - tun2socks 
TCP/IP - Version IPv4
any to any
остальное по умолчанию

[list]
[li][b]Firewall: Rules: LAN[/b][/li]
[/list]

Action            Pass
Disabled        no
Quick                yes
Interface          LAN
Direction          in
TCP/IP Version    IPv4
Protocol        TCP/UDP
Source/Invert      no
Source            any
Destination/Invert yes
Destination        RFC1918
Description        Trafic to xray

Gateway        10.0.0.2(Шлюз tun2socks)

Сохранить-Применить
