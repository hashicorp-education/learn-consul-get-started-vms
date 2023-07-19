ARG BASE_IMAGE

# ----------------- #
# | DOCKER IMAGES | #
# ----------------- #

FROM ${BASE_IMAGE}  

# ----------------- #
# | SW PACKAGES   | #
# ----------------- #

RUN apt-get update

RUN DEBIAN_FRONTEND=noninteractive \
	apt-get --assume-yes install nginx && \
	rm -rf /var/lib/apt/lists/*

# RUN mkdir -p /usr/share/nginx/html && chown -R 1000:1000 /usr/share/nginx/html

# COPY --from=base /usr/share/nginx/html /usr/share/nginx/html

RUN setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx

RUN mkdir -p /run/nginx && touch /run/nginx/nginx.pid && chown -R 1000:1000 /run/nginx && chown -R 1000:1000 /var/run/nginx
RUN mkdir /var/cache/nginx && chown -R 1000:1000 /var/cache/nginx

RUN mkdir -p /etc/nginx
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf
COPY def_upstreams.conf /etc/nginx/conf.d/def_upstreams.conf
	 
RUN chown -R 1000:1000 /etc/nginx
RUN chown -R 1000:1000 /usr/share/nginx/html

RUN mkdir -p /var/log/nginx && chown -R 1000:1000 /var/log/nginx
RUN mkdir -p /var/lib/nginx && chown -R 1000:1000 /var/lib/nginx

COPY start_nginx.sh /home/admin/start_service.sh
RUN  chown -R 1000:1000 /home/admin/start_service.sh && chmod +x /home/admin/start_service.sh

# ----------------- #
# | ENTRYPOINT    | #
# ----------------- #

EXPOSE 80

# The appliucation will be started manually ar runtime
# CMD ["nginx", "-g", "daemon off;"]