import { NewsItem } from '../model/NewsModel';

// [修复] 添加路由入口 Builder 函数
@Builder
export function NewsReaderPageBuilder() {
  NewsReaderPage()
}

@Component
export struct NewsReaderPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @State article: NewsItem | null = null;

  aboutToAppear() {
    // [修复] 显式类型断言，解决 "Use explicit types instead of any"
    const params = this.pageStack.getParamByName('NewsReaderPage') as NewsItem[];
    if (params && params.length > 0) {
      this.article = params[params.length - 1];
    }
  }

  build() {
    NavDestination() {
      Column() {
        // --- 顶部栏 ---
        Row() {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([Color.Black])
          }
          .backgroundColor(Color.Transparent)
          .width(48)
          .height(48)
          .onClick(() => this.pageStack.pop())

          Blank()
        }
        .width('100%')
        .padding({ top: 40, left: 16, right: 16, bottom: 0 })

        if (this.article) {
          Scroll() {
            Column({ space: 20 }) {
              // 标题
              Text(this.article.title)
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1A1A1A')
                .lineHeight(32)
                .width('100%')

              // 元数据
              Row() {
                Text(this.article.source).fontSize(14).fontColor('#0A59F7')
                Text(' • ' + this.article.date).fontSize(14).fontColor('#999')
              }.width('100%')

              Divider().color('#EEE').strokeWidth(1)

              // 正文内容
              Text(this.article.content)
                .fontSize(18)
                .fontColor('#333')
                .lineHeight(30)
                .letterSpacing(0.5)
                // [修复] 使用 JUSTIFY (全大写) 或 Start (如果编译器还不认 JUSTIFY，就改 Start)
                // 如果 JUSTIFY 依然报错，请改为 TextAlign.Start
                .textAlign(TextAlign.JUSTIFY)

              // 底部留白
              Blank().height(50)
            }
            .padding(24)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
          .align(Alignment.Top)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
    }
    .hideTitleBar(true)
  }
}