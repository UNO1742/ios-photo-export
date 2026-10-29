---
name: ios-photo-export
description: 在 Windows 上调用本地导出程序，通过 USB 将 iPhone 指定时间段的照片和视频导出到用户指定文件夹。用于导出手机照片、视频和按日期范围复制相册媒体。
---

# iPhone 照片和视频导出

读取本技能目录中的 `program-path.txt`，取得 `Export-iPhone.ps1` 的本机绝对路径。路径缺失时寻找工作区中的 `ios-photo-export/Export-iPhone.ps1`，不要重新手写 COM 复制流程。

将用户的相对时间解析为用户当前时区的具体起止时间；“到现在”在首次预览前固定为同一个时间戳，预览和执行使用完全相同的时间段。仅用户确实未说明时间范围时询问。保存位置按用户指定；未指定时使用程序默认 `exports` 目录。照片和视频默认都包含，用户仅要求照片时传 `-Media Photos`，仅视频时传 `-Media Videos`。

用 Windows PowerShell 的 STA 模式调用程序：

```powershell
powershell -NoProfile -STA -ExecutionPolicy Bypass -File "<program>" -Start "yyyy-MM-dd HH:mm:ss" -End "yyyy-MM-dd HH:mm:ss" -Destination "<folder>" -Preview
```

预览成功后，在同一参数上移除 `-Preview` 执行导出；已有用户导出指令即为授权，无需再次确认。需要时将 `-TimeoutSeconds` 提高到 600 处理大视频。程序调用耗时超过工具初始等待时，按工具返回的 session/cell 标识继续等待，不要重复启动导出。

程序按 iPhone WPD 创建时间从 UTC 转为指定时区筛选，不能保证与用户手动修改的相册日期一致。不要按未转换的 COM 时间或修改时间筛选。默认月份目录适合新拍摄媒体；用户提到旧照片改日期或发现漏项时，结合限制考虑 `-AllFolders`。不能读取的 iCloud 原片需用户先下载到手机。

设备未识别或目录不可访问时，提示用户解锁、信任电脑及检查 USB；等待用户完成后再重试。复制失败停止并保留清单与部分文件；检查失败文件，大小不符时将该部分文件改名后最多重试一次，不删除源文件、不覆盖冲突文件。

只在程序返回成功且清单中每项状态为 `Copied` 或 `AlreadyPresent` 时报告完成，说明图片/视频数量、总字节数、实际时间范围与输出路径。核对的是大小，不要称为哈希校验。不要把照片、视频、导出清单或本机配置提交到公开仓库。
