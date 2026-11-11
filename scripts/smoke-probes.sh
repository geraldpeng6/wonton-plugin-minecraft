# shellcheck shell=bash
# Minecraft 没有网页、账号体系和 MCP：web、身份、工具三项由套件按清单记 N/A。
# 用户数据就是数据卷里的世界和配置（/data）。服务端没有能从外面写数据的接口（游戏协议要完整客户端，
# 控制台要终端），所以数据探针把随机标记写进服务器容器挂载的 /data：升级、重装后标记还在，
# 就证明世界目录随数据卷保住了（容器里 exec 写的文件和服务端写世界用的是同一个挂载）。

_container() { # 本实例里 minecraft 服务的容器：按核心打的标签找，实例名没导出时按 SMOKE_BASE 推
  local inst="${SMOKE_INSTANCE:-}" args=(--filter "label=wonton.plugin=$SMOKE_PLUGIN_ID" --filter "label=wonton.service=minecraft")
  if [[ -z "$inst" && -n "${SMOKE_BASE:-}" ]]; then
    inst="${SMOKE_BASE#http://}"; inst="${inst%%.*}"
  fi
  [[ -z "$inst" ]] || args+=(--filter "label=wonton.instance=${inst//-/}")
  docker ps --format '{{.Names}}' "${args[@]}" | head -1
}

data_write() {
  local marker c
  c="$(_container)" || return 1
  [[ -n "$c" ]] || { echo "找不到 minecraft 容器"; return 1; }
  marker="wonton-smoke-$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')"
  docker exec "$c" sh -c "printf %s '$marker' > /data/wonton-smoke-marker" ||
    { echo "往 /data 写标记失败"; return 1; }
  printf '%s' "$marker" >"$(marker_file)"
}

data_check() { # 重装后标记还在，内容一致
  local marker c got
  marker="$(cat "$(marker_file)")"
  [[ -n "$marker" ]] || { echo "SMOKE_STATE 里没有标记"; return 1; }
  c="$(_container)" || return 1
  [[ -n "$c" ]] || { echo "找不到 minecraft 容器"; return 1; }
  got="$(docker exec "$c" cat /data/wonton-smoke-marker 2>&1)" ||
    { echo "读不回标记：$got"; return 1; }
  [[ "$got" == "$marker" ]] || { echo "标记对不上：期望 $marker，读到 $got"; return 1; }
}

marker_file() { # SMOKE_STATE 在套件里是状态目录（e2e 传的是标记文件本身），标记放对应路径
  if [[ -d "$SMOKE_STATE" ]]; then printf '%s' "$SMOKE_STATE/minecraft-marker"; else printf '%s' "${SMOKE_STATE}.marker"; fi
}

export IDENTITY_NA=1
SMOKE_NOTE="${SMOKE_NOTE:-}游戏服务器没有自己的账号：进服的人用 Minecraft 正版账号（online-mode），身份由 Mojang 校验，插件侧没有“当前用户”可断言。"
