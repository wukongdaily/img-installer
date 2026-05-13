#!/bin/bash
set -euo pipefail  

# 校验参数是否存在
if [ -z "$1" ]; then
  echo "❌ 错误：未提供下载地址！"
  exit 1
fi

mkdir -p _output
DOWNLOAD_URL="$1"
filename=$(basename "$DOWNLOAD_URL")  # 从 URL 提取文件名
OUTPUT_PATH="_output/$filename"

echo "下载地址: $DOWNLOAD_URL"
echo "保存路径: $OUTPUT_PATH"

# 下载文件
if ! curl -k -L -o "$OUTPUT_PATH" "$DOWNLOAD_URL"; then
  echo "❌ 下载失败！"
  exit 1
fi

echo "✅ 下载成功!"
file "$OUTPUT_PATH"

# 根据扩展名解压
extension="${filename##*.}"  # 获取文件扩展名
case $extension in
  gz)
    echo "gz正在解压$OUTPUT_PATH"
    gunzip -f "$OUTPUT_PATH" || true
    final_name=$(find _output -name '*.img' -print -quit)
    mv "$final_name" "_output/custom.img"
    ;;
  zip)
    echo "zip正在解压$OUTPUT_PATH"
    unzip -j -o "$OUTPUT_PATH" -d _output/  # -j 忽略目录结构 
    final_name=$(find _output -name '*.img' -print -quit)
    mv "$final_name" "_output/custom.img"
    ;;
  xz)
    echo "xz正在解压$OUTPUT_PATH"
    xz -d --keep "$OUTPUT_PATH"  # 保留原文件 
    final_name="${OUTPUT_PATH%.*}"
    mv "$final_name" "_output/custom.img"
    ;;
  *)
    echo "❌ 不支持的压缩格式: $extension"
    exit 1
    ;;
esac


# 检查最终文件
if [ -f "_output/custom.img" ]; then
  echo "✅ 解压成功"
  ls -lh _output/
  echo "✅ 准备合成 自定义OpenWrt 安装器"
else
  echo "❌ 错误：最终文件 _output/custom.img 不存在"
  exit 1
fi

mkdir -p output
GRUB_TITLE="Custom OpenWrt x86-UEFI Installer [EFI/GRUB]"
ISOLINUX_TITLE="Custom OpenWrt Installer"
export DDD_TITLE="Custom OpenWrt Installer"
export DDD_SUBTITLE="Custom OpenWrt"
export DDD_IMAGE_FILE_NAME="custom.img"
export DEB_LIVE_BUILD_NAME="custom"
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
