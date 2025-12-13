import { common } from '@kit.AbilityKit';

@Component
export struct AboutPage {
  @Consume('pageStack') pageStack: NavPathStack;

  build() {
    NavDestination() {
      Column() {
        // 1. 顶部导航栏
        Row() {
          Image($r('sys.media.ohos_ic_public_arrow_left'))
            .width(24).height(24).fillColor('#1A1A1A')
            .onClick(() => { this.pageStack.pop() })

          Blank()

          Text('关于应用')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')

          // 右侧占位，保证标题居中
          Blank().width(24)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 10, bottom: 10 })

        // 2. 主体内容
        Column({ space: 20 }) {
          // Logo 区域
          Image($r('app.media.icon'))
            .width(100).height(100) //稍微放大一点 Logo
            .borderRadius(24)
            .margin({ top: 80 }) // [修改] 增加顶部距离，视觉下移
            .fillColor('#0A59F7')
            .backgroundColor('#F0F2F5')

          Text('Lumina Word')
            .fontSize(26).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')

          Text('Version 1.0.0')
            .fontSize(14).fontColor('#999')
            .padding({ left: 16, right: 16, top: 6, bottom: 6 })
            .backgroundColor('#F5F7FA')
            .borderRadius(16)

          // 介绍文本
          Text('Lumina 是一款基于 SM-2 记忆曲线算法的极简背单词应用。\n\n我们致力于通过沉浸式的设计与科学的复习机制，帮助你高效掌握词汇。没有广告，没有打扰，只为专注。')
            .fontSize(16)
            .fontColor('#666')
            .lineHeight(28) // 增加行高，提升阅读体验
            .textAlign(TextAlign.Center)
            .padding({ left: 40, right: 40, top: 20 })

          Blank()

          // 底部版权
          Column() {
            Text('Designed with ❤').fontSize(12).fontColor('#CCC')
            Text('for HarmonyOS').fontSize(12).fontColor('#CCC').margin({ top: 4 })
          }
          .margin({ bottom: 60 })
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
      .padding({ top: 48 }) // [核心修复] 整体下移，避开状态栏
    }
    .hideTitleBar(true)
  }
}