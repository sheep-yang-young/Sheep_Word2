import { ArticleManager } from '../utils/ArticleManager';
import { NewsItem } from '../model/NewsModel';
import { common } from '@kit.AbilityKit'; // 确保引入 common

@Component
export struct DailyNewsPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @State articleList: NewsItem[] = [];
  @State isLoading: boolean = true;

  async aboutToAppear(): Promise<void> {
    this.isLoading = true;

    // [修复] 获取 context 并传递给 ArticleManager
    // 请确保这里 context 被正确传入了 getClassicArticles 方法中
    const context = getContext(this) as common.UIAbilityContext;
    const data = await ArticleManager.getClassicArticles(context);

    setTimeout(() => {
      this.articleList = data;
      this.isLoading = false;
    }, 300);
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([Color.Black])
          }
          .backgroundColor(Color.Transparent)
          .width(48)
          .height(48)
          .onClick(() => this.pageStack.pop())

          Text('经典晨读')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .margin({ left: 4 })

          Blank()
        }
        .width('100%')
        .padding({ top: 40, left: 16, right: 16, bottom: 10 })
        .alignItems(VerticalAlign.Center)

        if (this.isLoading) {
          Column() {
            LoadingProgress().width(50).height(50).color('#0A59F7')
          }.layoutWeight(1).justifyContent(FlexAlign.Center)
        } else {
          List() {
            ForEach(this.articleList, (item: NewsItem) => {
              ListItem() {
                Column({ space: 10 }) {
                  Text(item.title)
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#1A1A1A')
                    .lineHeight(24)

                  Text(item.description)
                    .fontSize(14)
                    .fontColor('#666')
                    .lineHeight(20)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Row() {
                    Text(item.source || 'Classic').fontSize(12).fontColor('#0A59F7').fontWeight(FontWeight.Medium)
                    Blank()
                    Text(item.date).fontSize(12).fontColor('#999')
                  }.width('100%').margin({ top: 4 })
                }
                .padding(16)
                .backgroundColor(Color.White)
                .borderRadius(16)
                .shadow({ radius: 8, color: 'rgba(0,0,0,0.05)', offsetY: 2 })
                .margin({ bottom: 16, left: 16, right: 16 })
              }
              .onClick(() => {
                this.pageStack.pushPath({ name: 'NewsReaderPage', param: item });
              })
            }, (item: NewsItem) => item.id)
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ top: 10, bottom: 20 })
        }
      }
      .width('100%').height('100%').backgroundColor('#F5F7FA')
    }
    .hideTitleBar(true)
  }
}