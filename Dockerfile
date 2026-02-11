#syntax=docker/dockerfile:1.2

# --- 第一阶段：构建 ---
FROM --platform=${BUILDPLATFORM} docker.io/golang:1.22-alpine AS base
RUN apk --update --no-cache add bash build-base curl git

FROM --platform=${BUILDPLATFORM} base AS build
WORKDIR /src
ARG TARGETOS
ARG TARGETARCH
RUN --mount=target=. \
    --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    USERARCH=`go env GOARCH` \
    GOARCH="$TARGETARCH" \
    GOOS="linux" \
    CGO_ENABLED=$([ "$TARGETARCH" = "$USERARCH" ] && echo "1" || echo "0") \
    go build -v -trimpath -o /out/ ./cmd/...

# --- 第二阶段：运行 ---
FROM alpine:latest
RUN apk --update --no-cache add curl

# 复制二进制
COPY --from=build /out/create-account /usr/bin/create-account
COPY --from=build /out/generate-config /usr/bin/generate-config
COPY --from=build /out/generate-keys /usr/bin/generate-keys
COPY --from=build /out/dendrite /usr/bin/dendrite

# 1. 创建并设置一个【不挂载卷】的配置目录
WORKDIR /dendrite-config

# 2. 在这里生成 Key (绝对安全，不会被覆盖)
RUN /usr/bin/generate-keys -private-key /dendrite-config/matrix_key.pem

# 3. 复制配置文件到这里
COPY dendrite.yaml /dendrite-config/dendrite.yaml

# 4. 准备数据目录 (这个目录给 Zeabur 挂载 Volume 用)
RUN mkdir -p /etc/dendrite
VOLUME /etc/dendrite

# 5. 启动命令指向新的配置路径
ENTRYPOINT ["/usr/bin/dendrite"]
CMD ["-config", "/dendrite-config/dendrite.yaml", "-http-bind-address", ":8008"]

EXPOSE 8008 8448
