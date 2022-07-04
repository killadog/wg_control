#!/bin/bash

RED='\033[0;31m'
IRED='\033[0;91m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color

WG_SERVER_NAME=<Server name (wg0-server)>
WG_DIR=<Location of WireGuard (/etc/wireguard)>
WG_SERVER_CONF=<Server configuration file (${WG_DIR}/wg0-server.conf)>
WG_SERVER_ADDRESS=<WireGuard server address (wg.example.com or 77.107.144.26)>
WG_SERVER_PORT=<Port of WireGuard server (51820)>
MAIL_SERVER_ADDRESS=<SMTP server address (smtp.example.com)>
MAIL_SERVER_PORT=<SMTP server port (465)>
MAIL_FROM=<Sender e-mail (wg@wg.example.com)>
MAIL_FROM_PASSWORD=<Sender password>
NETWORK=<Network for vpn (10.0.0)>

while true; do

echo -e "-----------------------------------
${YELLOW}1${NC} - show server config file
${YELLOW}2${NC} - create peer
${YELLOW}3${NC} - restart WireGuard server (reload config)
${YELLOW}4${NC} - wg show
${YELLOW}q${NC} - exit"

read -rN1 -p "Enter your choice: " CHOICE

echo -e "\n-----------------------------------"

case $CHOICE in
    1) 
    echo -e $GREEN
    cat $WG_SERVER_CONF
    echo -e $NC
;;

    2)
read -p "Enter PEER name (e.g. Dr_Smith): " PEER
read -p "Enter IP address (only last octet to ${NETWORK}.x): " IP
read -p "Enter e-mail: " EMAIL

SERVER_PUBLIC_KEY=${WG_DIR}/public-server.key
PEERS_DIR=${WG_DIR}/peers

SERVER_PUBLIC_KEY=$(cat $SERVER_PUBLIC_KEY)
PEER_PRIVATE_KEY_FILENAME="${PEER}_private.key"
PEER_PUBLIC_KEY_FILENAME="${PEER}_public.key"
PEER_CONF_FILENAME="${PEER}.conf"

echo "-----------------------------------"
umask 077; wg genkey > $PEERS_DIR/${PEER_PRIVATE_KEY_FILENAME}
echo "PEER PRIVATE key ($PEERS_DIR/$PEER_PRIVATE_KEY_FILENAME):"
PEER_PRIVATE_KEY=$(cat $PEERS_DIR/$PEER_PRIVATE_KEY_FILENAME)
echo -e "${GREEN}${PEER_PRIVATE_KEY}\n${NC}"

wg pubkey < $PEERS_DIR/${PEER_PRIVATE_KEY_FILENAME} > $PEERS_DIR/$PEER_PUBLIC_KEY_FILENAME
echo "PEER PUBLIC key ($PEERS_DIR/$PEER_PUBLIC_KEY_FILENAME):"
PEER_PUBLIC_KEY=$(cat $PEERS_DIR/$PEER_PUBLIC_KEY_FILENAME)
echo -e "${GREEN}${PEER_PUBLIC_KEY}\n${NC}"

echo "-----------------------------------"
echo "$PEERS_DIR/$PEER_CONF_FILENAME"
echo "-----------------------------------"

echo "[Interface]
PrivateKey = $PEER_PRIVATE_KEY
Address = ${NETWORK}.${IP}/24
DNS = 192.168.0.1, 192.168.0.2, 8.8.8.8

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
AllowedIPs = 0.0.0.0/0
Endpoint = ${WG_SERVER_ADDRESS}:${WG_SERVER_PORT}
PersistentKeepalive = 20" > $PEERS_DIR/$PEER_CONF_FILENAME

echo -e "${GREEN}"
cat $PEERS_DIR/$PEER_CONF_FILENAME
echo -e "${NC}"

echo -e "\n-----------------------------------"
echo "QR code in $PEERS_DIR/${PEER}_QR_code.txt"
echo "-----------------------------------"

qrencode -t ansiutf8 < $PEERS_DIR/$PEER_CONF_FILENAME
qrencode -t utf8 -o $PEERS_DIR/${PEER}_QR_code.txt < $PEERS_DIR/$PEER_CONF_FILENAME
qrencode -t png -o $PEERS_DIR/${PEER}_QR_code.png < $PEERS_DIR/$PEER_CONF_FILENAME

echo -e "\n-----------------------------------"
echo "Add this to $WG_SERVER_CONF"
echo "-----------------------------------"

echo -e "${IRED}[Peer]
#$PEER
PublicKey = $PEER_PUBLIC_KEY
AllowedIPs = 10.0.0.${IP}/32${NC}"

wg set wg0-server peer $PEER_PUBLIC_KEY allowed-ips 10.0.0.${IP}/32

echo -e "\n-----------------------------------"
echo "Do it to reload server"
echo "-----------------------------------"
echo -e "${IRED}wg-quick down $WG_SERVER_NAME && wg-quick up $WG_SERVER_NAME${NC}"

if [ -n "$EMAIL" ]; then
    echo -e "\n-----------------------------------"
    echo -e "Send e-mail to $EMAIL"
    echo -e "-----------------------------------\n"

curl smtps://${MAIL_SERVER_ADDRESS}:${MAIL_SERVER_PORT} --anyauth \
--mail-from $MAIL_FROM \
--mail-rcpt $EMAIL \
--user ${MAIL_FROM}:${MAIL_FROM_PASSWORD} \
-T <(echo "From: $MAIL_FROM
To: $EMAIL
Subject: WireGuard for $PEER
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary=\"boundary1\"

--boundary1
Content-Type: text/plain;

Hello! Here is WireGuard client settings.

Peer private key - $PEER_PRIVATE_KEY
Peer public key  - $PEER_PUBLIC_KEY

--boundary1
Content-Type: image/png; name=\"${PEER}_QR_code.png\"
Content-Transfer-Encoding: base64
Content-Disposition: inline; filename=\"${PEER}_QR_code.png\"
Content-Id: <${PEER}_QR_code.png>

$(cat $PEERS_DIR/${PEER}_QR_code.png | base64)

--boundary1
Content-Type: text/plain;
Content-Transfer-Encoding: base64
Content-Disposition: inline; filename=\"$PEER_CONF_FILENAME\"

$(cat $PEERS_DIR/$PEER_CONF_FILENAME | base64)

--boundary1--

")

fi
;;

3)
echo -e "${GREEN}Restart WireGuard server"
wg-quick down $WG_SERVER_NAME && wg-quick up $WG_SERVER_NAME
echo -e "${NC}"
;;

4)
wg show
;;

q)
echo
exit
;;

*)
;;
esac
done;