#syntax=docker/dockerfile:1.2

# --- 第一阶段：构建 (保持不变) ---
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

# --- 第二阶段：运行 (关键修改在这里) ---
FROM alpine:latest
RUN apk --update --no-cache add curl

# 1. 复制二进制文件
COPY --from=build /out/create-account /usr/bin/create-account
COPY --from=build /out/generate-config /usr/bin/generate-config
COPY --from=build /out/generate-keys /usr/bin/generate-keys
COPY --from=build /out/dendrite /usr/bin/dendrite

# 2. 设置工作目录
VOLUME /etc/dendrite
WORKDIR /etc/dendrite

# 3. ⚠️【关键修改】自动生成 Key，不再依赖本地文件！
# 这一步保证了 Key 的格式绝对是 Linux 标准的，不会有错。
RUN /usr/bin/generate-keys -private-key /etc/dendrite/matrix_key.pem

# 4. 复制配置文件 (前提是你的仓库里有这个文件)
# 确保你的 dendrite.yaml 里写的 private_key 路径是: /etc/dendrite/matrix_key.pem
COPY dendrite.yaml /etc/dendrite/dendrite.yaml

# 5. 设置启动命令
ENTRYPOINT ["/usr/bin/dendrite"]
CMD ["-config", "/etc/dendrite/dendrite.yaml", "-http-bind-address", ":8008"]

EXPOSE 8008 8448
