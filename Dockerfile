FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV REGION=ap

RUN apt-get update -y && apt-get install -y --no-install-recommends \
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
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config \
    && echo "PermitRootLogin yes" >> /etc/ssh/sshd_config \
    && echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config \
    && echo "UsePAM yes" >> /etc/ssh/sshd_config

# Start script
RUN cat > /start.sh <<'EOF'
#!/bin/sh

clear

# Support nama variable lama dan baru
TOKEN="${ngrokid:-$NGROK_TOKEN}"
ROOT_PASS="${Password:-$ROOT_PASSWORD}"
NGROK_REGION="${REGION:-ap}"

if [ -z "$ROOT_PASS" ]; then
  ROOT_PASS="craxid"
fi

echo "root:${ROOT_PASS}" | chpasswd

echo "==============================================="
echo " Starting SSH Server + Ngrok"
echo " Region   : ${NGROK_REGION}"
echo " User     : root"
echo " Password : ${ROOT_PASS}"
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
  sleep 8

  echo ""
  echo "================ NGROK SSH URL ================"

  curl -s http://127.0.0.1:4040/api/tunnels | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    tunnels = data.get("tunnels", [])
    if not tunnels:
        print("Ngrok tunnel belum muncul.")
        sys.exit(1)

    url = tunnels[0].get("public_url", "")
    if url.startswith("tcp://"):
        hostport = url.replace("tcp://", "")
        host, port = hostport.split(":")
        print("SSH Command:")
        print(f"ssh root@{host} -p {port}")
        print("")
        print("Raw URL:")
        print(url)
    else:
        print("Public URL:", url)
except Exception as e:
    print("Gagal ambil URL ngrok:", e)
' || echo "Gagal ambil URL ngrok. Cek token atau log /tmp/ngrok.log"

  echo ""
  echo "ROOT Password: ${ROOT_PASS}"
  echo "==============================================="
fi

/usr/sbin/sshd -D
EOF

RUN chmod +x /start.sh

EXPOSE 22 80 443 8080 8888 4040

CMD ["/bin/sh", "/start.sh"]
