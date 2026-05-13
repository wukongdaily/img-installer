#!/bin/bash
mkdir -p _output

CURL_INFO="`curl "https://fwindex.koolcenter.com/api/fw/device" --data-raw '{"deviceName":"x86_64_efi","firmwareName":"iStoreOS"}' `"
echo curl Result: $CURL_INFO
INFO=`echo $CURL_INFO | jq -r ".result.releases[0]"`
export VERSION="`echo $INFO | jq .release`"
cat "supportFiles/istoreos/info.md.template" | envsubst '${VERSION}' | tee "supportFiles/istoreos/info.md" > /dev/null
DOWNLOAD_URL="`echo $INFO | jq .url`"
FILE_NAME="${DOWNLOAD_URL##*/}"
echo $DOWNLOAD_URL

OUTPUT_PATH="_output/istoreos.img.gz"

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
  gzip -d _output/istoreos.img.gz
  ls -lh _output/
  echo "准备合成 istoreos 安装器"
else
  echo "下载失败！"
  exit 1
fi

mkdir -p output
export GRUB_TITLE="iStoreOS x86-UEFI Installer [EFI/GRUB]"
export ISOLINUX_TITLE="iStoreOS Installer for Virtual Machine"
export DDD_TITLE="iStoreOS Installer for all virtual machine"
export DDD_SUBTITLE="iStoreOS"
export DDD_IMAGE_FILE_NAME="istoreos.img"
export DEB_LIVE_BUILD_NAME="istoreos"
cat "supportFiles/_template/grub.cfg" | envsubst '${GRUB_TITLE}' | tee "supportFiles/$DEB_LIVE_BUILD_NAME/grub.cfg" > /dev/null
cat "supportFiles/_template/isolinux.cfg" | envsubst '${ISOLINUX_TITLE}' | tee "supportFiles/$DEB_LIVE_BUILD_NAME/isolinux.cfg" > /dev/null
cat "supportFiles/_template/ddd" | envsubst '${DDD_TITLE},${DDD_SUBTITLE},${DDD_IMAGE_FILE_NAME}'  | tee "supportFiles/$DEB_LIVE_BUILD_NAME/ddd" > /dev/null
cat "supportFiles/_template/build.sh" | envsubst '${DEB_LIVE_BUILD_NAME}'  | tee "supportFiles/$DEB_LIVE_BUILD_NAME/build.sh" > /dev/null
docker run --privileged --rm \
  -v $(pwd)/output:/output \
  -v $(pwd)/supportFiles:/supportFiles:ro \
  -v $(pwd)/_output/$DDD_IMAGE_FILE_NAME:/mnt/$DDD_IMAGE_FILE_NAME \
  debian:buster \
  /supportFiles/$DEB_LIVE_BUILD_NAME/build.sh
