# Stage 1: Base image with Node.js LTS
FROM docker.io/library/node:lts-alpine AS base

# Prepare work directory
WORKDIR /elk

# Stage 2: Builder - install dependencies, generate required files, and build
FROM base AS builder

# Prepare pnpm via Corepack (workaround for registry key change issue)
# See: https://github.com/nodejs/corepack/issues/612#issuecomment-2629496091
RUN npm i -g corepack@latest && corepack enable

# Install Git for fetching any git-based dependencies
RUN apk update && apk add --no-cache git

# Copy all source files (including package.json, pnpm-lock.yaml, .npmrc, patches, etc.)
COPY . ./

# Install all dependencies, running postinstall scripts
RUN pnpm install --frozen-lockfile

# Generate translation status JSON required by the app
RUN npx nr prepare-translation-status

# Update stale-dep markers and run Nuxt prepare hooks
RUN pnpm dlx stale-dep -u && npx nuxi prepare

# Build the project
RUN pnpm build

# Stage 3: Runtime image
FROM base AS runner

# Default UID/GID for non-root Elk user
ARG UID=911
ARG GID=911

# Create a dedicated user and group matching builder stage
RUN set -eux; \
    addgroup -g $GID elk; \
    adduser -u $UID -D -G elk elk;

# Switch to non-root user
USER elk

# Set production environment
ENV NODE_ENV=production

# Copy built output from builder
COPY --from=builder /elk/.output ./.output

# Expose application port
EXPOSE 5314/tcp

# Port environment variable
ENV PORT=5314

# File-based storage path (persistent volume mount in Railway)
ENV NUXT_STORAGE_FS_BASE='/elk/data'

# Remove Dockerfile VOLUME keyword for Railway compatibility
# Persistent storage is managed by Railway volumes

# Fix permissions on the mounted storage volume and start the server
ENTRYPOINT ["sh", "-c", "chown -R 911:911 /elk/data && exec node .output/server/index.mjs"]
