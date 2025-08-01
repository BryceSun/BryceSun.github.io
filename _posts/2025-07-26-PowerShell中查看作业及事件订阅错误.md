---
title: PowerShell中查看作业及事件订阅错误
date: 2025-07-26
categories: [未知]
tags: [未知]
image:
 path: assets/img/blog_face/默认封面.png
 alt:
---
# PowerShell 中查看作业及事件订阅错误

在 PowerShell 中查看事件监控任务（通过 `Register-ObjectEvent` 或 `Start-Job` 创建）的失败信息，可按以下步骤操作：

### **1. 使用 **`Receive-Job`** 获取详细错误**

若任务由 `Start-Job` 或事件注册创建，使用 `Receive-Job` 命令获取输出和错误流：



```
\# 获取所有作业

Get-Job

\# 获取指定作业的错误信息（替换 ID 为实际作业 ID）

\$job = Get-Job -Id <作业ID>

\$job | Receive-Job -ErrorAction SilentlyContinue  # 标准输出

\$job | Receive-Job -Error  # 错误输出
```

若作业已完成，可使用 `-Keep` 参数保留错误信息以便后续查看：



```
Receive-Job -Id <作业ID> -Keep -Error
```

### **2. 检查 **`$Error`** 变量**

PowerShell 会将最近的错误保存在全局变量 `$Error` 中：



```
\# 获取最近的错误

\$Error\[0]

\# 获取所有错误的摘要

\$Error | Select-Object Exception, ErrorRecord, InvocationInfo
```

### **3. 查看作业的 **`JobStateInfo`** 属性**

每个作业对象都包含 `JobStateInfo` 属性，其中可能包含失败原因：



```
\$job = Get-Job -Id <作业ID>

\$job.JobStateInfo.Reason
```

### **4. 检查事件订阅的错误**

若任务是通过 `Register-ObjectEvent` 创建的事件订阅，使用 `Get-EventSubscriber` 和 `Get-Event` 命令：



```
\# 获取所有事件订阅

Get-EventSubscriber

\# 获取指定事件的详细信息（替换 ID 为实际订阅 ID）

\$subscriber = Get-EventSubscriber -SubscriptionId <订阅ID>

\$subscriber | Get-Event | Select-Object \*
```

### **5. 使用 **`Get-History`** 查看命令历史**

若错误发生在交互式会话中，可查看命令历史及输出：



```
Get-History | Select-Object CommandLine, StartExecutionTime, EndExecutionTime
```

### **6. 启用详细日志记录**

在脚本中添加详细输出或日志记录：



```
\# 在脚本中添加错误捕获

try {

&#x20;   \# 可能出错的代码

} catch {

&#x20;   Write-Error "错误: $\_"

&#x20;   $\_ | Out-File "C:\script\_errors.log" -Append

}

\# 启用详细流

\$VerbosePreference = "Continue"

Write-Verbose "正在执行操作..."
```

### **示例：完整的错误检查流程**



```
\# 获取所有作业

\$jobs = Get-Job

\# 遍历作业并输出错误信息

foreach (\$job in \$jobs) {

&#x20;   Write-Host "作业 ID: \$(\$job.Id), 状态: \$(\$job.State)" -ForegroundColor Yellow

&#x20;  &#x20;

&#x20;   if (\$job.State -eq "Failed") {

&#x20;       Write-Host "错误信息:" -ForegroundColor Red

&#x20;       \$job | Receive-Job -Error | ForEach-Object {

&#x20;           "$\_"

&#x20;       }

&#x20;       Write-Host "------------------------"

&#x20;   }

}
```

### **注意事项**



*   **作业完成后错误可能丢失**：若作业已自动清理（如使用 `-AutoRemoveJob` 参数），错误信息可能无法恢复。

*   **远程作业**：若作业在远程会话中运行，需使用 `Invoke-Command` 获取远程错误信息。

*   **事件日志**：部分错误可能记录在 Windows 事件日志中，可通过 `Get-WinEvent` 命令查看。

通过以上方法，可定位并解决 PowerShell 作业执行失败的问题。

> （注：文档部分内容可能由 AI 生成）