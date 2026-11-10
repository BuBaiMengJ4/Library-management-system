# 图书管理系统 · FluentUI 重构版

> 将 Vision 1.0 的 CMD + MSVC 图书管理程序重构为 **Qt 6 QML + CMake + FluentUI** 桌面应用。

[![Qt](https://img.shields.io/badge/Qt-6.11.1-41CD52?logo=qt&logoColor=white)](https://www.qt.io/)
[![CMake](https://img.shields.io/badge/CMake-3.21%2B-064F8C?logo=cmake&logoColor=white)](https://cmake.org/)
[![FluentUI](https://img.shields.io/badge/FluentUI-1.7.7-0078D4)](https://github.com/zhuzhihang/FluentUI)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0078D4)](https://www.microsoft.com/windows)

---

## 项目简介

本项目最初是一个基于命令行的 C++ 图书管理作业（Vision 1.0，MSVC + `.sln`）。重构版本保留了原有的登录、借书、还书、检索和管理员功能，并将界面迁移到 Fluent Design 风格的 Qt QML 桌面程序，使用 CMake 管理构建。

- **界面**：Qt 6 QML + [FluentUI 1.7.7](https://github.com/zhuzhihang/FluentUI)，支持深色 / 浅色主题与响应式导航。
- **业务**：C++17 `LibraryService` 单例，向 QML 暴露账户、图书、借阅与统计接口。
- **存储**：Qt SQL（SQLite）数据库；用户与图书的文本字段逐字段 **AES-256-GCM** 加密，主密钥由 **Windows DPAPI** 保护。
- **迁移**：首次运行时可自动读取旧版 `book.control`、`user.control`、`pass.control` 等文件并加密导入 SQLite。

> 重构后已移除原 MSVC 工程（`.sln` / `.vcxproj` / `.rc` / `Main.cpp` / `x64` 等）与旧版 `control` 数据文件。

---

## 界面预览

### 登录

![登录](docs/login.png)

### 首页（浅色）

![首页](docs/home.png)

### 图书检索

![图书检索](docs/search.png)

### 我的借阅

![我的借阅](docs/mybooks.png)

### 管理中心 · 加密数据库

![数据中心](docs/admin-data.png)

### 关于

![关于](docs/about.png)

### 深色主题

![深色主题](docs/home-dark.png)

---

## 功能

| 模块 | 功能 |
| --- | --- |
| 登录 | 用户名 / 密码登录；管理员与读者权限区分；错误提示；数据库不可用时禁用登录 |
| 首页 | 馆藏统计、可借 / 借出 / 我的额度、快捷入口、借阅规则 |
| 图书检索 | 按全部（书名 / 作者 / 出版社 / 索书号）、书名、作者、索书号搜索；结果直接借书 / 还书 |
| 借阅 | 输入索书号借阅；可借列表一键借阅；每人最多 12 本；每本书同一时间仅可借一次 |
| 归还 | 输入索书号归还；我的在借列表一键归还；归还后额度立即恢复 |
| 我的借阅 | 借阅额度进度、在借清单、借阅日期与建议归还日期 |
| 管理中心 | 图书录入、创建读者账户、查看账户、重置密码、删除账户、载入示例数据 |
| 关于 | 版本 / 作者 / 技术架构 / 常见问题 / 反馈与仓库链接 |
| 主题 | 深色 / 浅色切换，跟随 FluentUI 主题系统 |
| 快捷键 | `Ctrl+1` 首页、`Ctrl+2` 检索、`Ctrl+3` 借阅、`Ctrl+4` 归还、`Ctrl+5` 我的借阅、`Ctrl+6` 管理中心（管理员）、`Ctrl+7` 关于 |

管理员默认账号：

```text
用户名：Administrator
密码：114514
```

---

## 数据与加密

### 存储位置

默认位置（按当前 Windows 用户）：

```text
%APPDATA%\BuBaiMengJ4\LibraryManagementSystem\
├── library.db    # SQLite 数据库
├── library.key   # DPAPI 保护的主密钥
└── logs\app.log  # 运行日志
```

如果该目录不可写，程序会依次回退到可执行文件旁的 `data/`、系统临时目录，并在日志中记录实际路径。管理中心的“数据与示例”页会显示当前数据库路径。

### 加密方案

- 使用 **Qt SQL / QSQLITE** 驱动，数据库为单文件 SQLite。
- 每个用户字段（用户名、密码、管理员标记）和每个图书字段（书名、作者、出版社、位置、借阅人、借阅时间）都单独使用 **AES-256-GCM** 加密。
- 密文格式：`0x01 | 12 字节 nonce | 16 字节认证标签 | 密文`。
- AAD 绑定 `library/user/<uuid>/<字段>` 或 `library/book/<索书号>/<字段>`，避免密文被跨字段替换。
- 32 字节主密钥由 `QRandomGenerator` 生成，写入前通过 **Windows DPAPI**（当前用户范围）加密，保存为 `library.key`。
- 数据库中的 `users.username_enc`、`books.name_enc` 等文本列均为 BLOB 密文；明文只存在于程序内存中。
- 图书索书号、用户 UUID 作为查询 / 关联键保留明文，不含个人文本内容。

> 管理员页面需要显示和重置账户密码，因此密码采用可逆加密（而非哈希）。这是对旧版“查看账号密码”功能的兼容；请勿在真实生产环境使用重要密码。

### 旧版数据迁移

首次启动且数据库中没有账户时，程序会尝试从以下目录读取 Vision 1.0 的 `control` 文件：

1. 可执行文件所在目录；
2. 可执行文件上两级目录（便于从项目根目录运行）；
3. 当前工作目录。

支持的旧文件：`book.control`、`name.control`、`writer.control`、`state.control`、`publisher.control`、`user.control`、`pass.control`、`user/*.control`。迁移完成后原始文件不会被修改；迁移结果会加密写入 SQLite。

### 备份与恢复

- 备份：关闭程序后复制 `library.db` 与 `library.key`。两者必须成对保存。
- 恢复：将同一对文件放回数据目录即可。
- `library.key` 由 DPAPI 绑定到“当前 Windows 用户 + 当前机器”，复制到其他用户或电脑后无法解密，这是预期的安全行为。
- 如果数据库存在但密钥丢失，程序会拒绝打开数据库并在登录页显示错误；需要恢复 `library.key` 或删除数据库重新开始。

---

## 构建

### 环境

- Windows 10 / 11 64 位
- Qt **6.11.1** MinGW 64-bit（项目自带 FluentUI 1.7.7 源码）
- CMake **3.21+**
- MinGW 13.1（随 Qt 安装：`C:\Qt\Tools\mingw1310_64`）
- Qt SQL SQLite 驱动（Qt 安装自带 `sqldrivers/qsqlite.dll`）

> 加密存储使用 Windows DPAPI + BCrypt，因此当前仅支持 Windows 构建。

### 命令行

```powershell
# 让 CMake 与 MinGW 可用
$env:Path = "C:\Qt\Tools\CMake_64\bin;C:\Qt\Tools\mingw1310_64\bin;C:\Qt\6.11.1\mingw_64\bin;" + $env:Path

# 配置
cmake -S . -B build -G "MinGW Makefiles" `
      -DCMAKE_BUILD_TYPE=Release `
      -DCMAKE_PREFIX_PATH="C:/Qt/6.11.1/mingw_64"

# 编译
cmake --build build --parallel
```

生成文件：

```text
build\bin\LibraryManagementSystem.exe
build\qml\FluentUI\fluentuiplugin.dll
```

运行时需要 Qt 的 DLL 与 SQLite 驱动在搜索路径中。推荐直接用 Qt Creator 打开根目录 `CMakeLists.txt` 并运行；或从 Qt 命令行启动：

```powershell
$env:Path = "C:\Qt\6.11.1\mingw_64\bin;" + $env:Path
.\build\bin\LibraryManagementSystem.exe
```

### 发布包

```powershell
cmake --build build --target deploy
```

该目标会生成 `build/dist`，其中包含 Qt 运行库、平台插件、`sqldrivers`、QML 模块和本项目构建的 FluentUI 插件：

```text
build\dist\LibraryManagementSystem.exe
build\dist\sqldrivers\qsqlite.dll
build\dist\qml\FluentUI\fluentuiplugin.dll
```

`build/dist/LibraryManagementSystem.exe` 可以脱离 Qt 安装目录直接运行（已在没有 Qt `PATH` 的环境下验证）。

### FluentUI 说明

项目以源码形式包含 [`FluentUI`](FluentUI)，根 `CMakeLists.txt` 将插件输出到：

```text
<build>/qml/FluentUI
```

`src/main.cpp` 通过 `FLUENTUI_IMPORT_PATH` 将该目录加入 QML 导入路径，同时兼容可执行文件旁的 `qml/FluentUI`。界面中使用的 `FluWindow`、`FluNavigationView`、`FluContentPage`、`FluPivot`、`FluTextBox`、`FluPasswordBox`、`FluFilledButton`、`FluContentDialog`、`FluInfoBar`、`FluTheme` 等均来自 FluentUI 1.7.7 的头文件 / QML 组件，未引入不存在的 API。

---

## 目录结构

```text
Library-management-system/
├── CMakeLists.txt              # 顶层构建
├── library.ico                 # 旧版项目图标（窗口 / exe）
├── src/
│   ├── CMakeLists.txt
│   ├── main.cpp                # QGuiApplication + QML 引擎 + 日志
│   ├── qml.qrc                 # QML 与图标资源
│   ├── backend/
│   │   ├── Encryption.h/.cpp   # DPAPI + AES-256-GCM
│   │   └── LibraryService.h/.cpp # 业务、SQLite、迁移与加密持久化
│   ├── qml/
│   │   ├── App.qml             # FluLauncher + 路由
│   │   ├── LoginWindow.qml
│   │   ├── MainWindow.qml      # 导航、用户信息、快捷键、退出
│   │   ├── components/         # StatCard / BookCard / EmptyState
│   │   └── pages/              # 首页、检索、借阅、归还、我的借阅、管理、关于
│   └── resources/app.rc.in     # Windows 图标与版本信息
├── FluentUI/                   # FluentUI 1.7.7 源码
├── docs/                       # README 截图
└── README.md
```

数据库结构：

```sql
users(id TEXT PRIMARY KEY, username_enc BLOB, password_enc BLOB, admin_enc BLOB)
books(number INTEGER PRIMARY KEY, name_enc BLOB, author_enc BLOB,
      publisher_enc BLOB, place_enc BLOB, borrower_enc BLOB, borrowed_at_enc BLOB)
```

---

## 重构说明

- 用 `FluWindow` + `FluNavigationView` 替代旧版控制台菜单；用 `FluContentPage` / `FluPivot` 组织页面。
- 用 `LibraryService` 单例替代旧版全局变量、`connect.temp`、`limit.temp` 等临时文件。
- 用 SQLite 事务替代多个 `control` 文本文件的逐行读写；每次借阅 / 归还 / 增删账户都会原子提交。
- 用逐字段认证加密替代明文 `user.control` / `pass.control`。
- 旧版 MSVC 工程、`.rc`、`Main.cpp`、预编译二进制、`x64/` 构建产物和旧 `control` 数据均已清理；图标与版本说明延续 Vision 1.0。
- 旧版功能（12 本借阅上限、每本书仅一位借阅人、管理员查看 / 重置密码、按书名 / 索书号检索）全部保留。

### 已知限制

- 仅支持 Windows（DPAPI / BCrypt）。
- 数据按字段加密，因此书名 / 作者检索在内存中完成；当前规模（约 1000 本）足够，若数据量很大需要引入可搜索加密或索引列。
- 管理员可查看解密后的账户密码，请勿在真实生产环境使用重要密码。
- 主题选择不做跨会话持久化，默认跟随 FluentUI / 系统主题。

---

## 反馈与致谢

- 作者：**BuBaiMengJ4**、**xiaoyu1145**
- 版本：Vision 1.0（正式版） / Qt QML 重构版 1.0.0
- 仓库：[github.com/BuBaiMengJ4/Library-management-system](https://github.com/BuBaiMengJ4/Library-management-system)
- 反馈：[Microsoft Forms](https://forms.office.com/Pages/ResponsePage.aspx?id=DQSIkWdsW0yxEjajBLZtrQAAAAAAAAAAAAN__jFEEqlUMVhLU0RFSE0yOUxLUlRMSDAzUDRQQUJTMS4u)

感谢 FluentUI 作者 **zhuzhihang** 开源这套 Qt Fluent Design 组件库。
