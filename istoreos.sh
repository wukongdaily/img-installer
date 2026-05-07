#!/bin/bash
mkdir -p openwrt

INFO="`curl -s "https://fwindex.koolcenter.com/api/fw/device" --data-raw '{"deviceName":"x86_64_efi","firmwareName":"iStoreOS"}' | jq -r ".result.releases[0]"`"
export VERSION="`echo $INFO | jq .release`"
cat "supportFiles/istoreos/info.md" | envsubst '${VERSION}' | tee "supportFiles/istoreos/info.md" > /dev/null
DOWNLOAD_URL="`echo $INFO | jq .url`"
FILE_NAME="${DOWNLOAD_URL##*/}"
OUTPUT_PATH="openwrt/istoreos.img.gz"

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "错误：未找到文件 $FILE_NAME"
  exit 1
fi

echo "下载地址: $DOWNLOAD_URL"
echo "下载文件: $FILE_NAME -> $OUTPUT_PATH"
curl -L -o "$OUTPUT_PATH" "$DOWNLOAD_URL"

if [[ $? -eq 0 ]]; then
  echo "下载istoreos成功!"
  echo "正在解压为:istoreos.img"
  gzip -d openwrt/istoreos.img.gz
  ls -lh openwrt/
  echo "准备合成 istoreos 安装器"
else
  echo "下载失败！"
  exit 1
fi

mkdir -p output
docker run --privileged --rm \
        -v $(pwd)/output:/output \
        -v $(pwd)/supportFiles:/supportFiles:ro \
        -v $(pwd)/openwrt/istoreos.img:/mnt/istoreos.img \
        debian:buster \
        /supportFiles/istoreos/build.sh
