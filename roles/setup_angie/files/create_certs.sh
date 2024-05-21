#!/usr/bin/env bash

SELF_NAME="$(basename $0)"

function failDueArg() {
    echo "Usage: ${SELF_NAME} <full_domain>"
    exit 1
}

if [ "$1" = "" ]; then
  failDueArg
fi

domain=${1}

if [[ -f "/etc/letsencrypt/live/${domain}/privkey.pem" || -f "/etc/letsencrypt/live/${domain}/fullchain.pem" ]]; then
  echo "Файл сертификата уже существует"
elif [[ -f "/root/.acme.sh/${domain}_ecc/${domain}.key" && -f "/root/.acme.sh/${domain}_ecc/${domain}.cer" ]]; then
  echo "Файл сертификата уже существует"
  /root/.acme.sh/acme.sh --installcert -d "${domain}" --fullchainpath /etc/letsencrypt/live/${domain}/fullchain.pem --keypath /etc/letsencrypt/live/${domain}/privkey.pem --ecc
else
  systemctl stop angie.service
  apt install socat netcat -y
  cd && curl https://get.acme.sh | sh
  /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
  mkdir -p /etc/letsencrypt/live/${domain}
  if /root/.acme.sh/acme.sh --issue --insecure -d "${domain}" --standalone -k ec-256 --force; then
    echo "SSL-сертификат успешно сгенерирован"
    sleep 2
    if /root/.acme.sh/acme.sh --installcert -d "${domain}" --fullchainpath /etc/letsencrypt/live/${domain}/fullchain.pem --keypath /etc/letsencrypt/live/${domain}/privkey.pem --ecc --force; then
      echo "Конфигурация сертификата прошла успешно"
    fi
  else
    echo "Не удалось создать SSL-сертификат"
    rm -rf "/root/.acme.sh/${domain}_ecc"
    exit 1
  fi
  systemctl start angie.service
  cat > /usr/bin/ssl_update_${domain}.sh <<EOF
#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
systemctl stop angie &> /dev/null
sleep 1
"/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" &> /dev/null
"/root/.acme.sh"/acme.sh --installcert -d ${domain} --fullchainpath /etc/letsencrypt/live/${domain}/fullchain.pem --keypath /etc/letsencrypt/live/${domain}/privkey.pem --ecc
sleep 1
systemctl start angie &> /dev/null
EOF
  chmod 755 /usr/bin/ssl_update_${domain}.sh
  if [[ $(crontab -l | grep -c "ssl_update_${domain}.sh") -lt 1 ]]; then
    sed -i "/acme.sh/c $((RANDOM%59)) 3 * * 0 bash /usr/bin/ssl_update_${domain}.sh" /var/spool/cron/crontabs/root
    echo '58 0 * * * "/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" > /dev/null' >> /var/spool/cron/crontabs/root
  fi
fi