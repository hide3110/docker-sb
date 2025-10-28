# sing-box docker安装脚本

此脚本可以帮助你在 Debian/Ubuntu 和 Alpine 系统通过 docker 快速部署 sing-box 代理服务器。

### 通过一键脚本自定义安装
自定义端口参数如：AL_PORTS=8443-8447 (也可用 AL_PORTS=8443,8444,8445,8446,8447 来表达) RE_PORT=443 (此为reality端口，注意端口占用问题) AL_DOMAIN=my.domain.com (服务器解析的域名) RE_SNI=www.java.com (此为reality协议证书地址)，使用时请自行定义此参数！
```bash
AL_PORTS=8443-8447 RE_PORT=443 AL_DOMAIN=my.domain.com RE_SNI=www.java.com bash <(curl -fsSL https://raw.githubusercontent.com/hide3110/docker-sb/main/install.sh)
```
### 安装指定版本号
可以在脚本前添加SB_VER变量，如SB_VER=v1.12.0
```
SB_VER=v1.12.0 AL_PORTS=8443-8447 RE_PORT=443 AL_DOMAIN=my.domain.com RE_SNI=www.java.com bash <(curl -fsSL https://raw.githubusercontent.com/hide3110/docker-sb/main/install.sh)
```

## 详细说明
- docker相关文件路径：/opt/sing-box
- 脚本使用的acme申请证书
- 默认安装sing-box 1.11.15版本，可自定版本安装，需要自行修改配置文件
- 此脚本仅安装了ss、trojan、vmess、vless、tuic、hystaria2和reality七个协议
