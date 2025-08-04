---
title: PowerShell脚本闪退排查与解决
date: 2025-07-26
categories: [脚本,powershell]
tags: [闪退]
image:
 path: assets/img/blog_face/默认封面.png
 alt:
---

在 Windows 系统中，PowerShell 脚本运行后立即闪退通常是由以下原因造成的：

### 一、脚本执行完毕自动退出

PowerShell 脚本在执行完最后一行代码后就会自动关闭窗口。要是你的脚本没有耗时操作，窗口就会快速消失。

**解决办法**：



1.  **在脚本末尾添加暂停命令**

    在脚本的最后加上 `Read-Host -Prompt "按任意键退出"`，这样脚本执行结束后会等待用户按键才关闭窗口。

2.  **从 PowerShell 控制台运行脚本**

    先打开 PowerShell 控制台，再通过命令来运行脚本，比如：`PS C:\> .\your_script.ps1`。

### 二、脚本执行出错

要是脚本里有错误，可能会致使脚本提前终止，进而让窗口快速关闭。

**解决办法**：



1.  **添加错误捕获**

    在脚本中运用 `try-catch` 块来捕获并显示错误信息，示例如下：



```
try {

&#x20;   \# 脚本主体代码

}

catch {

&#x20;   Write-Host "错误: $\_" -ForegroundColor Red

&#x20;   Read-Host -Prompt "按任意键退出"

}
```



1.  **使用日志记录**

    把脚本的执行过程记录到日志文件中，代码如下：



```
Start-Transcript -Path "C:\script\_log.txt"

\# 脚本代码

Stop-Transcript
```

### 三、执行策略限制

PowerShell 的执行策略可能会禁止脚本运行，这也会造成窗口闪退。

**解决办法**：



1.  **临时更改执行策略**

    以管理员身份打开 PowerShell，然后运行命令：`Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`，接着再运行脚本。

2.  **修改系统执行策略**

    以管理员身份打开 PowerShell，运行命令：`Set-ExecutionPolicy RemoteSigned`，不过这种方式会对系统全局产生影响。

### 四、脚本路径或编码问题



*   **路径包含空格或特殊字符**：要确保路径被正确引用，例如：`"C:\My Scripts\test.ps1"`。

*   **编码不兼容**：脚本文件要保存为 UTF-8 或者 UTF-16 格式，防止出现字符解析错误。

### 五、调试建议



1.  **分步执行脚本**

    在脚本中添加多个 `Read-Host` 命令，从而确定具体是哪一行代码导致了闪退。

2.  **使用 PowerShell ISE**

    借助 PowerShell ISE（集成脚本环境）来运行脚本，这样可以直接查看错误信息。

3.  **命令行调试**

    在命令提示符中通过以下方式运行脚本，查看错误输出：



```
powershell -NoExit -File "C:\path\to\your\_script.ps1"
```

参数说明：



*   `-NoExit`：脚本执行完后不关闭窗口。

*   `-File`：指定要运行的脚本文件。

通过上述方法，你应该能够找出 PowerShell 脚本闪退的原因并解决问题。

> （注：文档部分内容可能由 AI 生成）
