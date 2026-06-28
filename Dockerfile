FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV REGION=ap

# Agar RUN pakai bash
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update -y && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    bash \
    openssh-server \
    curl \
    wget \
    unzip \
    python3 \
    passwd \
    ca-certificates \
    nano \
    vim \
    procps \
    net-tools \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Install ngrok
RUN wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip -O /tmp/ngrok.zip \
    && unzip /tmp/ngrok.zip -d /usr/local/bin \
    && chmod +x /usr/local/bin/ngrok \
    && rm -f /tmp/ngrok.zip

# Setup SSH
RUN mkdir -p /run/sshd \
    && ssh-keygen -A \
    && echo "PermitRootLogin yes" >> /etc/ssh/sshd_config \
    && echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config \
    && echo "UsePAM yes" >> /etc/ssh/sshd_config \
    && chsh -s /bin/bash root || true

# Start script pakai bash
RUN cat > /start.sh <<'EOF'
#!/usr/bin/env bash

# Support nama variable lama dan baru
TOKEN="${ngrokid:-${NGROK_TOKEN:-}}"
ROOT_PASS="${Password:-${ROOT_PASSWORD:-}}"
NGROK_REGION="${REGION:-ap}"

if [ -z "$ROOT_PASS" ]; then
  ROOT_PASS="craxid"
fi

echo "root:${ROOT_PASS}" | chpasswd

echo "==============================================="
echo " Ubuntu 20.04 SSH Server + Ngrok"
echo " Region   : ${NGROK_REGION}"
echo " User     : root"
echo " Password : ${ROOT_PASS}"
echo " Shell    : bash"
echo "==============================================="

if [ -z "$TOKEN" ]; then
  echo ""
  echo "ERROR: Token ngrok kosong!"
  echo "Tambahkan variable di Railway:"
  echo "ngrokid=TOKEN_NGROK_KAMU"
  echo "Password=password_kamu"
  echo "REGION=ap"
  echo ""
else
  ngrok config add-authtoken "$TOKEN" >/dev/null 2>&1

  ngrok tcp --region "$NGROK_REGION" 22 >/tmp/ngrok.log 2>&1 &

  echo "Menunggu URL ngrok..."

  for i in {1..15}; do
    sleep 2

    URL=$(curl -s http://127.0.0.1:4040/api/tunnels | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    tunnels = data.get("tunnels", [])
    if tunnels:
        print(tunnels[0].get("public_url", ""))
except:
    pass
' 2>/dev/null)

    if [ -n "$URL" ]; then
      echo ""
      echo "================ NGROK SSH URL ================"

      python3 - <<PY
url = "$URL"

if url.startswith("tcp://"):
    hostport = url.replace("tcp://", "")
    host, port = hostport.split(":")
    print("SSH Command:")
    print(f"ssh root@{host} -p {port}")
    print("")
    print("Raw URL:")
    print(url)
else:
    print("Public URL:")
    print(url)
PY

      echo ""
      echo "ROOT Password: ${ROOT_PASS}"
      echo "================================================"
      break
    fi

    if [ "$i" -eq 15 ]; then
      echo ""
      echo "Gagal ambil URL ngrok."
      echo "Cek token ngrok atau lihat log:"
      echo "cat /tmp/ngrok.log"
      echo ""
    fi
  done
fi

/usr/sbin/sshd -D
EOF

RUN chmod +x /start.sh

EXPOSE 22 80 443 8080 8888 4040

CMD ["/bin/bash", "/start.sh"]
