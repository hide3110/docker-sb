#!/bin/sh

# sing-box 一键安装脚本
# 适用于 Debian/Ubuntu 和 Alpine 系统
# 兼容 bash 和 ash

set -e

# 默认配置变量
AL_PORTS=${AL_PORTS:-"64031-64036"}
RE_PORT=${RE_PORT:-"443"}
AL_DOMAIN=${AL_DOMAIN:-"us01.yyds.nyc.mn"}
RE_SNI=${RE_SNI:-"www.cityofrc.us"}
SB_VER=${SB_VER:-"v1.11.15"}

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检测系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    elif [ -f /etc/alpine-release ]; then
        OS="alpine"
    else
        log_error "无法检测系统类型"
        exit 1
    fi
    log_info "检测到系统: $OS"
}

# 检查 Docker 是否已安装
check_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker 已安装: $(docker --version)"
        return 0
    else
        log_warn "Docker 未安装"
        return 1
    fi
}

# 检查 Docker Compose 是否已安装
check_docker_compose() {
    if docker compose version &> /dev/null; then
        log_info "Docker Compose 已安装: $(docker compose version)"
        return 0
    elif command -v docker-compose &> /dev/null; then
        log_info "Docker Compose 已安装: $(docker-compose --version)"
        return 0
    else
        log_warn "Docker Compose 未安装"
        return 1
    fi
}

# 安装 Docker (Debian/Ubuntu)
install_docker_debian() {
    log_info "开始安装 Docker (Debian/Ubuntu)..."
    curl -fsSL https://get.docker.com | bash -s docker
    
    # 启动 Docker
    systemctl enable docker
    systemctl start docker
    
    log_info "Docker 安装完成"
}

# 安装 Docker (Alpine)
install_docker_alpine() {
    log_info "开始安装 Docker (Alpine)..."
    apk add docker docker-cli-compose
    
    # 启动 Docker
    rc-update add docker boot
    service docker start
    
    log_info "Docker 安装完成"
}

# 安装 Docker
install_docker() {
    case $OS in
        ubuntu|debian)
            install_docker_debian
            ;;
        alpine)
            install_docker_alpine
            ;;
        *)
            log_error "不支持的系统类型: $OS"
            exit 1
            ;;
    esac
}

# 解析端口范围
parse_ports() {
    if [[ $AL_PORTS =~ ^([0-9]+)-([0-9]+)$ ]]; then
        PORT_START=${BASH_REMATCH[1]}
        PORT_END=${BASH_REMATCH[2]}
        
        PORT_SS=$PORT_START
        PORT_TROJAN=$((PORT_START + 1))
        PORT_VMESS=$((PORT_START + 2))
        PORT_VLESS=$((PORT_START + 3))
        PORT_TUIC=$((PORT_START + 4))
        PORT_HYSTERIA2=$((PORT_START + 5))
    else
        log_error "端口范围格式错误，应为: 开始端口-结束端口 (如: 64031-64036)"
        exit 1
    fi
}

# 创建目录结构
create_directories() {
    log_info "创建目录结构..."
    mkdir -p /opt/sing-box/config
    mkdir -p /opt/sing-box/data
    log_info "目录创建完成: /opt/sing-box"
}

# 创建 docker-compose.yml
create_docker_compose() {
    log_info "创建 docker-compose.yml..."
    log_info "使用 sing-box 版本: $SB_VER"
    cat > /opt/sing-box/docker-compose.yml << EOF
services:
  sing-box:
    image: ghcr.io/sagernet/sing-box:$SB_VER
    container_name: sing-box
    restart: unless-stopped
    network_mode: host
    cap_add:
      - NET_ADMIN
    volumes:
      - ./config:/etc/sing-box/
      - ./data:/var/lib/sing-box/
    command: -D /var/lib/sing-box -C /etc/sing-box/ run
EOF
    log_info "docker-compose.yml 创建完成"
}

