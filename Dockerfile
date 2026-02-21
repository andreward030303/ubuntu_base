# ベースイメージ
FROM ubuntu:24.04

# 対話モード防止
ENV DEBIAN_FRONTEND=noninteractive

# タイムゾーン設定（Asia/Tokyo）
RUN ln -fs /usr/share/zoneinfo/Asia/Tokyo /etc/localtime && \
    apt update -y && \
    apt install -y git vim tzdata && \
    dpkg-reconfigure --frontend noninteractive tzdata && \
    apt clean && rm -rf /var/lib/apt/lists/*

RUN echo "alias dotfiles='git clone https://github.com/andreward030303/dotfiles.git'" >> /root/.bashrc

WORKDIR /home
