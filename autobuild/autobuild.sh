#!/bin/bash
# 接受从AutoBuildImmortalWrt Action 过来的固件 制作为ISO
mkdir -p imm
RECEIVE_FILE="$1"
filename=$(basename "$RECEIVE_FILE")  # 提取文件名
OUTPUT_PATH="imm/$filename"
mv $RECEIVE_FILE $OUTPUT_PATH
echo "保存路径: $OUTPUT_PATH"
echo "✅ 验证文件类型!"
file "$OUTPUT_PATH"

# 根据扩展名解压
extension="${filename##*.}"  # 获取文件扩展名
case $extension in
  gz)
    echo "gz正在解压$OUTPUT_PATH"
    gunzip -f "$OUTPUT_PATH" || true
    final_name=$(find imm -name '*.img' -print -quit)
    mv "$final_name" "imm/custom.img"
    ;;
  zip)
    echo "zip正在解压$OUTPUT_PATH"
    unzip -j -o "$OUTPUT_PATH" -d imm/  # -j 忽略目录结构 
    final_name=$(find imm -name '*.img' -print -quit)
    mv "$final_name" "imm/custom.img"
    ;;
  xz)
    echo "xz正在解压$OUTPUT_PATH"
    xz -d --keep "$OUTPUT_PATH"  # 保留原文件 
    final_name="${OUTPUT_PATH%.*}"
    mv "$final_name" "imm/custom.img"
    ;;
  *)
    echo "❌ 不支持的压缩格式: $extension"
    exit 1
    ;;
esac


# 检查最终文件
if [ -f "imm/custom.img" ]; then
  echo "✅ 解压成功"
  ls -lh imm/
  echo "✅ 准备合成 自定义OpenWrt 安装器"
else
  echo "❌ 错误：最终文件 imm/custom.img 不存在"
  exit 1
fi

mkdir -p output
docker run --privileged --rm \
    -v $(pwd)/output:/output \
    -v $(pwd)/supportFiles:/supportFiles:ro \
    -v $(pwd)/imm/custom.img:/mnt/custom.img \
    debian:buster \
    /supportFiles/custom/build.sh
