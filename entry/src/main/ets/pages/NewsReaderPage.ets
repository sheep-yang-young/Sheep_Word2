import { webview } from '@kit.ArkWeb';
import { NewsItem } from '../model/NewsModel';

@Builder
export function NewsReaderPageBuilder() {
  NewsReaderPage()
}

@Component
export struct NewsReaderPage {
  @Consume('pageStack') pageStack: NavPathStack;
  private newsItem: NewsItem | null = null;
  private webController: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    // 获取传递过来的新闻对象
    const params = this.pageStack.getParamByName("NewsReaderPage") as NewsItem[];
    if (params && params.length > 0) {
      this.newsItem = params[0];
      console.info('ReaderPage received content length:', this.newsItem.content?.length);
    }
  }

  // 构建优雅的阅读器 HTML
  private buildHtml(item: NewsItem): string {
    return `
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            line-height: 1.8;
            color: #333;
            padding: 20px;
            margin: 0;
            background-color: #fff;
          }
          h1 {
            font-size: 24px;
            font-weight: 800;
            margin-bottom: 10px;
            line-height: 1.3;
            color: #111;
          }
          .meta {
            font-size: 13px;
            color: #999;
            margin-bottom: 25px;
            display: flex;
            justify-content: space-between;
          }
          .source {
            font-weight: 600;
            color: #0A59F7;
          }
          img {
            max-width: 100%;
            height: auto;
            border-radius: 8px;
            margin: 15px 0;
            box-shadow: 0 4px 12px rgba(0,0,0,0.05);
          }
          p {
            margin-bottom: 16px;
            font-size: 17px;
            text-align: justify;
          }
          /* 去掉RSS内容中可能带有的内联样式干扰 */
          * { max-width: 100% !important; }
        </style>
      </head>
      <body>
        <h1>${item.title}</h1>
        <div class="meta">
          <span class="source">${item.source}</span>
          <span class="date">${item.date}</span>
        </div>
        <div class="content">
          ${item.content}
        </div>
      </body>
      </html>
    `;
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

          Text('Reading Mode')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .margin({ left: 4 })
            .layoutWeight(1) // 占满剩余空间
            .textAlign(TextAlign.Center) // 居中
            .padding({ right: 48 }) // 视觉居中修正

        }
        .width('100%')
        .padding({ top: 40, left: 16, right: 16, bottom: 10 })
        .alignItems(VerticalAlign.Center)
        .backgroundColor(Color.White)

        // --- 内容区域 ---
        if (this.newsItem) {
          Web({ src: '', controller: this.webController })
            .width('100%')
            .layoutWeight(1)
            .onControllerAttached(() => {
              // 核心：注入我们构建的精美 HTML
              this.webController.loadData(
                this.buildHtml(this.newsItem!),
                'text/html',
                'UTF-8'
              );
            })
        } else {
          // 错误处理
          Column() {
            Text("无法加载文章内容").fontColor(Color.Gray)
          }.layoutWeight(1).justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
    }
    .hideTitleBar(true)
  }
}