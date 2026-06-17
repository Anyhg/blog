---
title: "Docker 核心速查手册"
date: 2026-06-17T00:00:00+08:00
draft: false
tags: ["Docker", "容器", "速查"]
categories: ["技术笔记"]
summary: "Docker 常用配置、镜像、容器生命周期、调试、网络、存储与 Compose 速查。"
---


## 系统配置与环境

拉取镜像慢时，必须配置镜像加速器。

```Shell
# 1. 编辑配置文件
sudo vi /etc/docker/daemon.json

# 2. 填入镜像源配置 (按 i 进入编辑，完成后按 ESC，输入 :wq 保存退出)
{
    "registry-mirrors": [
        "https://docker.m.daocloud.io",
        "https://docker.1panel.live",
        "https://hub.rat.dev"
    ]
}

# 3. 重启 Docker 服务使配置生效
sudo service docker restart 

# 查看 Docker 系统信息 (可用于验证镜像源是否生效)
docker info
```

## 一、 镜像管理 (Images)

镜像是静态的安装包，是启动容器的基础。

```Shell
docker images                                       # 查看本地所有镜像
docker pull [registry/][username/]name:version      # 从仓库拉取镜像 (默认拉取 latest 最新版)
docker pull --platform=linux/arm64 nginx            # 补充：指定 CPU 架构拉取镜像 (M芯片 Mac 常用)
docker rmi <镜像名或ID>                             # 删除单个镜像
docker image prune -a                               # 补充：一键清理所有未被使用的镜像 (释放磁盘空间神器)
```

## 二、 容器生命周期管理 (Containers)

容器是运行起来的镜像。这是日常使用最高频的部分。

### 1. 启动容器 (`docker run`)

`docker run` = 创建 (`create`) + 启动 (`start`)。它的参数非常多，建议分类记忆：

```Shell
docker run [参数] <镜像名> [启动命令]

# --- 常用参数对照表 ---
# -d                  后台运行容器 (最常用)
# --name <名字>       给容器取个自定义好记的名字
# -p <外>:<内>        端口映射。例如 -p 8080:80 (将宿主机的 8080 端口映射到容器内的 80)
# -e <Key>=<Value>    设置环境变量。例如 -e MYSQL_ROOT_PASSWORD=123456
# --restart <策略>    重启策略：
#                     ↳ always: 无论如何退出都自动重启 (哪怕开机重启也会拉起)
#                     ↳ unless-stopped: 手动停止的不重启，意外退出的才重启
# -it                 分配交互式终端并保持输入打开 (进容器内部必备)
# --rm                用完即焚 (容器停掉后立即自动删除，常用于临时测试)
```

**👉 经典组合示例：**

- **启动常驻服务：** `docker run -d --name my_nginx -p 80:80 --restart always nginx`
- **启动临时测试环境：** `docker run -it --rm alpine /bin/sh` (退出立刻销毁)

### 2. 状态查看与基础操作

```Shell
docker ps               # 查看正在运行的容器
docker ps -a            # 查看所有容器 (包含已停止的、运行报错退出的)
docker stop <容器ID/名>  # 优雅停止容器
docker start <容器ID/名> # 重新启动已停止的容器
docker rm <容器ID/名>    # 删除已停止的容器
docker rm -f <容器ID/名> # 补充：强制删除正在运行的容器
```

## 三、 容器交互与调试 (Debug)

当容器跑起来但行为不对时，用这组命令去“诊断”。

```Shell
docker logs <容器ID/名>            # 查看容器吐出的日志
docker logs -f <容器ID/名>         # 实时滚动追踪日志 (类似 tail -f)
docker inspect <容器ID/名>         # 查看容器的详细信息 (JSON 格式，看网络 IP、挂载路径等)

# --- 进入运行中的容器内部 ---
# 格式：docker exec [参数] <容器> <命令>
docker exec -it <容器ID/名> /bin/sh  # 进入容器并打开 Shell 交互终端 (最常用)
docker exec <容器ID/名> ps -ef       # 不进入容器，仅仅是让容器执行个命令就把结果返回给你
```

## 四、 数据持久化 (Volumes & Mounts)

容器删除了，数据不能丢。Docker 有两种挂载数据的方式：

### 方式 1：绑定挂载 (Bind Mounts) —— 适合开发写代码

直接把宿主机（你的电脑）上的具体目录，强行覆盖映射到容器里。

- **语法：** `-v <宿主机绝对路径>:<容器内路径>`
- **示例：** `docker run -d -p 80:80 -v /Users/freedom/Downloads/html:/usr/share/nginx/html nginx`

### 方式 2：具名卷 (Named Volumes) —— 适合数据库存数据

由 Docker 全权管理的数据卷，你不必关心它实际存在宿主机的哪个深层目录里。

```Shell
docker volume create nginx_html     # 创建一个卷
docker volume ls                    # 查看已创建的卷列表
docker volume inspect nginx_html    # 查看该卷的详细信息 (含真实存储路径)
docker volume rm nginx_html         # 删除特定卷
docker volume prune                 # 删除所有未被任何容器使用的卷

# 使用卷启动容器示例：
docker run -d -v nginx_html:/usr/share/nginx/html nginx
```

## 五、 网络管理 (Networks)

控制容器之间、容器与宿主机之间的网络通信。

```Shell
docker network create network1      # 创建一个自定义的子网网络
docker network ls                   # 补充：查看本机所有 Docker 网络

# --- 启动时的网络参数 ---
# --network <子网名>    将容器加入指定的子网 (同子网内的容器，可以直接用容器名字互相 ping 通！)
# --network none        完全隔离，不给容器分配网络
# --network host        直接使用宿主机网络启动容器。 
#                       ⚠️ 避坑：仅限 Linux 系统生效！在 Mac 和 Windows 的 Docker Desktop 上无效！
```

## 六、 容器编排 (Docker Compose)

解决**多容器联合部署**的痛点（如 Nginx + SpringBoot + MySQL + Redis）。用 YAML 文件代替冗长难记的 `docker run` 命令。

### 1. 核心配置文件 (`docker-compose.yml`) 示例

```YAML
version: '3.8'

services:
  # 服务一：数据库
  db:
    image: mysql:8.0
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: my_secret_password
      MYSQL_DATABASE: wordpress
    volumes:
      - db_data:/var/lib/mysql

  # 服务二：WordPress 后端程序
  wordpress:
    image: wordpress:latest
    restart: always
    ports:
      - "8080:80"        # 映射到宿主机 8080 端口
    environment:
      WORDPRESS_DB_HOST: db  # 💡 核心魔法：由于在同一个 compose 文件下，直接用服务名 "db" 就能通信！
      WORDPRESS_DB_USER: root
      WORDPRESS_DB_PASSWORD: my_secret_password
    depends_on:
      - db               # 控制启动顺序：告诉 Docker 必须等 db 启动后，再启动 wordpress

# 声明需要用到的具名卷
volumes:
  db_data:               
```

### 2. 补充：Docker Compose 常用执行命令

这些命令必须在 `docker-compose.yml` 文件所在的同级目录下执行：

```shell
docker compose up -d       # 一键启动并后台运行所有服务 (等同于 run 的批量版)
docker compose down        # 一键停止并删除所有相关的容器和网络 (不删数据卷)
docker compose ps          # 查看当前 compose 项目下的容器状态
docker compose logs -f     # 混合查看所有容器的滚动日志
```