FROM debian:stable

ARG ngrokid
ARG Password

ENV Password=${Password}
ENV ngrokid=${ngrokid}

RUN apt update -y > /dev/null 2>&1 && apt upgrade -y > /dev/null 2>&1
RUN apt install openssh-server wget unzip curl python3 passwd -y > /dev/null 2>&1

RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.zip > /dev/null 2>&1
RUN unzip ngrok.zip
RUN chmod +x ./ngrok

RUN mkdir -p /run/sshd
RUN ssh-keygen -A

RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
RUN echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config

RUN echo './ngrok config add-authtoken ${ngrokid} &&' >> /1.sh
RUN echo './ngrok tcp 22 &>/dev/null &' >> /1.sh
RUN echo 'sleep 5' >> /1.sh
RUN echo 'curl -s http://localhost:4040/api/tunnels || true' >> /1.sh
RUN echo '/usr/sbin/sshd -D' >> /1.sh

RUN echo root:${Password}|chpasswd
RUN chmod 755 /1.sh

EXPOSE 80 8888 8080 443 5130 5131 5132 5133 5134 5135 3306

CMD /1.sh
