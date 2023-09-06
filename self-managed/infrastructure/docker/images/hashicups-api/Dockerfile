ARG APP1_VERSION
ARG APP2_VERSION
ARG APP3_VERSION

ARG BASE_IMAGE

# ----------------- #
# | DOCKER IMAGES | #
# ----------------- #

FROM hashicorpdemoapp/public-api:${APP1_VERSION} as application1
FROM hashicorpdemoapp/product-api:${APP2_VERSION} as application2
FROM hashicorpdemoapp/payments:${APP3_VERSION} as application3

FROM ${BASE_IMAGE} 

# ----------------- #
# | SW PACKAGES   | #
# ----------------- #

RUN apt-get update

RUN DEBIAN_FRONTEND=noninteractive \
	apt-get --assume-yes install default-jre postgresql-client && \
	rm -rf /var/lib/apt/lists/*

# Install Public API
COPY --from=application1 app/public-api /bin/public-api

# Install Product API
COPY --from=application2 /app/product-api /bin/product-api
COPY wait.sh /bin/
COPY conf.json /home/admin/conf.json
RUN  chown -R 1000:1000 /home/admin

RUN chmod +x /bin/product-api && chmod +x /bin/wait.sh

# Install Payments
COPY --from=application3 spring-boot-payments-*.jar /bin/spring-boot-payments.jar

# ----------------- #
# | ENTRYPOINT    | #
# ----------------- #

# Install startup script
COPY start_api.sh /home/admin/start_service.sh
RUN  chown -R 1000:1000 /home/admin/start_service.sh && chmod +x /home/admin/start_service.sh

EXPOSE 8080

# The appliucation will be started manually ar runtime
# Start Payments
# CMD ["/home/app/start_api.sh"]
