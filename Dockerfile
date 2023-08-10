FROM emscripten/emsdk:latest AS emsdk

RUN git clone --depth=1 https://github.com/IFCjs/web-ifc.git && \
    cd web-ifc && \
    npm install && \
    npm run build-release

FROM node:16-slim AS builder

RUN apt-get update && \
    apt-get install -y git python3 pkg-config libx11-dev libxi-dev libgl-dev libpixman-1-dev libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev g++ make && \
    apt-get clean && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src

COPY ["package.json", "yarn.lock", "./"]
RUN yarn install && \
    npm_config_build_from_source=true yarn add --force https://github.com/bldrs-ai/web-ifc-three.git && \
    yarn build

COPY --from=emsdk ["/src/web-ifc/dist/*.wasm", "./web-ifc-three/web-ifc-three/node_modules/web-ifc/"]

COPY . .

FROM node:16-slim AS app

ENV NODE_ENV production

RUN apt-get update && \
    apt-get install -y git mesa-utils xserver-xorg xvfb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder ["/src/package.json", "/src/yarn.lock", "./"]
RUN yarn install --production
COPY --from=builder ["/src/node_modules/canvas", "./node_modules/canvas"]
COPY --from=builder ["/src/node_modules/web-ifc-three", "./node_modules/web-ifc-three"]
COPY --from=builder /src/src ./

EXPOSE 8001
CMD ["xvfb-run", "--error-file=/dev/stderr", "--listen-tcp", "--server-args", "-ac -screen 0 1024x768x24 +extension GLX +render", "node", "server.js"]