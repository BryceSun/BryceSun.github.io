---
title: Puppeteer使用介绍
date: 2025-07-26
categories: [未知]
tags: [未知]
image:
 path: assets/img/blog_face/默认封面.png
 alt:
---

Puppeteer 是一个由 Chrome 团队开发的 Node.js 库，提供高级 API 来控制无头(Headless) Chrome 或 Chromium 浏览器。它可以用于网页自动化、测试、爬虫等多种场景。

## 1. 核心特性

- **完全控制 Chrome/Chromium**：可以执行几乎所有手动操作
- **无头模式支持**：可以运行不显示界面的浏览器
- **网页截图和PDF生成**：高质量的输出能力
- **网络请求拦截和修改**：可以监控和修改网络请求
- **性能分析**：获取页面加载性能数据
- **支持现代Web特性**：完全支持JavaScript渲染的页面

## 2. 安装与基本使用

### 安装
```bash
npm install puppeteer
# 或者使用轻量版(不自动下载Chromium)
npm install puppeteer-core
```

### 基本示例
```javascript
const puppeteer = require('puppeteer');

(async () => {
  // 启动浏览器
  const browser = await puppeteer.launch();
  // 打开新页面
  const page = await browser.newPage();
  // 导航到URL
  await page.goto('https://example.com');
  // 截图
  await page.screenshot({ path: 'example.png' });
  // 关闭浏览器
  await browser.close();
})();
```

## 3. 主要API功能

### 浏览器操作
```javascript
// 启动浏览器，可配置选项
const browser = await puppeteer.launch({
  headless: false,  // 显示浏览器界面
  slowMo: 50,      // 减慢操作速度，便于观察
  args: ['--no-sandbox', '--disable-setuid-sandbox'] // 沙箱配置
});

// 创建新页面
const page = await browser.newPage();

// 设置视口大小
await page.setViewport({ width: 1280, height: 800 });

// 关闭浏览器
await browser.close();
```

### 页面导航
```javascript
// 跳转到URL
await page.goto('https://example.com', {
  waitUntil: 'networkidle2', // 等待网络空闲
  timeout: 30000            // 超时时间
});

// 后退、前进
await page.goBack();
await page.goForward();

// 刷新页面
await page.reload();
```

### 元素操作
```javascript
// 点击元素
await page.click('#submit-button');

// 输入文本
await page.type('#username', 'myusername');

// 获取元素文本
const text = await page.$eval('.title', el => el.textContent);

// 获取多个元素
const links = await page.$$eval('a', anchors => 
  anchors.map(a => a.href)
);

// 上传文件
const input = await page.$('input[type="file"]');
await input.uploadFile('/path/to/file');
```

### 表单处理
```javascript
// 填写并提交表单
await page.type('#username', 'admin');
await page.type('#password', 'password');
await page.click('#submit');

// 选择下拉框选项
await page.select('#country', 'china');
```

### 等待机制
```javascript
// 等待元素出现
await page.waitForSelector('#results');

// 等待XPath元素
await page.waitForXPath('//div[contains(@class, "result")]');

// 等待函数返回true
await page.waitForFunction(
  'document.querySelector("body").innerText.includes("Done")'
);

// 等待导航完成
await Promise.all([
  page.waitForNavigation(),
  page.click('a') // 点击会触发导航
]);

// 等待超时
await page.waitForTimeout(1000); // 等待1秒
```

### 截图和PDF
```javascript
// 截取整个页面
await page.screenshot({
  path: 'fullpage.png',
  fullPage: true
});

// 截取特定区域
await page.screenshot({
  path: 'element.png',
  clip: { x: 10, y: 10, width: 100, height: 100 }
});

// 生成PDF
await page.pdf({
  path: 'page.pdf',
  format: 'A4'
});
```

## 4. 高级功能

### 网络请求拦截
```javascript
await page.setRequestInterception(true);
page.on('request', request => {
  // 阻止图片请求
  if (request.resourceType() === 'image') {
    request.abort();
  } else {
    request.continue();
  }
});
```

### 执行JavaScript
```javascript
// 在页面上下文中执行代码
const dimensions = await page.evaluate(() => {
  return {
    width: document.documentElement.clientWidth,
    height: document.documentElement.clientHeight
  };
});

// 传递参数到页面上下文
const result = await page.evaluate((x, y) => {
  return window.computeSomething(x, y);
}, 10, 20);
```

### 处理弹窗
```javascript
// 监听对话框事件
page.on('dialog', async dialog => {
  console.log(dialog.message());
  await dialog.dismiss(); // 或 accept()
});
```

### 多页面和iframe
```javascript
// 获取所有页面
const pages = await browser.pages();

// 处理iframe
const frame = page.frames().find(f => f.name() === 'myframe');
await frame.click('#button-in-frame');
```

