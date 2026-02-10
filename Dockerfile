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

# --- 第二阶段：运行 (这里有修改) ---
FROM alpine:latest
RUN apk --update --no-cache add curl
# ... (Label 省略，保持原样即可) ...

# 1. 复制二进制文件 (保持不变)
COPY --from=build /out/create-account /usr/bin/create-account
COPY --from=build /out/generate-config /usr/bin/generate-config
COPY --from=build /out/generate-keys /usr/bin/generate-keys
COPY --from=build /out/dendrite /usr/bin/dendrite

# 2. 设置工作目录
VOLUME /etc/dendrite
WORKDIR /etc/dendrite

# 3. ⚠️【新增】把配置文件直接拷进去 (彻底解决找不到文件的问题)
# 确保你的项目根目录下有这两个文件！
COPY dendrite.yaml /etc/dendrite/dendrite.yaml
COPY matrix_key.pem /etc/dendrite/matrix_key.pem

# 4. 设置入口点
ENTRYPOINT ["/usr/bin/dendrite"]

# 5. ⚠️【新增】设置默认参数
# 这样你在 Zeabur 的 Command 里什么都不用填，它自己就能跑
CMD ["-config", "/etc/dendrite/dendrite.yaml", "-http-bind-address", ":8008"]

EXPOSE 8008 8448
