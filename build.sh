#!/bin/bash
mkdir -p armbian

# 读取环境变量 (带默认值)
VERSION_TYPE="${VERSION_TYPE:-standard}"
if [ "$VERSION_TYPE" = "debian13_minimal" ]; then
  echo "构建debian13_minimal-armbian..."
  URL="https://dl.armbian.com/uefi-x86/Trixie_current_minimal"
elif [ "$VERSION_TYPE" = "ubuntu26_minimal" ]; then
  echo "构建ubuntu26_minimal-armbian..." 
  URL="https://dl.armbian.com/uefi-x86/Resolute_current_minimal"
elif [ "$VERSION_TYPE" = "homeassistant" ]; then
  echo "构建homeassistant全家桶版armbian..." 
  URL="https://dl.armbian.com/uefi-x86/Trixie_current_server-homeassistant"
else 
  echo "无效信息"
  exit 1
fi

eval "`curl -sILOJ -w 'DOWNLOAD_URL="%{url_effective}"\nFILE_NAME="%{filename_effective}"\n' "$URL"`"
[ -f "$FILE_NAME" ] && rm "$FILE_NAME"

OUTPUT_PATH="armbian/armbian.img.xz"

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "错误：未找到文件 $FILE_NAME"
  exit 1
fi

echo "下载地址: $DOWNLOAD_URL"
echo "下载文件: $FILE_NAME -> $OUTPUT_PATH"
curl -L -o "$OUTPUT_PATH" "$DOWNLOAD_URL"

if [[ $? -eq 0 ]]; then
  echo "下载armbian成功!"
  file armbian/armbian.img.xz
  echo "正在解压为:armbian.img"
  xz -d armbian/armbian.img.xz
  ls -lh armbian/
  echo "准备合成 armbian 安装器"
else
  echo "下载失败！"
  exit 1
fi

mkdir -p output
docker run --privileged --rm \
        -v $(pwd)/output:/output \
        -v $(pwd)/supportFiles:/supportFiles:ro \
        -v $(pwd)/armbian/armbian.img:/mnt/armbian.img \
        debian:buster \
        /supportFiles/build.sh