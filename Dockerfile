ARG NODE_IMAGE=public.ecr.aws/docker/library/node:24.18.0-alpine3.23@sha256:595398b0081eacda8e1c4c5b97b76cd1020e4d58a8ebcb4843b9bca1e79e7436

FROM ${NODE_IMAGE} AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts
COPY tsconfig.json ./
COPY src ./src
COPY db ./db
RUN npm run build

FROM build AS production-deps
RUN npm prune --omit=dev

FROM ${NODE_IMAGE} AS runtime
ENV NODE_ENV=production \
    PORT=8080
WORKDIR /app
RUN apk add --no-cache libcrypto3=3.5.8-r0 libssl3=3.5.8-r0 \
    && rm -rf /usr/local/lib/node_modules /opt/yarn-* \
    && rm -f /usr/local/bin/corepack /usr/local/bin/npm /usr/local/bin/npx \
      /usr/local/bin/pnpm /usr/local/bin/pnpx /usr/local/bin/yarn \
      /usr/local/bin/yarnpkg
COPY --from=build --chown=node:node /app/dist/src ./dist/src
COPY --from=production-deps --chown=node:node /app/node_modules ./node_modules
USER node
EXPOSE 8080
CMD ["node", "dist/src/index.js"]
