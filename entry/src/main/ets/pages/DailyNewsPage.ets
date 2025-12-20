import { NewsManager } from '../utils/NewsManager';
import { NewsItem } from '../model/NewsModel';
import { promptAction } from '@kit.ArkUI';

@Component
export struct DailyNewsPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @State newsList: NewsItem[] = [];
  @State isLoading: boolean = true;
  @State isError: boolean = false;

  async aboutToAppear() {
    await this.fetchNews();
  }

  async fetchNews() {
    this.isLoading = true;
    this.isError = false;
    const data = await NewsManager.getDailyNews();
    if (data.length > 0) {
      this.newsList = data;
    } else {
      this.isError = true;
    }
    this.isLoading = false;
  }

  build() {
    NavDestination() {
      Column() {
        // --- [修复] 顶部栏：标准样式 ---
        Row() {
          Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([Color.Black]) }
          .backgroundColor(Color.Transparent).width(48).height(48).onClick(() => this.pageStack.pop())
          Text('每日新闻').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 4 })
        }.width('100%').padding({ top: 40, left: 16, right: 16, bottom: 10 }).alignItems(VerticalAlign.Center)

        // --- 内容区域 ---
        if (this.isLoading) {
          Column() {
            LoadingProgress().width(50).height(50).color('#0A59F7')
            Text('Updating...').fontSize(14).fontColor('#999').margin({ top: 10 })
          }.layoutWeight(1).justifyContent(FlexAlign.Center)

        } else if (this.isError) {
          Column() {
            Image($r('sys.media.ohos_ic_public_fail')).width(60).height(60).fillColor('#CCC')
            Text('Failed to load news.').fontSize(14).fontColor('#999').margin({ top: 10 })
            Button('Retry').margin({ top: 20 }).onClick(() => this.fetchNews())
          }.layoutWeight(1).justifyContent(FlexAlign.Center)

        } else {
          List() {
            ForEach(this.newsList, (item: NewsItem) => {
              ListItem() {
                Column({ space: 10 }) {
                  if (item.picUrl) {
                    Image(item.picUrl).width('100%').height(180).borderRadius(12).objectFit(ImageFit.Cover).backgroundColor('#F5F5F5')
                  }
                  Text(item.title || 'No Title').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1A1A1A').lineHeight(24)
                  Text(item.description || 'No Description').fontSize(14).fontColor('#666').lineHeight(20).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
                  Row() {
                    Text(item.source || 'China Daily').fontSize(12).fontColor('#0A59F7').fontWeight(FontWeight.Medium)
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
                if (item.url) {
                  this.pageStack.pushPath({ name: 'NewsWebPage', param: item.url });
                } else {
                  promptAction.showToast({ message: '无效的链接' });
                }
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