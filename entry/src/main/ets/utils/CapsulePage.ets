import { FloatingCapsuleManager } from '../utils/FloatingCapsuleManager';

@Entry
@Component
struct CapsulePage {
  @State isBusy: boolean = false;

  build() {
    Stack() {
      // 胶囊主体
      Row() {
        // 左侧图标/状态
        if (this.isBusy) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color('#FFFFFF')
            .margin({ right: 6 })
        } else {
          // 简单的“图片”图标示意
          Text('📷')
            .fontSize(16)
            .margin({ right: 6 })
        }

        // 右侧文字
        Text(this.isBusy ? '识别中' : '选图')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#34495E') // 深色背景，护眼
      .borderRadius(25) // 全圆角
      .shadow({ radius: 8, color: 'rgba(0,0,0,0.4)', offsetY: 4 }) // 悬浮阴影
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .onClick(async () => {
        if (this.isBusy) return;

        this.isBusy = true;
        // 调用 Manager 里的方法
        const count = await FloatingCapsuleManager.getInstance().triggerImageImport();
        this.isBusy = false;

        // 可选：这里虽然不能弹 Toast，但可以在控制台看结果
        console.info(`成功导入 ${count} 个单词`);
      })
    }
    .width('100%')
    .height('100%')
  }
}