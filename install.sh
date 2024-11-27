#!/bin/bash

# 检查是否以root用户运行
[ "$EUID" -ne 0 ] && { echo "请以root用户运行此脚本。"; exit 1; }

# 检查必需程序是否安装
for cmd in docker openssl; do
  command -v $cmd &> /dev/null || { echo "$cmd 未安装，请先安装 $cmd。"; exit 1; }
done

# 获取用户输入并验证
read -p "请输入服务器公网IP(或0.0.0.0): " server_ip
[[ ! $server_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && { echo "无效的IP地址。"; exit 1; }

read -p "请输入邮件服务器根域名 (example.com): " domain_name
[[ ! $domain_name =~ ^[a-zA-Z0-9.-]+$ ]] && { echo "无效的域名。"; exit 1; }

read -p "请输入邮件服务器管理员密码: " mailpassword
read -p "请输入GoPhish服务器管理员密码: " gppassword

# 检查配置文件是否存在
for file in docker-compose.yml mailu.env gophish.db gophish_config.json; do
  [ ! -f $file ] && { echo "$file 文件不存在。"; exit 1; }
done


# 所有检查通过后，开始执行操作

# 创建目录结构
echo "创建项目目录 /opt/efdp.."
mkdir -p /opt/efdp/{mailu/certs,gophish/certs}

# 替换配置文件内容
echo "配置文件修改.."
sed -i "s/serverip/$server_ip/g" docker-compose.yml
sed -i "s/gppassword/$gppassword/g" docker-compose.yml
sed -i "s/example.com/$domain_name/g" mailu.env
sed -i "s/yourpassword/$mailpassword/g" mailu.env

# 处理邮服证书
echo "处理邮件服务器证书.."
echo "请选择邮件服务器证书选项："
echo "1. 使用自定义证书(efdp.example.com)"
echo "2. 生成自签名证书(efdp.example.com)"
read -p "请输入选项 (1 或 2): " mailcert_option

if [ "$mailcert_option" -eq 1 ]; then
  read -p "请输入自定义证书路径 (crt或pem格式): " mailcert_path
  read -p "请输入自定义密钥路径 (key或pem格式): " mailkey_path

  for file in "$mailcert_path" "$mailkey_path"; do
    [ ! -f "$file" ] && { echo "证书或密钥文件不存在。"; exit 1; }
  done

  cp "$mailcert_path" /opt/efdp/mailu/certs/cert.pem
  cp "$mailkey_path" /opt/efdp/mailu/certs/key.pem

elif [ "$mailcert_option" -eq 2 ]; then
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /opt/efdp/mailu/certs/key.pem \
    -out /opt/efdp/mailu/certs/cert.pem \
    -subj "/CN=efdp.$domain_name"
    
  echo "已生成efdp.$domain_name 邮件服务器域名证书"
else
  echo "无效的选项。"
  exit 1
fi

## 处理gophish证书
echo "处理gophish服务器证书.."
read -p "gophish钓鱼页是否使用HTTPS? (Y/N): " -r gptls

if [[ "$gptls" =~ ^[Yy]$ ]]; then
  echo "钓鱼网页使用HTTPS协议"
  echo "1. 使用自定义证书"
  echo "2. 生成自签名证书"
  read -p "请选择邮件服务器证书选项: (1 或 2): " gpcert_option

  if [[ "$gpcert_option" == "1" ]]; then
    read -p "请输入自定义证书路径 (crt或pem格式): " gpcert_path
    read -p "请输入自定义密钥路径 (key或pem格式): " gpkey_path

    for file in "$gpcert_path" "$gpkey_path"; do
      [ ! -f "$file" ] && { echo "$file 不存在。"; exit 1; }
    done

    cp "$gpcert_path" /opt/efdp/gophish/certs/server.crt
    cp "$gpkey_path" /opt/efdp/gophish/certs/server.key  

  elif [[ "$gpcert_option" == "2" ]]; then
    read -p "请输入钓鱼网页域名: " gpdomain
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /opt/efdp/gophish/certs/server.key \
    -out /opt/efdp/gophish/certs/server.crt \
    -subj "/CN=$gpdomain"
    
    echo "已生成$gpdomain gophish钓鱼网页域名证书"
  else
    echo "无效的选项。"
    exit 1
  fi
elif [[ "$gptls" =~ ^[Nn]$ ]]; then
  echo "钓鱼网页不使用HTTPS协议"
  sed -i 's/\"use_tls\": true/\"use_tls\": false/g' gophish_config.json
else
  echo "无效输入，请键入 Y 或 N"
  exit 1
fi


# 复制配置文件到目标目录
cp docker-compose.yml /opt/efdp/docker-compose.yml
cp gophish.db /opt/efdp/gophish/gophish.db
chmod 666 gophish_config.json
cp gophish_config.json /opt/efdp/gophish/config.json
cp mailu.env /opt/efdp/mailu/mailu.env

#chmod -R 666 /opt/efdp/{mailu,gophish}/

echo "安装完成。"
echo "- 在/opt/efdp目录下使用docker compose up -d启动。"
echo "- 请在防火墙上开启以下端口："
echo "  8088,4433,25,465,587,110,995,143,993,4190,3333,80,443,8080"
echo "- *请确保25端口开放能给收发邮箱"
echo "- mailu邮件服务器后台(http为8088端口)：https://$server_ip:4433/或https://efdp.$domain_name:4433"
echo "  管理员凭证为：admin/$mailpassword"
echo "- gophish后台：http://$server_ip:3333，钓鱼网页为80/443端口"
echo "  管理员凭证为：admin/$gppassword"
