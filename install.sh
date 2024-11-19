#!/bin/bash

# 检查是否以root用户运行
if [ "$EUID" -ne 0 ]; then
  echo "请以root用户运行此脚本。"
  exit 1
fi

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
  echo "Docker未安装，请先安装Docker。"
  exit 1
fi

# 获取用户输入并验证
read -p "请输入服务器公网IP: " server_ip
if [[ ! $server_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "无效的IP地址。"
  exit 1
fi

read -p "请输入邮件服务器域名 (example.com): " domain_name
if [[ ! $domain_name =~ ^[a-zA-Z0-9.-]+$ ]]; then
  echo "无效的域名。"
  exit 1
fi

read -p "请输入邮件服务器管理员密码: " password
echo
read -p "请输入GoPhish服务器管理员密码: " gppassword
echo

# 检查配置文件是否存在
if [ ! -f docker-compose.yml ]; then
  echo "docker-compose.yml 文件不存在。"
  exit 1
fi

if [ ! -f mailu.env ]; then
  echo "mailu.env 文件不存在。"
  exit 1
fi

if [ ! -f gophish.db ]; then
  echo "gophish.db 文件不存在。"
  exit 1
fi

if [ ! -f gophish_config.json ]; then
  echo "gophish_config.json 文件不存在。"
  exit 1
fi

# 处理证书选项
echo "请选择证书选项："
echo "1. 使用自定义证书"
echo "2. 生成自签名证书"
read -p "请输入选项 (1 或 2): " cert_option

if [ "$cert_option" -eq 1 ]; then
  read -p "请输入自定义证书路径 (crt或pem格式): " cert_path
  read -p "请输入自定义密钥路径 (key或pem格式): " key_path

  if [ ! -f "$cert_path" ] || [ ! -f "$key_path" ]; then
    echo "证书或密钥文件不存在。"
    exit 1
  fi

elif [ "$cert_option" -eq 2 ]; then
  # 检查OpenSSL是否安装
  if ! command -v openssl &> /dev/null; then
    echo "OpenSSL未安装，请先安装OpenSSL。"
    exit 1
  fi
else
  echo "无效的选项。"
  exit 1
fi

# 所有检查通过后，开始执行操作

# 创建目录结构
echo "创建项目目录 /opt/efdp"
mkdir -p /opt/efdp/mailu/certs
mkdir -p /opt/efdp/gophish/certs

# 替换配置文件内容
sed -i "s/serverip/$server_ip/g" docker-compose.yml
sed -i "s/gppassword/$gppassword/g" docker-compose.yml
sed -i "s/example.com/$domain_name/g" mailu.env
sed -i "s/yourpassword/$password/g" mailu.env

# 处理证书
if [ "$cert_option" -eq 1 ]; then
  cp "$cert_path" /opt/efdp/mailu/certs/cert.pem
  cp "$key_path" /opt/efdp/mailu/certs/key.pem
  cp "$cert_path" /opt/efdp/gophish/certs/server.crt
  cp "$key_path" /opt/efdp/gophish/certs/server.key
elif [ "$cert_option" -eq 2 ]; then
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /opt/efdp/mailu/certs/key.pem \
    -out /opt/efdp/mailu/certs/cert.pem \
    -subj "/CN=$domain_name"

  cp /opt/efdp/mailu/certs/cert.pem /opt/efdp/gophish/certs/server.crt
  cp /opt/efdp/mailu/certs/key.pem /opt/efdp/gophish/certs/server.key
fi

# 复制配置文件到目标目录
cp docker-compose.yml /opt/efdp/docker-compose.yml
cp gophish.db /opt/efdp/gophish/gophish.db
cp gophish_config.json /opt/efdp/gophish/config.json
cp mailu.env /opt/efdp/mailu/mailu.env

echo "安装完成。"
echo "请在防火墙上开启以下端口："
echo "8088,4433,25,465,587,110,995,143,993,4190,3333,80,443,8080"
echo "在/opt/efdp目录下使用docker compose up -d启动。"
echo "mailu邮件服务器后台为8088/4433(tls)端口，gophish后台为3333端口，钓鱼页面为80/443端口"
echo "*请确保25端口开放能给收发邮箱"