#!/bin/bash

# 检查是否以root用户运行
if [ "$EUID" -ne 0 ]; then
  echo "请以root用户运行此脚本。"
  exit 1
fi

# 获取用户输入
read -p "请输入服务器公网IP: " server_ip
read -p "请输入邮件服务器域名 (example.com): " domain_name
read -p "请输入邮件服务器管理员密码 (yourpassword): " password

# 替换docker-compose.yml中的serverip字段
if [ -f docker-compose.yml ]; then
  sed -i "s/serverip/$server_ip/g" docker-compose.yml
else
  echo "docker-compose.yml 文件不存在。"
  exit 1
fi

# 替换mailu.env中的example.com和yourpassword字段
if [ -f mailu.env ]; then
  sed -i "s/example.com/$domain_name/g" mailu.env
  sed -i "s/yourpassword/$password/g" mailu.env
else
  echo "mailu.env 文件不存在。"
  exit 1
fi

# 创建目录结构
echo "项目目录/opt/efdp"
mkdir -p /opt/efdp/mailu/certs
mkdir -p /opt/efdp/gophish/certs

# 处理证书
echo "请选择证书选项："
echo "1. 使用自定义证书"
echo "2. 生成自签名证书"
read -p "请输入选项 (1 或 2): " cert_option

if [ "$cert_option" -eq 1 ]; then
  read -p "请输入自定义证书路径: " cert_path
  read -p "请输入自定义密钥路径: " key_path

  if [ -f "$cert_path" ] && [ -f "$key_path" ]; then
    cp "$cert_path" /opt/efdp/mailu/certs/server.crt
    cp "$key_path" /opt/efdp/mailu/certs/server.key
    cp "$cert_path" /opt/efdp/gophish/certs/server.crt
    cp "$key_path" /opt/efdp/gophish/certs/server.key
  else
    echo "证书或密钥文件不存在。"
    exit 1
  fi

elif [ "$cert_option" -eq 2 ]; then
  # 生成自签名证书
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /opt/efdp/mailu/certs/server.key \
    -out /opt/efdp/mailu/certs/server.crt \
    -subj "/CN=$domain_name"

  cp /opt/efdp/mailu/certs/server.crt /opt/efdp/gophish/certs/server.crt
  cp /opt/efdp/mailu/certs/server.key /opt/efdp/gophish/certs/server.key

else
  echo "无效的选项。"
  exit 1
fi

cp docker-compose.yml /opt/efdp/docker-compose.yml
cp mailu.env /opt/efdp/mailu/mailu.env

echo "安装完成。"