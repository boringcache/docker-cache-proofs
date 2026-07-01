# syntax=docker/dockerfile:1.7
FROM node:24.4.0-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable && corepack prepare pnpm@10.22.0 --activate

FROM base AS deps
WORKDIR /usr/src/app

RUN apt-get update && apt-get install -y python3 make g++ git python3-pip pkg-config libsecret-1-dev && rm -rf /var/lib/apt/lists/*

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/api/package.json apps/api/package.json
COPY apps/dokploy/package.json apps/dokploy/package.json
COPY apps/schedules/package.json apps/schedules/package.json
COPY packages/server/package.json packages/server/package.json

RUN --mount=type=cache,id=pnpm-dokploy-cloud,target=/pnpm/store,sharing=locked pnpm --filter=@dokploy/server --filter=./apps/dokploy install --frozen-lockfile

FROM deps AS build
COPY . /usr/src/app

ARG NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY
ENV NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=$NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY

ENV NODE_ENV=production
RUN pnpm --filter=@dokploy/server build
RUN --mount=type=cache,id=next-dokploy-cloud,target=/usr/src/app/apps/dokploy/.next/cache,sharing=locked pnpm --filter=./apps/dokploy run build

RUN pnpm --filter=./apps/dokploy --prod deploy --legacy /prod/dokploy

RUN cp -R /usr/src/app/apps/dokploy/.next /prod/dokploy/.next
RUN cp -R /usr/src/app/apps/dokploy/dist /prod/dokploy/dist

FROM base AS dokploy
WORKDIR /app

ENV NODE_ENV=production

RUN apt-get update && apt-get install -y curl unzip apache2-utils && rm -rf /var/lib/apt/lists/*

COPY --from=build /prod/dokploy/.next ./.next
COPY --from=build /prod/dokploy/dist ./dist
COPY --from=build /prod/dokploy/next.config.mjs ./next.config.mjs
COPY --from=build /prod/dokploy/public ./public
COPY --from=build /prod/dokploy/package.json ./package.json
COPY --from=build /prod/dokploy/drizzle ./drizzle
COPY --from=build /prod/dokploy/components.json ./components.json
COPY --from=build /prod/dokploy/node_modules ./node_modules

RUN curl https://rclone.org/install.sh | bash
RUN pnpm install -g tsx

EXPOSE 3000
CMD [ "pnpm", "start" ]
