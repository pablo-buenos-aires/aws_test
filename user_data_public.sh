#!/bin/bash
set -euxo pipefail  # error,undefuned, exec, честные пайплайны ошибок
export DEBIAN_FRONTEND=noninteractive # чтобы не было вопросов
echo "netfilter-persistent netfilter-persistent/autosave_v4 boolean true" | debconf-set-selections
echo "netfilter-persistent netfilter-persistent/autosave_v6 boolean false" | debconf-set-selections

#  пакеты для автосохранения правил
apt-get update -y
apt-get install -y netfilter-persistent

# Включаем форвардинг и делаем это постоянным
sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-nat.conf #  reboot-safe
sysctl --system

# CIDR подставит terraform
VPC_CIDR="${aws_vpc.my_vpc.cidr_block}"

# Аккуратно берём внешний интерфейс по default route (IPv4)
EXT_IF="$(ip -o -4 route show to default | awk '{print $5}' | head -n1)"

# Добавляем MASQUERADE, если ещё нет (чтобы не дублировать)
if ! iptables -t nat -C POSTROUTING -s "$VPC_CIDR" -o "$EXT_IF" -j MASQUERADE 2>/dev/null; then
  iptables -t nat -A POSTROUTING -s "$VPC_CIDR" -o "$EXT_IF" -j MASQUERADE
fi
#
netfilter-persistent save
systemctl enable --now netfilter-persistent