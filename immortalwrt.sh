#!/bin/bash
mkdir -p immortalwrt

# DOMAIN 改成 downloads.openwrt.org 就是OpenWrt原版的（
FILE_TYPE="squashfs-combined-efi.img.gz"
DOMAIN="downloads.immortalwrt.org"

export VERSION="`curl -s https://$DOMAIN/.versions.json | jq -r .stable_version`"
if [[ -z "$VERSION" || "$VERSION" == "null" ]]; then
  echo "无法获取版本号"
  exit 1
fi
cat "supportFiles/immortalwrt/info.md.template" | envsubst '${VERSION}' | tee "supportFiles/immortalwrt/info.md" > /dev/null
URL_PREFIX="https://$DOMAIN/releases/$VERSION/targets/x86/64"
FILE_NAME="`curl -s $URL_PREFIX/profiles.json | jq -r --arg type "$FILE_TYPE" \
   '.profiles.generic.images[] | select(.name | contains($type)) | .name'`"
DOWNLOAD_URL="$URL_PREFIX/$FILE_NAME"
OUTPUT_PATH="immortalwrt/immortalwrt.img.gz"

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "错误：未找到文件 $FILE_NAME"
  exit 1
fi

echo "下载地址: $DOWNLOAD_URL"
echo "下载文件: $FILE_NAME -> $OUTPUT_PATH"
curl -L -o "$OUTPUT_PATH" "$DOWNLOAD_URL"

if [[ $? -eq 0 ]]; then
  echo "下载immortalwrt-24.10.1成功!"
  file immortalwrt/immortalwrt.img.gz
  echo "正在解压为:immortalwrt.img"
  gzip -d immortalwrt/immortalwrt.img.gz
  ls -lh immortalwrt/
  echo "准备合成 immortalwrt 安装器"
else
  echo "下载失败！"
  exit 1
fi

mkdir -p output
docker run --privileged --rm \
        -v $(pwd)/output:/output \
        -v $(pwd)/supportFiles:/supportFiles:ro \
        -v $(pwd)/immortalwrt/immortalwrt.img:/mnt/immortalwrt.img \
        debian:buster \
        /supportFiles/immortalwrt/build.sh
