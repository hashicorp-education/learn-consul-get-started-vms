ARG CONSUL_VERSION
ARG ENVOY_VERSION
ARG BASE_IMAGE

# ----------------- #
# | DOCKER IMAGES | #
# ----------------- #

FROM hashicorp/consul:${CONSUL_VERSION} as consul-bin
FROM envoyproxy/envoy:${ENVOY_VERSION} as envoy-bin
FROM grafana/agent:latest as grafana-agent-bin
FROM hashicorp/consul-template:latest as consul-template-bin

FROM ${BASE_IMAGE}

# ----------------- #
# | SW PACKAGES   | #
# ----------------- #

COPY --from=grafana-agent-bin /usr/bin/grafana-agent /usr/bin/grafana-agent
COPY --from=envoy-bin /usr/local/bin/envoy /usr/bin/envoy
COPY --from=consul-bin /bin/consul /usr/bin/consul
COPY --from=consul-template-bin /bin/consul-template /usr/bin/consul-template

RUN chown -R 1000:1000 /usr/bin/consul
RUN chown -R 1000:1000 /usr/bin/consul-template
RUN chown -R 1000:1000 /usr/bin/envoy
RUN chown -R 1000:1000 /usr/bin/grafana-agent

## Give binaries the capability to run on privileged ports without using root
RUN setcap 'cap_net_bind_service=+ep' /usr/bin/consul
RUN setcap 'cap_net_bind_service=+ep' /usr/bin/envoy

RUN mkdir -p /etc/consul.d
RUN chown -R 1000:1000 /etc/consul.d
RUN mkdir -p /opt/consul
RUN chown -R 1000:1000 /opt/consul

# ----------------- #
# | ENTRYPOINT    | #
# ----------------- #

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]

CMD ["/entrypoint.sh"]