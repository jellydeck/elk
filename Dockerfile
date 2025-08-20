FROM node:lts-alpine AS base
WORKDIR /elk

FROM base AS builder
# Install Corepack, Git, etc.
RUN npm i -g corepack@latest && corepack enable
RUN apk update && apk add --no-cache git

# Bring in everything
COPY . ./

# Install deps
RUN pnpm install --frozen-lockfile

# Generate translation status JSON
RUN pnpm dlx nr prepare-translation-status

# Update stale-dep markers & run Nuxt prepare
RUN pnpm dlx stale-dep -u && npx nuxi prepare

# Now build
RUN pnpm build

FROM base AS runner
ARG UID=911 GID=911
RUN addgroup -g $GID elk && adduser -D -u $UID -G elk elk
USER elk
ENV NODE_ENV=production PORT=5314 NUXT_STORAGE_FS_BASE='/elk/data'
COPY --from=builder /elk/.output ./.output
EXPOSE 5314
ENTRYPOINT ["sh","-c","chown -R 911:911 /elk/data && exec node .output/server/index.mjs"]
