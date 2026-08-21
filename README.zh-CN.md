<h1 align="center">Fleet</h1>
<p align="center">原生 macOS 终端，每个工作区都是同一块看板上的实时卡片</p>

<p align="center">
  <a href="README.md">English</a> | 简体中文
</p>

> **Fleet 是 [cmux](https://github.com/manaflow-ai/cmux)（Manaflow, Inc.）的个人 fork。**
> 这里几乎所有东西 —— 基于 Ghostty 的终端、竖向标签页、agent 通知系统、可脚本化的浏览器、
> CLI —— 都是上游的工作。Fleet 做的是：改名、加上 fleet canvas、并给构建产物一个独立身份，
> 使它能与 cmux 并存安装。本项目与 Manaflow 无关，也未获其背书。
>
> 如果你想要的是有人维护、正式签名、有下载链接的那个，请用 [cmux](https://github.com/manaflow-ai/cmux)。

## Fleet 增加了什么

### Fleet canvas

一个看板视图：窗口里每个工作区都是一张实时卡片 —— 是真正的终端，不是预览图。
它是为「同时跑多个编码 agent，并且一眼看全」而做的。

- **卡片是组队，不是二分。** 布局是 N 元树：一个容器可以有任意多个成员，所以三个工作区
  能等宽并列，而不会退化成层层嵌套的二分。把一张卡片拖到另一张旁边，不会被迫变成 1/2 分割。
- **落点按位置判断意图。** 拖进卡片内部 = 与它组队；落在两张卡片之间的缝隙、或一行的首尾
  = 平级插入。按住 Shift 可多选，右键菜单里的 **Group workspace** / **Exit group** 与拖拽
  完全等效，用于拖拽不好使的场合。
- **卡片不会乱动。** 按比例调整尺寸并记住比例，也不会因为某个会话忙起来就自己换位置。
- **标题说人话。** 单个终端显示路径；跑着 agent 时显示 agent 与会话标题，并换成该 agent 的
  图标；多个终端则显示共同路径。手动改过的标题不会再被自动覆盖。
- **快速启动。** 每张卡片的操作栏里有 Claude 和 Codex 按钮，在该工作区自己的目录下启动 ——
  当前终端空闲就直接用它，忙则新开一个 pane。

### 其它改动

- **统一的主题色**（绿色）取代了散落各处的 `Color.accentColor`，包括标签栏的装饰色 ——
  它此前跟随 macOS 系统强调色，而不是 app 自己的主题。
- **等待处理的工作区改为闪烁的黄色边框**，此前是常亮的边框，容易被忽略。遵循「减弱动态效果」设置。
- **只有一个光标在闪。** Ghostty surface 会沿用创建时的 focus 意图，所以从未获得过 first
  responder 的 pane 会一直闪实心光标。现在不会了。

### 独立身份

Fleet 的 Release 构建是 `com.tankxu.fleet`，因此它与 cmux 并存安装、而非替换。状态数据
按这个身份隔离 —— `~/.config/fleet/fleet.json` 和 `~/Library/Application Support/fleet/` ——
因为两个 app 共用同一份 session 快照文件会互相覆盖工作区。已有的 cmux 安装完全不受影响。

目录名是从运行时的 bundle id 派生的，而不是编译期写死，所以 Debug 与 nightly 构建仍然读取
它们原本的 `cmux` 状态。

仓库内的 `.cmux/` 项目配置目录**故意保持不变**：那是与 cmux 共享的仓库内约定，改名会让
cmux 读不了这些配置。

## 安装

没有 DMG、没有 Homebrew、没有自动更新 —— 自己构建：

```bash
./scripts/setup.sh          # 子模块 + GhosttyKit
./scripts/install-fleet.sh  # 构建 Release，安装到 /Applications/Fleet.app
```

它同时会在 `~/bin` 装一个 `fleet` 命令。在 Fleet 或 cmux 的终端里，它指向拥有该终端的那个
app；在别处则指向 Fleet。已有的 `cmux` 命令不会被改动。

构建使用本地签名，与本项目一直在用的 Debug 构建相同。设置
`FLEET_DEVELOPMENT_TEAM=<team-id>` 可改用真实证书签名 —— 注意那条路会在该团队下注册
`com.tankxu.fleet` 这个 App ID。

## 已知限制

这些是真实存在且尚未解决的问题，不是路线图：

- **登录目前走不通。** Fleet 注册 `fleet://` 作为回调 scheme，因为两个已安装的 app 都声明
  `cmux://` 时，macOS 可能把回调交给错的那一个。服务端的 scheme 白名单需要部署 `fleet`
  之后登录才能完成。临时办法是 `CMUX_AUTH_CALLBACK_SCHEME=cmux`。
  纯本地使用 —— 终端、工作区、分割、画布 —— 完全不需要账号；登录只影响手机配对、云端工作区和同步。
- **iOS app 仍然是 cmux。** 给它改名需要 Apple Developer 的 App ID、APNs key，以及后端推送
  路由的改动。
- **内部标识符仍然是 `com.cmuxterm`** —— logger subsystem、dispatch queue label、通知名。
  它们不面向用户，而改写其中 225 处纯属折腾，且很容易打错字。
- **README 里没有截图。** 上游的截图是 cmux 的界面，现在已经对不上了。

## 其余部分

Fleet 原封不动地继承了 cmux 的其余部分 —— 竖向标签页、agent 通知边框、会话恢复、可脚本化的
内置浏览器、socket API、分割面板、键盘快捷键。这些内容以上游为准：

- [cmux README](https://github.com/manaflow-ai/cmux/blob/main/README.md) —— 功能与键盘快捷键
- [cmux 文档](https://cmux.com/docs/getting-started) —— 配置说明

若本 fork 与那些文档在名称或颜色上有出入，那是本 fork 改动过的地方。

## 许可

GPL-3.0-or-later，与上游相同。Copyright (c) 2024-present Manaflow, Inc.；
其他贡献者与第三方保留其材料的著作权。本 fork 的改动以相同许可提供。
见 [LICENSE](LICENSE) 与 [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md)。
