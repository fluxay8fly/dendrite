# 1. 使用国内镜像源拉取官方【成品】 (跳过漫长的编译过程)
FROM matrixdotorg/dendrite-monolith:latest

# 2. 建立一个专门放配置的目录 (避开 /etc/dendrite 那个挂载卷)
WORKDIR /dendrite-config

# 3. 复制你的配置文件到这个新目录
# (确保你本地确实有 dendrite.yaml 这个文件)
COPY dendrite.yaml /dendrite-config/dendrite.yaml

# 4. 生成 Key 到这个新目录
RUN /usr/bin/generate-keys -private-key /dendrite-config/matrix_key.pem

# 5. ⚠️ 修正 dendrite.yaml 里的 Key 路径 (用 sed 命令自动改，省得你手动改错)
# 这一步会自动把你配置文件里的 private_key: ... 改成指向 /dendrite-config/matrix_key.pem
RUN sed -i 's|private_key: .*|private_key: /dendrite-config/matrix_key.pem|g' /dendrite-config/dendrite.yaml

# 6. 准备数据目录 (这个目录给 Zeabur 挂载 Volume 用，只存数据，不存配置)
VOLUME /etc/dendrite

# 7. 启动命令
# ⚠️ 注意：这里指向了正确的 /dendrite-config/ 目录
ENTRYPOINT ["/usr/bin/dendrite"]
CMD ["-config", "/dendrite-config/dendrite.yaml", "-http-bind-address", ":8008", "-really-enable-open-registration"]