### 设备模拟
```javascript
const devices = require('puppeteer/DeviceDescriptors');
await page.emulate(devices['iPhone X']);
```

### 性能分析
```javascript
// 启用性能跟踪
await page.tracing.start({ path: 'trace.json' });
await page.goto('https://example.com');
await page.tracing.stop();

// 获取性能指标
const metrics = await page.metrics();
console.log(metrics);
```

## 5. 实战技巧

### 处理登录
```javascript
await page.goto('https://example.com/login');
await page.type('#username', 'user');
await page.type('#password', 'pass');
await page.click('#submit');
await page.waitForNavigation();
// 保存cookies
const cookies = await page.cookies();
fs.writeFileSync('cookies.json', JSON.stringify(cookies));

// 后续会话恢复cookies
const cookies = JSON.parse(fs.readFileSync('cookies.json'));
await page.setCookie(...cookies);
```

### 避免检测
```javascript
const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
puppeteer.use(StealthPlugin());

(async () => {
  const browser = await puppeteer.launch({ headless: false });
  const page = await browser.newPage();
  
  // 覆盖navigator.webdriver属性
  await page.evaluateOnNewDocument(() => {
    Object.defineProperty(navigator, 'webdriver', {
      get: () => false
    });
  });
  
  await page.goto('https://example.com');
})();
```

### 分布式爬虫
```javascript
// 使用puppeteer-cluster进行并行处理
const { Cluster } = require('puppeteer-cluster');

(async () => {
  const cluster = await Cluster.launch({
    concurrency: Cluster.CONCURRENCY_CONTEXT,
    maxConcurrency: 4, // 4个浏览器实例并行
    puppeteerOptions: { headless: true }
  });

  await cluster.task(async ({ page, data: url }) => {
    await page.goto(url);
    const title = await page.title();
    console.log(title);
  });

  // 添加任务
  cluster.queue('http://example.com/page1');
  cluster.queue('http://example.com/page2');
  
  await cluster.idle();
  await cluster.close();
})();
```

## 6. 调试技巧

### 调试模式
```javascript
const browser = await puppeteer.launch({
  headless: false,
  devtools: true  // 自动打开开发者工具
});
```

### 慢动作模式
```javascript
const browser = await puppeteer.launch({
  headless: false,
  slowMo: 250  // 每个操作延迟250ms
});
```

### 控制台输出
```javascript
// 监听console事件
page.on('console', msg => {
  console.log('浏览器控制台:', msg.text());
});

// 在页面上下文中输出
await page.evaluate(() => console.log('页面中的消息'));
```

## 7. 常见问题解决

### 处理超时
```javascript
try {
  await page.waitForSelector('#element', { timeout: 5000 });
} catch (e) {
  console.log('元素未在5秒内出现');
}
```

### 处理元素不可点击
```javascript
await page.evaluate(selector => {
  document.querySelector(selector).scrollIntoView();
}, '#button');
await page.click('#button');
```

### 处理页面卡死
```javascript
// 设置全局超时
page.setDefaultTimeout(30000);

// 使用Promise.race实现超时
await Promise.race([
  page.click('#button'),
  new Promise((_, reject) => 
    setTimeout(() => reject(new Error('Timeout')), 5000)
  )
]);
```

## 8. 性能优化

### 禁用不必要的内容
```javascript
await page.setRequestInterception(true);
page.on('request', request => {
  // 阻止图片、样式表、字体等
  if (['image', 'stylesheet', 'font'].includes(request.resourceType())) {
    request.abort();
  } else {
    request.continue();
  }
});
```

### 复用浏览器实例
```javascript
// 启动时
const browser = await puppeteer.launch();

// 每次任务
const page = await browser.newPage();
// ...执行任务...
await page.close();  // 不关闭browser

// 最后关闭
await browser.close();
```

### 内存管理
```javascript
// 定期清理页面
for (let i = 0; i < 10; i++) {
  const page = await browser.newPage();
  // ...使用页面...
  await page.close();
}
```

## 9. 生态系统扩展

### 常用插件
- `puppeteer-extra` - 增强版Puppeteer
- `puppeteer-extra-plugin-stealth` - 反检测
- `puppeteer-cluster` - 集群管理
- `puppeteer-recorder` - 录制操作

### 替代方案
- Playwright (微软开发，支持多浏览器)
- Cypress (专注于测试)
- Selenium (更传统的WebDriver方案)

## 10. 最佳实践

1. **错误处理**：始终使用try-catch处理异步操作
2. **资源清理**：确保关闭页面和浏览器实例
3. **可配置性**：将选择器和URL等提取为配置
4. **日志记录**：记录关键操作和错误
5. **速率限制**：避免对目标服务器造成过大压力

Puppeteer是一个功能强大且灵活的工具，适用于从简单自动化到复杂爬虫的各种场景。通过合理使用其API和生态系统扩展，可以构建出高效可靠的浏览器自动化解决方案。
