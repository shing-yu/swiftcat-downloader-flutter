# 灵猫小说下载器 Flutter

一个用于下载七猫小说的工具。

[swiftcat-downloader](https://github.com/shing-yu/swiftcat-downloader) 的 Flutter 版本。

**Flutter 版本是技术测试版本，不保证稳定性。**


## 特性

- [x] 支持保存为TXT格式
- [x] 支持保存为单文件或按章节保存*
- [x] 极快的下载速度
- [x] 漂亮的用户界面
- [x] 全平台支持*
- [ ] 下载为EPUB格式
- [ ] 通过书名搜索小说

*按章节保存支持平台：Android、iOS、macOS、Windows、Linux  
*全平台支持：Android、iOS、macOS、Windows、Linux、Web

## 特定于平台的说明

#### Android
由于 Android 10 及以上版本的存储权限限制，目前 Android 版本只能保存到 Download 文件夹。  
支持的架构：arm64-v8a、armeabi-v7a、x86_64
#### iOS
由于签名需要向Apple缴纳开发者费用，iOS 版本提供的ipa文件需要您自行使用第三方工具（如 爱思助手）进行签名后才能安装。  
我们不提供关于签名的技术支持，请您自行查找相关资料。
#### macOS
macOS 版本由于需要自定义文件保存路径，故运行时未使用沙盒模式，请您仅从信任的来源下载应用。  
您可能需要执行以下操作来在新版本的 macOS 上运行应用：
1. 打开“终端”应用
2. 输入并回车执行 `sudo spctl --global-disable`，  
   输入您的管理员密码（输入时不会显示）并回车；
3. 打开 系统设置 > 隐私与安全性 > 常规，  
   在“允许以下来源的应用程序”下选择“任何来源”，输入密码并同意。
4. 在“终端”应用中输入并回车执行 `sudo xattr -r -d com.apple.quarantine /Applications/灵猫小说下载器.app`
5. 运行应用。  
支持的架构：arm64 (Apple Silicon)、x86_64 (Intel)
#### Linux
支持的架构：arm64、x86_64
#### Web
Web 版本支持 Chrome、Edge、Firefox 等现代浏览器，您可能需要在浏览器设置中打开硬件加速功能以避免白屏。  
由于浏览器限制，不支持分章节保存模式，且仅能保存至浏览器下载目录。

## 许可

基于 星缘工作室软件共享许可证A 1.0 (SSLA 1.0) 发布，详情见 [LICENSE.md](https://github.com/shing-yu/swiftcat-downloader-flutter/blob/main/LICENSE.md)。

仅供个人学习研究使用，严禁用于任何商业目的，请于下载后24小时内删除小说文件。

书籍内容著作权归原作者所有，使用本软件下载书籍内容前请确保您遵循当地法律法规。

本项目作者、贡献者不对因用户使用本软件而导致的任何直接、间接、偶然、特殊或后果性损害承担责任。

## 技术支持

社区Q群：690736066

如果您认为本程序侵犯了您的权益，请通过 shyu@staredges.cn 联系我们。
