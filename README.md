# 小肥鱼下载器 iOS（SwiftUI）

Android 端的 iOS 原生移植骨架，覆盖：
- 四平台链接识别（抖音 / 快手 / 小红书 / B站）
- B站 wbi 签名 + DASH 4K/8K 解析
- 抖音详情接口 + 图集 / 实况 / 最高码率
- URLSession Cookie 拦截器（用户 SESSDATA 优先，内置兜底）
- AVFoundation 无损合轨、纯音频导出
- PHPhotoLibrary 写入原生 Live Photo
- SwiftUI 毛玻璃 UI、WKWebView 登录抓 SESSDATA、剪贴板悬浮条

## 构建
1. Mac 安装 Xcode 15+。
2. `brew install xcodegen`，在本目录执行 `xcodegen generate`。
3. 打开 `XiaoFeiYu.xcodeproj`，选择自己的 Team 与真机。
4. 免费 Apple ID 只能自己装；上架/分发需要 $99/年 开发者账号。

## 注意
- `BiliSession.defaultSessdata` 默认留空，填入自己的大会员 SESSDATA 后才会启用内置兜底。
- 后台下载受 iOS 限制：URLSession background 可以继续下载，但合轨/写相册必须回前台。
- 保存 Live Photo 需要 `.photo` + `.pairedVideo` 两个资源，且视频建议为 MOV。
