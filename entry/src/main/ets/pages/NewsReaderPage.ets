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
    const params = this.pageStack.getParamByName("NewsReaderPage") as NewsItem[];
    if (params && params.length > 0) {
      this.newsItem = params[0];
    }
  }

  private buildHtml(item: NewsItem): string {
    // 构建响应式 HTML，优化阅读体验
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
            padding: 24px 20px;
            margin: 0;
            background-color: #fff;
            word-wrap: break-word;
          }
          h1 {
            font-size: 26px;
            font-weight: 800;
            margin-bottom: 12px;
            line-height: 1.4;
            color: #111;
          }
          .meta {
            font-size: 13px;
            color: #999;
            margin-bottom: 30px;
            display: flex;
            align-items: center;
          }
          .source {
            font-weight: 600;
            color: #0A59F7;
            margin-right: 12px;
          }
          img {
            max-width: 100% !important;
            height: auto !important;
            border-radius: 12px;
            margin: 20px 0;
            box-shadow: 0 4px 12px rgba(0,0,0,0.08);
            display: block;
          }
          p {
            margin-bottom: 20px;
            font-size: 17px;
            text-align: justify;
            color: #444;
          }
          /* 针对 RSS 可能存在的脏数据进行清洗 */
          iframe, video { max-width: 100%; }
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
        // 顶部导航栏
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
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .padding({ right: 48 }) // 视觉居中修正
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .backgroundColor(Color.White)
        .shadow({ radius: 2, color: 'rgba(0,0,0,0.05)', offsetY: 1 })
        .zIndex(1)

        // Web 阅读器
        if (this.newsItem) {
          Web({ src: '', controller: this.webController })
            .width('100%')
            .layoutWeight(1)
            .domStorageAccess(true) // 开启 DOM 存储，防止部分样式解析失败
            .javaScriptAccess(true) // 允许 JS，防止图片懒加载失效
            .onControllerAttached(() => {
              try {
                // 【核心修复】必须传入 baseUrl 和 historyUrl ("about:blank")
                // 否则 Web 组件可能认为这是不安全的跨域内容而拒绝渲染
                this.webController.loadData(
                  this.buildHtml(this.newsItem!),
                  'text/html',
                  'UTF-8',
                  'about:blank',
                  'about:blank'
                );
              } catch (e) {
                console.error('Web loadData failed:', JSON.stringify(e));
              }
            })
        } else {
          Column() {
            SymbolGlyph($r('sys.symbol.info_circle')).fontSize(48).fontColor(['#DDD'])
            Text("文章内容加载失败").fontSize(14).fontColor(Color.Gray).margin({ top: 12 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
    }
    .hideTitleBar(true)
  }
}