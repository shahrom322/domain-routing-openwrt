# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Обзор проекта

Ansible-роль и набор shell-скриптов для настройки маршрутизации по доменам и VPN-туннелей на роутерах OpenWrt. Опубликована в Ansible Galaxy как `itdoginfo.domain_routing_openwrt`.

**Целевая платформа:** OpenWrt 21.02, 22.03, 23.05, 24.10

## Основные команды

### Ansible-роль

```bash
# Установка роли из Ansible Galaxy
ansible-galaxy role install itdoginfo.domain_routing_openwrt

# Установка зависимости роли
ansible-galaxy role install gekmihesg.openwrt

# Запуск playbook (роутер должен быть в группе [openwrt] в inventory)
ansible-playbook -i inventory playbook.yml

# Тестовый playbook (использует tests/inventory с целью 192.168.56.23)
ansible-playbook -i tests/inventory tests/test.yml
```

### Автономные скрипты (запускаются напрямую на роутере OpenWrt)

```bash
# Установка
sh <(wget -O - https://raw.githubusercontent.com/shahrom322/domain-routing-openwrt/master/getdomains-install.sh)

# Удаление
sh <(wget -O - https://raw.githubusercontent.com/shahrom322/domain-routing-openwrt/master/getdomains-uninstall.sh)

# Проверка конфигурации (поддерживает --lang en для английского)
wget -O - https://raw.githubusercontent.com/shahrom322/domain-routing-openwrt/master/getdomains-check.sh | sh

# Управление пользовательскими доменами (добавление/удаление/исключение)
wget -O - https://raw.githubusercontent.com/shahrom322/domain-routing-openwrt/master/getdomains-manage.sh | sh
```

### Пользовательские домены

Хранятся в `/etc/getdomains/`:
- `user-domains.conf` - домены, добавленные в туннель
- `exclude-domains.conf` - домены, исключённые из туннелирования

## Архитектура

### Структура Ansible-роли

- `defaults/main.yml` - Переменные по умолчанию (тип туннеля, шифрование DNS, списки стран)
- `tasks/main.yml` - Основной файл задач (~700 строк) с обширной логикой для разных версий OpenWrt
- `handlers/main.yml` - Обработчики перезапуска сервисов (network, dnsmasq, getdomains, sing-box)
- `templates/` - Jinja2-шаблоны для init-скриптов и конфигов:
  - `openwrt-getdomains.j2` - Init-скрипт для загрузки списков доменов
  - `openwrt-30-vpnroute.j2` - Hotplug-правила маршрутизации
  - `sing-box-json.j2`, `config-sing-box.j2` - Конфигурация Sing-box

### Автономные shell-скрипты

- `getdomains-install.sh` - Интерактивный установщик с выбором туннеля/DNS
- `getdomains-uninstall.sh` - Скрипт полного удаления
- `getdomains-check.sh` - Проверка конфигурации с поддержкой i18n (русский/английский)
- `getdomains-manage.sh` - Управление пользовательскими доменами в рантайме

## Основные переменные роли

```yaml
tunnel: wg          # Варианты: wg, openvpn, singbox, tun2socks
dns_encrypt: false  # Варианты: false, dnscrypt, stubby
country: russia-inside  # Варианты: russia-inside, russia-outside, ukraine
list_domains: true  # Включить маршрутизацию по доменам
list_subnet: false  # Включить маршрутизацию по подсетям
list_ip: false      # Включить маршрутизацию по IP
```

## Особенности версий

В кодовой базе обширная версионно-специфичная логика в `tasks/main.yml`:
- OpenWrt 21.02: Ограниченные возможности dnsmasq, некоторые скрипты работают частично
- OpenWrt 22.03: Требуется dnsmasq-full >= 2.87 (из dev-репозитория)
- OpenWrt 23.05+: Полная поддержка функций с firewall4/nftables

При изменении задач проверяйте условия `when` с проверками `ansible_distribution_version`.

## Зависимости

- **Ansible-роль:** `gekmihesg.openwrt` (требуется для OpenWrt-специфичных модулей Ansible)
- **Мин. версия Ansible:** 2.10.7
- **Ключевые пакеты OpenWrt:** dnsmasq-full, curl, wireguard-tools, nftables
