
ARG ENVOY_VERSION
ARG CONSUL_VERSION

FROM hashicorp/consul:${CONSUL_VERSION} as consul-bin
FROM envoyproxy/envoy:${ENVOY_VERSION} as envoy-bin
# FROM vault:latest as vault-bin
# FROM nicholasjackson/fake-service:${FAKEAPP_VERSION} AS application
# FROM filebrowser/filebrowser:latest AS filebrowser

FROM alpine:latest

COPY --from=consul-bin /bin/consul /usr/local/bin/consul
COPY --from=envoy-bin /usr/local/bin/envoy /usr/local/bin/envoy
# COPY --from=envoy-bin /etc/envoy /etc/envoy


# https://stackoverflow.com/questions/66963068/docker-alpine-executable-binary-not-found-even-if-in-path
# https://www.gitmemory.com/issue/sgerrand/alpine-pkg-glibc/154/851078836
# RUN rm /usr/glibc-compat/lib/ld-linux-x86-64.so.2 && /usr/glibc-compat/sbin/ldconfig

## Install setcap for binary capabilities
RUN apk add --no-cache libcap
## Instal iptables for transparent proxies
# RUN apk add --no-cache iptables

## Add base packages useful for interacting with the running container
RUN apk add --no-cache -u bash vim curl bind-tools jq openssl dropbear dropbear-dbclient openssh-client

## Replaces init with tini for long lived containers that allow service restarts
RUN apk add --no-cache tini

## Add user wuth UID and GID 1000
RUN set -x ; addgroup --gid 1000 admin && \
	adduser -D -G "admin" \
    --shell "/bin/bash" \
	--home "/home/admin" \
	--uid 1000 \
	"admin"

## Folders for SSH server (Dropbear)
RUN mkdir /etc/dropbear
RUN chown 1000:1000 /etc/dropbear

## Folders for Consul agent
RUN mkdir /etc/consul.d
RUN chown 1000:1000 /etc/consul.d

## Define terminal
ENV TERM=xterm
ENV PS1='🐳:\[\033[1;36m\]\u@\h: \[\033[1;34m\]\w\[\033[0;35m\] \[\033[1;36m\]\$ \[\033[0m\]'

## Give binaries the capability to run on privileged ports without using root
RUN setcap 'cap_net_bind_service=+ep' /usr/local/bin/consul
RUN setcap 'cap_net_bind_service=+ep' /usr/local/bin/envoy
RUN setcap 'cap_net_bind_service=+ep' /usr/sbin/dropbear

## The image needs a cert-key pair to enable SSH automatically
## generate it with `ssh-keygen -t rsa -b 4096`
COPY ./certs/id_rsa.pub /etc/dropbear/authorized_keys
COPY ./certs/id_rsa.pub /home/admin/.ssh/authorized_keys

COPY ./certs/id_rsa.pub /home/admin/.ssh
COPY ./certs/id_rsa /home/admin/.ssh
RUN chown -R 1000:1000 /home/admin/.ssh

# RUN echo 'alias ssh="dbclient"' >> /home/admin/.bashrc

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]

CMD ["/entrypoint.sh"]