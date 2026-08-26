# syntax=docker/dockerfile:1

FROM node:16-bullseye-slim AS builder

WORKDIR /app

RUN apt-get update \
	&& apt-get install -y --no-install-recommends python3 make g++ git ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

ENV CI=true \
	HUSKY=0 \
	HUSKY_SKIP_INSTALL=1 \
	SKIP_PREFLIGHT_CHECK=true \
	DISABLE_ESLINT_PLUGIN=true \
	GENERATE_SOURCEMAP=false \
	NODE_OPTIONS=--max-old-space-size=2048 \
	npm_config_legacy_peer_deps=true

COPY package.json ./
RUN npm install --legacy-peer-deps --no-audit --no-fund

COPY . .
COPY .env-cmdrc.docker .env-cmdrc

RUN node -e "const fs=require('fs'); const pkg=require('./package.json'); const env=JSON.parse(fs.readFileSync('.env-cmdrc','utf8')); env.default.REACT_APP_VERSION=pkg.version; fs.writeFileSync('.env-cmdrc', JSON.stringify(env, null, '\t'));" \
	&& mkdir -p public/logs \
	&& npm run build

FROM nginx:1.27-alpine

LABEL org.opencontainers.image.source="https://github.com/TheFel0x/ffxiv-ember-overlay" \
	org.opencontainers.image.title="FFXIV Ember Overlay" \
	org.opencontainers.image.description="Self-hosted Ember Overlay for OverlayPlugin / ACT"

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/build /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
	CMD wget -q -O /dev/null http://127.0.0.1/healthz || exit 1
