# BettaFish (微舆) 部署与修复交接文档

## 1. 项目现状与成果

**项目地址**：[https://github.com/xmkinc/BettaFish](https://github.com/xmkinc/BettaFish) (Fork 自 666ghj/BettaFish)
**部署地址**：[https://bettafish-production-e142.up.railway.app](https://bettafish-production-e142.up.railway.app)

已成功将 BettaFish 部署至 Railway 平台，并修复了原项目中阻碍云端部署的几个核心 Bug，使得应用能在单容器多端口环境下正常运行。

## 2. 已修复的核心问题

原项目在本地运行正常，但在云端部署（如 Railway 单端口暴露限制）时会遇到以下致命问题，现已全部修复：

### 2.1 Streamlit iframe 无法跨域加载与通信 (已修复)
- **问题表现**：点击"开始"搜索后，没有任何 Agent 响应。因为原代码前端直接通过 `http://localhost:8501` 访问 Streamlit，在云端该端口未对外暴露。
- **修复方案**：
  1. 引入 **Nginx** 作为反向代理，统一监听 5000 端口。
  2. Nginx 将 `/streamlit/insight/` 等路径代理到对应的 Streamlit 内部端口 (8501/8502/8503)。
  3. 关键修复：Nginx 配置了 **WebSocket 升级支持** (`Upgrade $http_upgrade`)，解决 Streamlit 无法建立 WebSocket 连接导致一直显示 "Please wait..." 的问题。
  4. 修改 `app.py`，为 Streamlit 启动命令添加 `--server.baseUrlPath /streamlit/xxx`，让 Streamlit 知道自己运行在子路径下，从而正确加载静态资源。

### 2.2 前后端搜索请求路由错误 (已修复)
- **问题表现**：Flask 的 `/api/search` 试图向 Streamlit 发送 POST 请求，但 Streamlit 没有该 API 端点。
- **修复方案**：修改 Flask 的 `/api/search` 路由，使其不再发送无效的 POST 请求，而是返回各 Agent 的**代理 URL**。前端 JS 收到 URL 后，通过更新 iframe 的 `src` 来触发 Streamlit 的 URL 参数查询机制 (`?query=...&auto_search=true`)。

### 2.3 CORS 与数据库字符集警告 (已修复)
- **问题表现**：Streamlit 启动时报 CORS 冲突警告；PostgreSQL 数据库配置默认显示 MySQL 专用的 `utf8mb4`。
- **修复方案**：在 `app.py` 中为 Streamlit 添加 `--server.enableXsrfProtection false` 参数；在 `config.py` 中将 `DB_CHARSET` 默认值改为空。

### 2.4 Query Agent 强制依赖 Tavily (已修复)
- **问题表现**：如果没有配置 Tavily API Key，Query Agent 会直接崩溃退出，即使配置了 Anspire/Bocha 也不行。
- **修复方案**：修改 `SingleEngineApp/query_engine_streamlit_app.py`，将强制报错改为警告提示，允许在只有 Anspire/Bocha 的情况下继续运行其他 Agent。

## 3. 部署架构说明

当前 Railway 部署采用 **Nginx + Flask + Streamlit** 混合架构：

- **Railway 暴露端口**：5000 (由 Nginx 监听)
- **Nginx (5000)**：
  - `/` -> 转发给 Flask (内部端口 5001)
  - `/api/` -> 转发给 Flask (内部端口 5001)
  - `/streamlit/insight/` -> 转发给 Insight Streamlit (内部端口 8501，支持 WebSocket)
  - `/streamlit/media/` -> 转发给 Media Streamlit (内部端口 8502，支持 WebSocket)
  - `/streamlit/query/` -> 转发给 Query Streamlit (内部端口 8503，支持 WebSocket)

## 4. 环境变量配置清单

Railway 中已配置以下环境变量（均已生效）：

| 变量名 | 说明 |
|---|---|
| `DATABASE_URL` | Railway 内部 PostgreSQL 连接字符串 |
| `INSIGHT_ENGINE_API_KEY` | OpenRouter API Key |
| `MEDIA_ENGINE_API_KEY` | OpenRouter API Key |
| `QUERY_ENGINE_API_KEY` | OpenRouter API Key |
| `REPORT_ENGINE_API_KEY` | OpenRouter API Key |
| `MINDSPIDER_API_KEY` | OpenRouter API Key |
| `FORUM_HOST_API_KEY` | OpenRouter API Key |
| `KEYWORD_OPTIMIZER_API_KEY` | OpenRouter API Key |
| `ANSPIRE_API_KEY` | Anspire 搜索 API Key |
| `BOCHA_WEB_SEARCH_API_KEY` | Bocha 搜索 API Key |
| `TAVILY_API_KEY` | Tavily 搜索 API Key |

## 5. 后续维护建议

1. **等待最新部署完成**：当前 Railway 正在进行最后一次构建（应用了完整的 Nginx WebSocket 和 baseUrlPath 修复），构建完成后（约需 8 分钟），系统即可完美运行。
2. **私有数据分析**：Insight Agent 需要连接包含实际社媒数据的数据库才能发挥作用。目前连接的是 Railway 提供的空 PostgreSQL 数据库。你需要额外部署 `MindSpider` 爬虫项目，将爬取的数据写入该数据库。
3. **模型调优**：目前所有 Agent 统一使用了 OpenRouter 提供的模型（如 `kimi-k2`, `gemini-2.5-pro`），你可以在页面点击"LLM 配置"根据实际效果调整不同 Agent 使用的模型。
