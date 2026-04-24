#!/bin/sh

# Скрипт управления пользовательскими доменами для туннелирования
# Версия: 1.0

# Константы
USER_DOMAINS_CONF="/etc/getdomains/user-domains.conf"
EXCLUDE_DOMAINS_CONF="/etc/getdomains/exclude-domains.conf"
USER_DOMAINS_LST="/tmp/dnsmasq.d/user-domains.lst"
MAIN_DOMAINS_LST="/tmp/dnsmasq.d/domains.lst"
NFSET_FORMAT="nftset=/%s/4#inet#fw4#vpn_domains"

# Цвета
GREEN='\033[32;1m'
RED='\033[31;1m'
YELLOW='\033[33;1m'
NC='\033[0m'

# Инициализация директорий и файлов
init_dirs() {
    mkdir -p /etc/getdomains
    mkdir -p /tmp/dnsmasq.d
    touch "$USER_DOMAINS_CONF"
    touch "$EXCLUDE_DOMAINS_CONF"
}

# Валидация формата домена
validate_domain() {
    echo "$1" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
}

# Генерация файла user-domains.lst для dnsmasq
generate_user_lst() {
    > "$USER_DOMAINS_LST"
    if [ -f "$USER_DOMAINS_CONF" ] && [ -s "$USER_DOMAINS_CONF" ]; then
        while IFS= read -r domain || [ -n "$domain" ]; do
            [ -n "$domain" ] && printf "$NFSET_FORMAT\n" "$domain" >> "$USER_DOMAINS_LST"
        done < "$USER_DOMAINS_CONF"
    fi
}

# Применение исключений к основному списку доменов
apply_exclusions() {
    if [ -f "$EXCLUDE_DOMAINS_CONF" ] && [ -s "$EXCLUDE_DOMAINS_CONF" ] && [ -f "$MAIN_DOMAINS_LST" ]; then
        while IFS= read -r domain || [ -n "$domain" ]; do
            [ -n "$domain" ] && sed -i "/$domain/d" "$MAIN_DOMAINS_LST"
        done < "$EXCLUDE_DOMAINS_CONF"
    fi
}

# Перезапуск dnsmasq с проверкой конфигурации
restart_dnsmasq() {
    local test_result

    # Проверяем user-domains.lst если он не пустой
    if [ -s "$USER_DOMAINS_LST" ]; then
        test_result=$(dnsmasq --conf-file="$USER_DOMAINS_LST" --test 2>&1)
        if ! echo "$test_result" | grep -q "syntax check OK"; then
            printf "${RED}Ошибка синтаксиса в user-domains.lst${NC}\n"
            return 1
        fi
    fi

    /etc/init.d/dnsmasq restart
    printf "${GREEN}dnsmasq перезапущен${NC}\n"
}

# Добавить домен в туннель
add_domain() {
    printf "Введите домен: "
    read -r domain

    # Удаление пробелов
    domain=$(echo "$domain" | tr -d ' ')

    if [ -z "$domain" ]; then
        printf "${RED}Домен не может быть пустым${NC}\n"
        return 1
    fi

    if ! validate_domain "$domain"; then
        printf "${RED}Неверный формат домена${NC}\n"
        return 1
    fi

    if grep -qx "$domain" "$USER_DOMAINS_CONF" 2>/dev/null; then
        printf "${YELLOW}Домен уже добавлен${NC}\n"
        return 1
    fi

    # Проверка на наличие в списке исключений
    if grep -qx "$domain" "$EXCLUDE_DOMAINS_CONF" 2>/dev/null; then
        printf "${YELLOW}Внимание: этот домен находится в списке исключений${NC}\n"
    fi

    echo "$domain" >> "$USER_DOMAINS_CONF"
    generate_user_lst
    restart_dnsmasq
    printf "${GREEN}Домен $domain добавлен в туннель${NC}\n"
}

# Удалить домен из туннеля
remove_domain() {
    if [ ! -s "$USER_DOMAINS_CONF" ]; then
        printf "${YELLOW}Список пользовательских доменов пуст${NC}\n"
        return 1
    fi

    printf "\n${GREEN}Добавленные домены:${NC}\n"
    nl -ba "$USER_DOMAINS_CONF"
    printf "\nВведите номер или домен для удаления: "
    read -r input

    if [ -z "$input" ]; then
        printf "${RED}Ничего не введено${NC}\n"
        return 1
    fi

    if echo "$input" | grep -qE '^[0-9]+$'; then
        domain=$(sed -n "${input}p" "$USER_DOMAINS_CONF")
        if [ -z "$domain" ]; then
            printf "${RED}Неверный номер${NC}\n"
            return 1
        fi
    else
        domain="$input"
    fi

    if grep -qx "$domain" "$USER_DOMAINS_CONF"; then
        sed -i "/^${domain}$/d" "$USER_DOMAINS_CONF"
        generate_user_lst
        restart_dnsmasq
        printf "${GREEN}Домен $domain удалён${NC}\n"
    else
        printf "${RED}Домен не найден${NC}\n"
    fi
}

