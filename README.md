# iOS 照片和视频导出工具

在 Windows 上通过 USB 将已连接 iPhone 的指定时间段照片和视频复制到本地。无需安装 Python、iTunes 或第三方模块。保留原始文件格式，按设备月份子文件夹保存，避免不同目录中的同名文件相互覆盖。

## 使用

连接并解锁 iPhone，选择“信任此电脑”或允许照片访问。在本目录打开 PowerShell：

```powershell
# 预览：结束时间省略时固定为本次运行开始的当前时间
powershell -NoProfile -STA -ExecutionPolicy Bypass -File .\Export-iPhone.ps1 -Start "2026-10-29 08:00:00" -Preview

# 导出到指定目录，起止时间均包含在内
powershell -NoProfile -STA -ExecutionPolicy Bypass -File .\Export-iPhone.ps1 -Start "2026-10-29 08:00:00" -End "2026-10-29 17:00:00" -Destination "D:\iPhone导出"

# 将 config.example.json 复制为 config.json，设置时间段、路径后运行
powershell -NoProfile -STA -ExecutionPolicy Bypass -File .\Export-iPhone.ps1 -Config .\config.json
```

Destination 省略或留空时使用程序旁的 `exports` 文件夹。`-Media Photos` 仅导出图片，`-Media Videos` 仅导出视频。大视频可设置 `-TimeoutSeconds 600`。每次运行按配置导出一次，不是后台定时任务。

也可以先编辑 `config.json`，再双击 `Start-Export.cmd`。首次没有配置时，启动入口会复制示例配置并打开记事本；修改时间和路径、保存后，再次双击启动入口执行导出。

默认只扫描起止日期所在月份目录；如果照片被移动、导入或日期曾修改，可用 `-AllFolders` 扫描所有目录，耗时可能很长。

## 时间与完整性

时间使用 iPhone 通过 Windows Portable Devices 提供的创建时间，并明确从 UTC 转换为 `-TimeZone`（默认北京时间）。保留秒精度，避免 UTC 与北京时间相差 8 小时造成漏选。这通常对应手机媒体的原始创建时间，但手机相册中手动修改后的日期、下载图片的 EXIF 拍摄日期不一定一致；工具不会声称能读取 iOS 相册数据库。可先预览名单核对。

每个文件按设备报告的字节数核对，并在输出目录写入 JSON 清单。已有同名且大小一致的文件会跳过，大小不同则停止以避免覆盖。字节数核对不等同于内容哈希核对。复制失败保留原文件和可能的部分输出；重试前将部分输出改名。手机文件不会被删除。

iCloud 中尚未下载的原片可能不在 USB 可见目录内，需要先在手机上下载原片。Live Photo 的照片和配套 MOV 会分别导出。

## Codex 技能

仓库 `skill/ios-photo-export/SKILL.md` 包含调用说明。复制该目录到你的 Codex `skills` 目录，并将 `program-path.txt` 设置为本机 `Export-iPhone.ps1` 的绝对路径。以后请求“导出 iPhone 今天早上 8 点到现在的照片和视频”即可让 Codex 使用程序。

也可运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-CodexSkill.ps1` 自动安装到 Codex 技能目录并记录程序路径。安装后在新对话中使用技能；移动程序目录后需同步更新技能的 `program-path.txt`。

程序只在本地读取 USB 设备并写入指定目录，不上传照片。仓库只包含程序、配置示例及技能，不包含任何导出媒体或个人配置。
