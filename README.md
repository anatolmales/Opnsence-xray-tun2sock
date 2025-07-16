### Автоустановка. Остаётся настроить через ВебМорду cron, шлюз и нат
```sh
fetch -o - https://github.com/anatolmales/Opnsence-xray-tun2sock/raw/refs/heads/main/install.sh | sh
```

---

# 🧪 Ручная Настройка tun2socks и xray на OPNsense

## 1. Установка и настройка tun2socks

### 📂 Установка

```sh
mkdir -p /usr/local/tun2socks
fetch -q -o /tmp/tun2socks.zip https://github.com/xjasonlyu/tun2socks/releases/download/v2.6.0/tun2socks-freebsd-amd64.zip
mkdir -p /usr/local/etc/tun2socks/
unzip -p /tmp/tun2socks.zip tun2socks-freebsd-amd64 > /usr/local/etc/tun2socks/tun2socks
chmod +x /usr/local/etc/tun2socks/tun2socks
```

### ⚙️ Конфигурация

Создайте файл `/usr/local/etc/tun2socks/config.yaml`:

```yaml
loglevel: info
proxy: socks5://192.168.1.1:2080
device: tun://tun2socks0
mtu: 1500
udp-timeout: 120s
```

### 🧩 Служба tun2socks

Файл: `/usr/local/etc/rc.d/tun2socks`

```sh
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
```

###Разрешение на запуск:

```sh
chmod +x /usr/local/etc/rc.d/tun2socks
```
###Автозапуск:
```sh
echo 'tun2socks_enable="YES"' > /etc/rc.conf.d/tun2socks
```

Создайте файл запуска при старте: '/usr/local/etc/rc.syshook.d/start/91-tun2socks '
```sh
#!/bin/sh

# Start tun2socks service
/usr/local/etc/rc.d/tun2socks restart

```

### 🔧 Интеграция в Web GUI

Файл `/usr/local/opnsense/service/conf/actions.d/actions_tun2socks.conf`:

```ini
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
```

Создайте плагин `/usr/local/etc/inc/plugins.inc.d/tuntosocks.inc`:

```php
<?php
function tuntosocks_services() {
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

function tuntosocks_syslog() {
    return ['tun2socks' => ['facility' => ['tun2socks']]];
}
```

Перезагрузите службы:

```sh
pluginctl -s
```

### 🌐 Настройка интерфейса и шлюза

* **Interfaces → Assignments**

  * Description: `tun2socks`
  * IPv4 Configuration: `Static`
  * IPv4 Address: `10.0.0.1/24`

* **System → Gateways → Configuration**

  * Name: `GW-tun2socks`
  * Interface: `tun2socks`
  * IP Address: `10.0.0.2`
  * Far Gateway: `yes`
  * Disable Monitoring: `yes`
  * Priority: `250`

## 2. Установка и настройка xray

### 📥 Установка

```sh
pkg install xray-core
```

### ⚙️ Служба xray

Файл: `/usr/local/etc/rc.d/xray`

```sh
#!/bin/sh
# PROVIDE: xray-core
# REQUIRE: LOGIN
# KEYWORD: shutdown

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
run_rc_command "$1"
```

### Разрешение на запуск:

```sh
chmod +x /usr/local/etc/rc.d/xray
```
### Автозапуск
```sh
echo 'xray_enable="YES" ' > /etc/rc.conf.d/xray
```

Файл автозапуска `/usr/local/etc/rc.syshook.d/start/91-xray`:

```sh
#!/bin/sh

# Start x2ray service
/usr/local/etc/rc.d/x2ray restart

```

### 🔧 GUI-интеграция

Файл `/usr/local/opnsense/service/conf/actions.d/actions_xray.conf`:

```ini
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
```

Скрипт обновления баз GeoIP и GeoSite: `/usr/local/etc/xray-core/update-xray.sh`

```sh
#!/bin/sh
wget https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geoip.dat -O /usr/local/share/xray-core/geoip.dat
wget https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release/geosite.dat -O /usr/local/share/xray-core/geosite.dat
/usr/local/etc/rc.d/xray restart
```

Плагин `/usr/local/etc/inc/plugins.inc.d/xray.inc`:

```php
<?php
function xray_services() {
    global $config;
    return [
        [
            'description' => gettext('xray service'),
            'configd' => [
                'restart' => ['xray restart'],
                'start' => ['xray start'],
                'stop' => ['xray stop'],
            ],
            'name' => 'xray',
            'pidfile' => '/var/run/xray.pid'
        ]
    ];
}

function xray_syslog() {
    return ['xray' => ['facility' => ['xray']]];
}
```

Применить:

```sh
pluginctl -s
service configd restart
```

Настройте свой конфигурационный файл: `/usr/local/etc/xray-core/config.json`.

Обновление баз вручную:

```sh
/usr/local/etc/xray-core/update-xray.sh
```

### 🕒 Автообновление Geo-баз

Добавьте в GUI → System → Settings → Cron:

| Параметр    | Значение                        |
| ----------- | ------------------------------- |
| Enabled     | yes                             |
| Minutes     | 0                               |
| Hours       | \*/8                            |
| Command     | Update GeoIP and GeoSite        |
| Description | Update GeoIP & GeoSite for xray |

## 3. Правила и маршруты

* **Firewall → NAT → Outbound**: режим "Hybrid outbound NAT rule generation"
* Добавьте правило для `tun2socks` интерфейса
* **Firewall → Rules → LAN**: добавить правило для перенаправления трафика на шлюз `10.0.0.2`
