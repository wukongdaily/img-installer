#!/bin/bash

REPO="sirpdboy/openwrt"
TAG=$(curl -sL "https://api.github.com/repos/$REPO/releases/latest" | jq -r '.tag_name // empty')
[ -z "$TAG" ] && TAG=$(curl -sL "https://api.github.com/repos/$REPO/tags" | jq -r '.[0].name')
echo "最新TAG: $TAG"
# 获取该 Tag 下所有以 .img.gz 结尾的文件
DOWNLOAD_URLS=$(curl -sL "https://api.github.com/repos/$REPO/releases/tags/$TAG" \
  | jq -r '.assets[] | select(.name | endswith("img.gz")) | .browser_download_url')
# 保存位置
mkdir -p imm
OUTPUT_PATH="imm/ezopwrt.img.gz"

if [ -z "$DOWNLOAD_URLS" ]; then
  echo "Error: No .img.gz files found under tag $TAG"
  exit 1
fi

FIRST_DOWNLOAD_URL=$(echo "$DOWNLOAD_URLS" | head -n1)
echo "下载地址: $FIRST_DOWNLOAD_URL"
curl -L -o "$OUTPUT_PATH" "$FIRST_DOWNLOAD_URL"

if [[ $? -eq 0 ]]; then
  echo "下载ezopwrt成功!"
  file imm/ezopwrt.img.gz
  echo "正在解压为:ezopwrt.img"
  gzip -d imm/ezopwrt.img.gz
  ls -lh imm/
  echo "准备合成 EzOpWrt 安装器"
else
  echo "下载失败！"
  exit 1
fi

mkdir -p output
docker run --privileged --rm \
        -v $(pwd)/output:/output \
        -v $(pwd)/supportFiles:/supportFiles:ro \
        -v $(pwd)/imm/ezopwrt.img:/mnt/ezopwrt.img \
        debian:buster \
        /supportFiles/ezopwrt/build.sh
