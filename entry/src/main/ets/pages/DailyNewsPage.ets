import { NewsManager } from '../utils/NewsManager';
import { NewsItem } from '../model/NewsModel';
import { promptAction } from '@kit.ArkUI';

@Component
export struct DailyNewsPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @State newsList: NewsItem[] = [];
  @State isLoading: boolean = true;
  @State isError: boolean = false;

  async aboutToAppear(): Promise<void> {
    await this.fetchNews();
  }

  // [修复1] 显式声明返回类型 Promise<void>，解决编译器推断报错
  async fetchNews(): Promise<void> {
    // 只有当列表为空时才显示全屏加载动画，避免下拉刷新时闪烁
    if (this.newsList.length === 0) {
      this.isLoading = true;
    }

    this.isError = false;
    const data = await NewsManager.getDailyNews();

    if (data && data.length > 0) {
      this.newsList = data;
    } else {
      this.isError = true;
    }

    this.isLoading = false;
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

          Text('每日新闻')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .margin({ left: 4 })

          Blank()

          // 右上角手动刷新按钮
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize(20).fontColor([Color.Black])
          }
          .backgroundColor(Color.Transparent)
          .width(40)
          .height(40)
          .onClick(() => {
            this.newsList = []; // 清空列表以触发 Loading 效果
            this.fetchNews();
          })
        }
        .width('100%')
        .padding({ top: 40, left: 16, right: 16, bottom: 10 })
        .alignItems(VerticalAlign.Center)

        // --- 内容区域 ---

        // 1. 首次加载 Loading (全屏)
        if (this.isLoading && this.newsList.length === 0) {
          Column() {
            LoadingProgress().width(50).height(50).color('#0A59F7')
            Text('正在获取最新新闻...').fontSize(14).fontColor('#999').margin({ top: 10 })
          }.layoutWeight(1).justifyContent(FlexAlign.Center)

          // 2. 错误页 (全屏)
        } else if (this.isError && this.newsList.length === 0) {
          Column() {
            SymbolGlyph($r('sys.symbol.exclamationmark_circle')).fontSize(60).fontColor(['#CCC'])
            Text('无法连接到服务器').fontSize(14).fontColor('#999').margin({ top: 10 })
            Button('重试')
              .margin({ top: 20 })
              .onClick(() => this.fetchNews())
              .backgroundColor('#0A59F7')
          }.layoutWeight(1).justifyContent(FlexAlign.Center)

          // 3. 新闻列表 (带下拉刷新)
        } else {
          // [修复2] 使用 Refresh 组件包裹 List，这是 ArkUI 实现下拉刷新的标准方式
          Refresh({ refreshing: $$this.isLoading }) {
            List() {
              ForEach(this.newsList, (item: NewsItem) => {
                ListItem() {
                  Column({ space: 10 }) {
                    if (item.picUrl) {
                      Image(item.picUrl)
                        .width('100%')
                        .height(180)
                        .borderRadius(12)
                        .objectFit(ImageFit.Cover)
                        .backgroundColor('#F5F5F5')
                        .onError(() => {
                          console.warn('Image load failed:' + item.picUrl);
                        })
                    }
                    Text(item.title || '无标题').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1A1A1A').lineHeight(24)
                    Text(item.description || '无描述').fontSize(14).fontColor('#666').lineHeight(20).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
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
                  // 不再检查 url，直接传递整个 item 给阅读器
                  this.pageStack.pushPath({ name: 'NewsReaderPage', param: item });
                })
              }, (item: NewsItem) => item.id)
            }
            .width('100%')
            .layoutWeight(1)
            .padding({ top: 10, bottom: 20 })
          }
          .onRefreshing(() => {
            // 下拉触发刷新
            this.fetchNews();
          })
        }
      }
      .width('100%').height('100%').backgroundColor('#F5F7FA')
    }
    .hideTitleBar(true)
  }
}