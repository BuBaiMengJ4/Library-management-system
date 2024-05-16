## 简介
这是一个基于命令行界面的简单图书管理程序，旨在实现基本的图书借阅和归还操作。本系统支持普通用户登录、管理员账户管理和图书检索功能。

## 安装指南
下载并解压缩源代码文件，或从资产中下载setup程序，或直接下载`programme.zip`（无需安装）。
- **setup安装注意事项**:在“选择组件”页面时，只需要选择一个即可，组件从上到下是被包含的关系（也就是说，下面是最全的，但不一定适合你）。
>注：开发者用的是MSVC，如果您使用其他编译器，请在代码中稍作修改，具体修改地方已用注释给出。

## 使用方法
- **登录**: 输入用户名和密码进行登录。若为管理员，则可以输入 "Administrator" 和初始密码（114514，密码暂时不支持更改）。
- **借书**: 登录后，输入索书号进行借书。每本书最多可以借阅一次，一位用户最多可以借阅12本。
- **还书**: 输入索书号进行还书操作。
- **搜索**: 提供书名和索书号两种搜索方式，通过输入相应的关键字来查找图书信息（暂不支持模糊搜索）。
- **管理员功能**: 管理员可以添加、查看用户账户密码以及添加图书等。

## 注意事项
- **数据文件**: 程序依赖于多个控制文件（如 `state.control`, `name.control` 等），请确保这些文件与可执行文件位于同一目录下，且文件没有被删除。
- **错误处理**: 如果检测到任何文件缺失或损坏，程序将提示用户联系管理员解决问题。这包括但不限于 `book.control`, `user.control` 等关键文件。
- **版本更新**: 如需更新或改进程序，您可以在GitHub上找到源代码并进行贡献，或从程序的“关于”处发送反馈。我们欢迎社区的贡献和反馈。
- 更多问题请参阅`help.html`。

## 未来的计划

用数据库代替部分control文件记录图书信息；添加更多管理员操作、图书信息和用户个人信息。完成数据的加密工作；实现更新功能；完善帮助文档；将程序错误捕获并写入日志；未来，GUI与CMD版本的图书管理系统将共存。

**本项目合作伙伴：xiaoyu1145(https://github.com/xiaoyu1145)**
