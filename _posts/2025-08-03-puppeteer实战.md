---
layout: post
title: puppeteer实战
category: [前端]
tags: [爬虫]
image:
 path: assets/img/blog_face/默认封面.png
 alt:
---

##windows平台安装
1. 建立文件夹puppeteer，打开终端并进入此文件夹

2. 执行以下命令
  ```
  npm cache clean --force //清空缓存
  npm config list --json //查看配置

  npm config set registry https://registry.npmmirror.com配置镜像源
  npm install puppeteer
  //或者
  npm install -g cnpm --registry=https://registry.npmmirror.com
  cnpm install puppeteer
  ```
