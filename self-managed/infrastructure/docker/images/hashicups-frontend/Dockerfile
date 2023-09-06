ARG BASE_IMAGE
ARG APP_VERSION

# ----------------- #
# | DOCKER IMAGES | #
# ----------------- #

# FROM hashicorpdemoapp/frontend:${APP_VERSION} as application
# FROM im2nguyenhashi/hashicups-frontend:latest as application
FROM im2nguyenhashi/frontend-localhost:latest as application

FROM ${BASE_IMAGE} 

# ----------------- #
# | SW PACKAGES   | #
# ----------------- #

RUN apt-get update

RUN DEBIAN_FRONTEND=noninteractive \
	apt-get --assume-yes install nodejs && \
	rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV NEXT_PUBLIC_PUBLIC_API_URL /
# Uncomment the following line in case you want to disable telemetry during runtime.
# ENV NEXT_TELEMETRY_DISABLED 1

# RUN addgroup --system --gid 1001 nodejs
# RUN adduser --system --uid 1001 nextjs

# You only need to copy next.config.js if you are NOT using the default configuration
# COPY --from=builder /app/next.config.js ./
COPY --from=application /app/public ./public
COPY --from=application /app/.next ./.next
COPY --from=application /app/node_modules ./node_modules
COPY --from=application /app/package.json ./package.json

RUN chown -R 1000:1000 /app

# COPY --from=application /app/entrypoint.sh ./entrypoint.sh
COPY start_frontend.sh /home/admin/start_service.sh
RUN  chown -R 1000:1000 /home/admin/start_service.sh && chmod +x /home/admin/start_service.sh

# ----------------- #
# | ENTRYPOINT    | #
# ----------------- #

USER admin

EXPOSE 3000

ENV PORT 3000

# The application will be started manually ar runtime
# CMD ["/app/start_frontend.sh"]