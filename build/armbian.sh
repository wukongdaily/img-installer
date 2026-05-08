#!/bin/bash
mkdir -p _output

# 读取环境变量 (带默认值)
VERSION_TYPE="${VERSION_TYPE:-standard}"
case "$VERSION_TYPE" in
  "debian13_minimal") echo "构建debian13_minimal-armbian..."
    URL="https://dl.armbian.com/uefi-x86/Trixie_current_minimal" ;;
  "ubuntu26_minimal") echo "构建ubuntu26_minimal-armbian..."
    URL="https://dl.armbian.com/uefi-x86/Resolute_current_minimal" ;;
  "homeassistant") echo "构建homeassistant全家桶版armbian..."
    URL="https://dl.armbian.com/uefi-x86/Trixie_current_server-homeassistant" ;;
  *) echo "无效信息"; exit 1 ;;
esac
eval "`curl -sILOJ -w 'DOWNLOAD_URL="%{url_effective}"\nFILE_NAME="%{filename_effective}"\n' "$URL"`"
[ -f "$FILE_NAME" ] && rm "$FILE_NAME"
OUTPUT_PATH="_output/armbian.img.xz"

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "错误：未找到文件 $FILE_NAME"
  exit 1
fi

echo "下载地址: $DOWNLOAD_URL"
echo "下载文件: $FILE_NAME -> $OUTPUT_PATH"
curl -L -o "$OUTPUT_PATH" "$DOWNLOAD_URL"

if [[ $? -eq 0 ]]; then
  echo "下载armbian成功!"
  file _output/armbian.img.xz
  echo "正在解压为:armbian.img"
  xz -d _output/armbian.img.xz
  ls -lh _output/
  echo "准备合成 armbian 安装器"
else
  echo "下载失败！"
  exit 1
fi

mkdir -p output
export GRUB_TITLE="Armbian x86-UEFI Installer [EFI/GRUB]"
export ISOLINUX_TITLE="Armbian Installer"
export DDD_TITLE="Armbian x86-UEFI Installer"
export DDD_SUBTITLE="Armbian x86-UEFI"
export DDD_IMAGE_FILE_NAME="armbian.img"
export DEB_LIVE_BUILD_NAME="armbian"
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