# 创建 config.json
create_config() {
    log_info "创建 config.json..."
    log_info "使用端口配置: SS=$PORT_SS, Trojan=$PORT_TROJAN, VMess=$PORT_VMESS, VLESS=$PORT_VLESS, TUIC=$PORT_TUIC, Hysteria2=$PORT_HYSTERIA2, Reality=$RE_PORT"
    log_info "使用域名: $AL_DOMAIN, Reality SNI: $RE_SNI"
    
    cat > /opt/sing-box/config/config.json << EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "shadowsocks",
      "tag": "ss-in",
      "listen": "::",
      "listen_port": $PORT_SS,
      "method": "aes-128-gcm",
      "password": "L3vCBgE7nSUlHQcV0D9qYA=="
    },
    {
      "type": "trojan",
      "tag": "trojan-in",
      "listen": "::",
      "listen_port": $PORT_TROJAN,
      "users": [
        {
          "password": "hBh1uKxMhYr6yTc40MDIcg=="
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$AL_DOMAIN",
        "alpn": [
          "h2",
          "http/1.1"
        ],
        "acme": {
          "domain": "$AL_DOMAIN",
          "data_directory": "acme",
          "email": "yyds88@gmail.com"
        }
      }
    },
    {
      "type": "vmess",
      "tag": "vmess-wss-in",
      "listen": "::",
      "listen_port": $PORT_VMESS,
      "users": [
        {
          "uuid": "25ec3523-5bbc-4cbf-b946-879941af55ab",
          "alterId": 0
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$AL_DOMAIN",
        "alpn": [
          "h2",
          "http/1.1"
        ],
        "acme": {
          "domain": "$AL_DOMAIN",
          "data_directory": "acme",
          "email": "yyds88@gmail.com"
        }
      },
      "transport": {
        "type": "ws",
        "path": "/02ad194e"
      }
    },
    {
      "type": "vless",
      "tag": "vless-wss-in",
      "listen": "::",
      "listen_port": $PORT_VLESS,
      "users": [
        {
          "uuid": "43a1f08a-d9ff-4aea-ac8a-cc622caf62a5"
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/42af2c6b"
      },
      "tls": {
        "enabled": true,
        "server_name": "$AL_DOMAIN",
        "alpn": [
          "h2",
          "http/1.1"
        ],
        "acme": {
          "domain": "$AL_DOMAIN",
          "data_directory": "acme",
          "email": "yyds88@gmail.com"
        }
      },
      "multiplex": {
        "enabled": true
      }
    },
    {
      "type": "tuic",
      "tag": "tuic-in",
      "listen": "::",
      "listen_port": $PORT_TUIC,
      "users": [
        {
          "uuid": "47013aa0-b699-4468-b6e4-56250573f3ab",
          "password": "Ro060jU4fghfvTpHxiDQyA=="
        }
      ],
      "congestion_control": "bbr",
      "tls": {
        "enabled": true,
        "server_name": "$AL_DOMAIN",
        "alpn": [
          "h3"
        ],
        "acme": {
          "domain": "$AL_DOMAIN",
          "data_directory": "acme",
          "email": "yyds88@gmail.com"
        }
      }
    },
    {
      "type": "hysteria2",
      "tag": "hysteria2-in",
      "listen": "::",
      "listen_port": $PORT_HYSTERIA2,
      "users": [
        {
          "password": "yK9VdaPrUZ5iZRLpv0ZNow=="
        }
      ],
      "ignore_client_bandwidth": false,
      "tls": {
        "enabled": true,
        "server_name": "$AL_DOMAIN",
        "alpn": [
          "h3"
        ],
        "acme": {
          "domain": "$AL_DOMAIN",
          "data_directory": "acme",
          "email": "yyds88@gmail.com"
        }
      }
    },
    {
      "type": "vless",
      "tag": "real-in",
      "listen": "::",
      "listen_port": $RE_PORT,
      "users": [
        {
          "uuid": "43a1f08a-d9ff-4aea-ac8a-cc622caf62a5",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$RE_SNI",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$RE_SNI",
            "server_port": 443
          },
          "private_key": "IJ7MvrtAgMGCJdLk4JHtaRci5uAIa2SD5aNO0hsNJ2U",
          "short_id": [
            "4eae9cfd38fb5a8d"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF
    log_info "config.json 创建完成"
}

# 启动容器
start_container() {
    log_info "启动 sing-box 容器..."
    cd /opt/sing-box
    docker compose up -d
    log_info "sing-box 容器已启动"
}

# 显示状态
show_status() {
    echo ""
    log_info "========================================"
    log_info "sing-box 安装完成！"
    log_info "========================================"
    echo ""
    log_info "配置信息:"
    log_info "  - sing-box 版本: $SB_VER"
    log_info "  - Shadowsocks 端口: $PORT_SS"
    log_info "  - Trojan 端口: $PORT_TROJAN"
    log_info "  - VMess 端口: $PORT_VMESS"
    log_info "  - VLESS 端口: $PORT_VLESS"
    log_info "  - TUIC 端口: $PORT_TUIC"
    log_info "  - Hysteria2 端口: $PORT_HYSTERIA2"
    log_info "  - Reality 端口: $RE_PORT"
    log_info "  - ACME 域名: $AL_DOMAIN"
    log_info "  - Reality SNI: $RE_SNI"
    echo ""
    log_info "常用命令:"
    log_info "  - 查看日志: docker logs -f sing-box"
    log_info "  - 停止容器: cd /opt/sing-box && docker compose down"
    log_info "  - 重启容器: cd /opt/sing-box && docker compose restart"
    log_info "  - 查看状态: docker ps | grep sing-box"
    echo ""
}

# 主函数
main() {
    echo ""
    log_info "========================================"
    log_info "sing-box 一键安装脚本"
    log_info "========================================"
    echo ""
    
    # 检测系统
    detect_os
    
    # 检查 Docker
    if ! check_docker; then
        log_info "准备安装 Docker..."
        install_docker
    fi
    
    # 检查 Docker Compose
    if ! check_docker_compose; then
        log_error "Docker Compose 未安装，但应该随 Docker 一起安装"
        exit 1
    fi
    
    # 解析端口
    parse_ports
    
    # 创建目录和文件
    create_directories
    create_docker_compose
    create_config
    
    # 启动容器
    start_container
    
    # 显示状态
    show_status
}

# 运行主函数
main
