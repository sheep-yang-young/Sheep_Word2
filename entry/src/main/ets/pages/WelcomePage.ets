import { PreferenceManager } from '../utils/PreferenceManager';

@Component
export struct WelcomePage {
  // 回调函数
  onFinish: () => void = () => {};

  // [新增] 页面控制器和索引状态
  private swiperController: SwiperController = new SwiperController();
  @State currentIndex: number = 0;
  private totalPages: number = 3; // 总页数

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 绑定控制器
      Swiper(this.swiperController) {
        // 第 1 页
        this.GuideItem(
          '极简设计',
          '告别繁杂，回归纯粹。\n专注于记忆本身，享受心流体验。',
          '#0A59F7'
        )
        // 第 2 页
        this.GuideItem(
          '科学记忆',
          '内置 SM-2 记忆算法。\n根据你的遗忘曲线智能安排复习。',
          '#10B981'
        )
        // 第 3 页
        this.GuideItem(
          '禅定模式',
          '独创 Zen Mode。\n跟随呼吸节奏，潜意识沉浸式学习。',
          '#722ED1'
        )
      }
      .width('100%')
      .height('100%')
      .loop(false) // 禁止循环滑动
      .indicator(true)
      .curve(Curve.EaseInOut)
      // [新增] 监听滑动事件，更新索引
      .onChange((index: number) => {
        this.currentIndex = index;
      })

      // [修改] 动态按钮：没到最后一页显示"下一步"，到了显示"开始"
      Button(this.currentIndex === this.totalPages - 1 ? '开始旅程' : '下一步')
        .width('80%')
        .height(50)
        .backgroundColor('#1A1A1A')
        .fontColor(Color.White)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 50 })
        .onClick(async () => {
          if (this.currentIndex < this.totalPages - 1) {
            // 如果不是最后一页，滑到下一页
            this.swiperController.showNext();
          } else {
            // 是最后一页，完成引导
            await PreferenceManager.getInstance().setFirstLaunch(false);
            if (this.onFinish) {
              this.onFinish();
            }
          }
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }

  @Builder GuideItem(title: string, desc: string, color: string) {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Circle({ width: 200, height: 200 })
          .fill(color)
          .opacity(0.1)

        Text(title.substring(0, 1))
          .fontSize(80)
          .fontWeight(FontWeight.Bold)
          .fontColor(color)
      }
      .margin({ top: 150, bottom: 50 })

      Text(title)
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
        .margin({ bottom: 16 })

      Text(desc)
        .fontSize(16)
        .fontColor('#666')
        .textAlign(TextAlign.Center)
        .lineHeight(24)
        .padding({ left: 40, right: 40 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }
}