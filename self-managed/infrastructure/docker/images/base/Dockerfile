
# ----------------- #
# | DOCKER IMAGES | #
# ----------------- #

## Using Debian as base system
FROM debian:latest

# ----------------- #
# | SW PACKAGES   | #
# ----------------- #

## Install needed utils

## Update repositories
RUN apt-get update

## Install `setcap` for binary capabilities
## Install `tini` as init process
RUN DEBIAN_FRONTEND=noninteractive \
	apt-get --assume-yes install bash bash-completion lsb-release \
								vim curl wget dnsutils jq iputils-ping tree unzip \
								procps net-tools\
								openssl dropbear openssh-client openssh-sftp-server gnupg \
								libcap2-bin \
								tini \
								sudo && \
	rm -rf /var/lib/apt/lists/*

# Add repositories
# HashiCorp repository
RUN curl --fail --silent --show-error --location https://apt.releases.hashicorp.com/gpg | \
		gpg --dearmor | \
		dd of=/usr/share/keyrings/hashicorp-archive-keyring.gpg

RUN echo "deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
		tee -a /etc/apt/sources.list.d/hashicorp.list

## Give binaries the capability to run on privileged ports without using root
RUN setcap 'cap_net_bind_service=+ep' /usr/sbin/dropbear

# ----------------- #
# | USERS         | #
# ----------------- #

# Add 'admin' user with UID and GID 1000
RUN addgroup --gid 1000 admin && \
	adduser \
	--disabled-password \
	--shell "/bin/bash" \
	--home "/home/admin" \
	--uid 1000 \
	--gid 1000 \
	--gecos '' \
	"admin"

RUN adduser admin sudo

RUN echo "admin ALL = (root) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/admin
RUN chmod 0440 /etc/sudoers.d/admin

## Set users password
RUN echo admin:admin | chpasswd
RUN echo root:toor | chpasswd

# ----------------- #
# | TERMINAL      | #
# ----------------- #

# Set prompt and aliases
## Tring out icons 💻 🐳 👾 🔥 🐧 🍥 🍄 💀 👤 👊 👉 ⭕ 🔷 🔵
ENV TERM=xterm
ENV PS1='🔵:\[\033[1;36m\]\u@\h: \[\033[1;34m\]\w\[\033[0;35m\] \[\033[1;36m\]\$ \[\033[0m\]'

COPY ./bash.aliases /etc/bash.aliases
RUN printf "\n source /etc/bash.aliases \n" >> /home/admin/.bashrc
RUN printf "\n source /etc/bash.aliases \n" >> /etc/bash.bashrc

# ----------------- #
# | SSH ACCESS    | #
# ----------------- #

## Create folders for SSH server (Dropbear)
RUN mkdir -p /etc/dropbear
RUN chown -R 1000:1000 /etc/dropbear

## The image needs a cert-key pair to enable SSH automatically
## generate it with `ssh-keygen -t rsa -b 4096`
COPY ./certs /home/admin/certs

COPY ./certs/id_rsa.pub /etc/dropbear/authorized_keys

COPY ./certs/id_rsa.pub /home/admin/.ssh/authorized_keys
COPY ./certs/id_rsa.pub /home/admin/.ssh
COPY ./certs/id_rsa /home/admin/.ssh

COPY ./certs/id_rsa.pub /root/.ssh/authorized_keys
COPY ./certs/id_rsa.pub /root/.ssh
COPY ./certs/id_rsa /root/.ssh

COPY ./ssh_config /home/admin/.ssh/config
COPY ./ssh_config /root/.ssh/config

RUN chown -R 1000:1000 /home/admin/.ssh
RUN chown -R 1000:1000 /home/admin/certs

# ----------------- #
# | ENTRYPOINT    | #
# ----------------- #

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]

CMD ["/entrypoint.sh"]