# ARG BASE_VERSION
# ARG APP_VERSION
ARG BASE_IMAGE

# ----------------- #
# | DOCKER IMAGES | #
# ----------------- #

FROM postgres:latest as pgres
# FROM hashicorpdemoapp/product-api-db:${APP_VERSION} as base
FROM ${BASE_IMAGE} 

# ----------------- #
# | SW PACKAGES   | #
# ----------------- #

RUN apt-get update

RUN DEBIAN_FRONTEND=noninteractive \
	apt-get --assume-yes install postgresql postgresql-client postgresql-contrib && \
	rm -rf /var/lib/apt/lists/*

RUN mkdir /docker-entrypoint-initdb.d

COPY --from=pgres /usr/local/bin/docker-entrypoint.sh /usr/local/bin/

COPY products.sql /docker-entrypoint-initdb.d/
COPY pg_hba.conf /home/admin

RUN mkdir -p /var/run/postgresql && chown -R 1000:1000 /var/run/postgresql && chmod 2777 /var/run/postgresql

ENV PGDATA /var/lib/postgresql/data
# ENV POSTGRES_HOST_AUTH_METHOD trust
ENV POSTGRES_DB products
ENV POSTGRES_USER postgres
ENV POSTGRES_PASSWORD password
# # this 777 will be replaced by 700 at runtime (allows semi-arbitrary "--user" values)
RUN mkdir -p "$PGDATA" && \
    chown -R 1000:1000 "$PGDATA" && \
    chmod 777 "$PGDATA" && \
    chown -R 1000:1000 /var/lib/postgresql && \
    chown -R 1000:1000 /etc/postgresql
    

# ----------------- #
# | ENTRYPOINT    | #
# ----------------- #

COPY start_database.sh /home/admin/start_service.sh
RUN  chown -R 1000:1000 /home/admin/start_service.sh && chmod +x /home/admin/start_service.sh

STOPSIGNAL SIGINT

EXPOSE 5432

# The appliucation will be started manually ar runtime
# CMD ["docker-entrypoint.sh", "postgres"]



# CMD ["postgres", "--version"]