# Исключить домен из туннелирования
exclude_domain() {
    printf "Введите домен для исключения из туннелирования: "
    read -r domain

    # Удаление пробелов
    domain=$(echo "$domain" | tr -d ' ')

    if [ -z "$domain" ]; then
        printf "${RED}Домен не может быть пустым${NC}\n"
        return 1
    fi

    if ! validate_domain "$domain"; then
        printf "${RED}Неверный формат домена${NC}\n"
        return 1
    fi

    if grep -qx "$domain" "$EXCLUDE_DOMAINS_CONF" 2>/dev/null; then
        printf "${YELLOW}Домен уже в списке исключений${NC}\n"
        return 1
    fi

    echo "$domain" >> "$EXCLUDE_DOMAINS_CONF"
    apply_exclusions
    restart_dnsmasq
    printf "${GREEN}Домен $domain исключён из туннелирования${NC}\n"
}

# Убрать исключение домена
unexclude_domain() {
    if [ ! -s "$EXCLUDE_DOMAINS_CONF" ]; then
        printf "${YELLOW}Список исключений пуст${NC}\n"
        return 1
    fi

    printf "\n${GREEN}Исключённые домены:${NC}\n"
    nl -ba "$EXCLUDE_DOMAINS_CONF"
    printf "\nВведите номер или домен: "
    read -r input

    if [ -z "$input" ]; then
        printf "${RED}Ничего не введено${NC}\n"
        return 1
    fi

    if echo "$input" | grep -qE '^[0-9]+$'; then
        domain=$(sed -n "${input}p" "$EXCLUDE_DOMAINS_CONF")
        if [ -z "$domain" ]; then
            printf "${RED}Неверный номер${NC}\n"
            return 1
        fi
    else
        domain="$input"
    fi

    if grep -qx "$domain" "$EXCLUDE_DOMAINS_CONF"; then
        sed -i "/^${domain}$/d" "$EXCLUDE_DOMAINS_CONF"
        # Перезагрузить основной список для восстановления домена
        printf "${YELLOW}Перезагрузка основного списка доменов...${NC}\n"
        /etc/init.d/getdomains start
        printf "${GREEN}Исключение для $domain снято${NC}\n"
    else
        printf "${RED}Домен не найден${NC}\n"
    fi
}

# Показать добавленные домены
list_user_domains() {
    printf "\n${GREEN}=== Добавленные домены ===${NC}\n"
    if [ -s "$USER_DOMAINS_CONF" ]; then
        nl -ba "$USER_DOMAINS_CONF"
        printf "\nВсего: $(wc -l < "$USER_DOMAINS_CONF") доменов\n"
    else
        printf "${YELLOW}Список пуст${NC}\n"
    fi
}

# Показать исключённые домены
list_excluded_domains() {
    printf "\n${GREEN}=== Исключённые домены ===${NC}\n"
    if [ -s "$EXCLUDE_DOMAINS_CONF" ]; then
        nl -ba "$EXCLUDE_DOMAINS_CONF"
        printf "\nВсего: $(wc -l < "$EXCLUDE_DOMAINS_CONF") доменов\n"
    else
        printf "${YELLOW}Список пуст${NC}\n"
    fi
}

# Главное меню
show_menu() {
    while true; do
        printf "\n${GREEN}=== Управление доменами ===${NC}\n"
        printf "1) Добавить домен в туннель\n"
        printf "2) Удалить домен из туннеля\n"
        printf "3) Исключить домен из туннелирования\n"
        printf "4) Убрать исключение домена\n"
        printf "5) Показать добавленные домены\n"
        printf "6) Показать исключённые домены\n"
        printf "7) Выход\n"
        printf "\nВыберите действие [1-7]: "

        read -r choice

        case $choice in
            1) add_domain ;;
            2) remove_domain ;;
            3) exclude_domain ;;
            4) unexclude_domain ;;
            5) list_user_domains ;;
            6) list_excluded_domains ;;
            7)
                printf "${GREEN}До свидания!${NC}\n"
                exit 0
                ;;
            *) printf "${RED}Неверный выбор. Введите число от 1 до 7${NC}\n" ;;
        esac
    done
}

# Проверка что скрипт запущен на OpenWrt
check_openwrt() {
    if [ ! -f /etc/openwrt_release ]; then
        printf "${YELLOW}Внимание: Скрипт предназначен для OpenWrt${NC}\n"
    fi
}

# Точка входа
main() {
    check_openwrt
    init_dirs
    show_menu
}

main
