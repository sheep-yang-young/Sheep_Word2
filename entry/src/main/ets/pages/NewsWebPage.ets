import { webview } from '@kit.ArkWeb';

@Component
export struct NewsWebPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @State url: string = '';
  @State isLoading: boolean = true;
  webviewController: webview.WebviewController = new webview.WebviewController();

  build() {
    NavDestination() {
      Column() {
        Row() {
          Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([Color.Black]) }
          .backgroundColor(Color.Transparent).width(48).height(48).onClick(() => this.pageStack.pop())
          Text('China Daily').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 4 })
        }.width('100%').padding({ top: 40, left: 16, right: 16, bottom: 10 }).alignItems(VerticalAlign.Center)

        Stack() {
          Web({ src: this.url, controller: this.webviewController })
            .width('100%').height('100%')
            .javaScriptAccess(true)
            .domStorageAccess(true)
            .onPageBegin(() => { this.isLoading = true })
            .onPageEnd(() => { this.isLoading = false })
            .onErrorReceive((e) => {
              console.error(`Web Error: ${JSON.stringify(e)}`)
            })

          if (this.isLoading) {
            LoadingProgress().width(50).height(50).color('#0A59F7')
          }
        }
        .layoutWeight(1).width('100%')
      }
      .width('100%').height('100%')
    }
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.url = context.pathInfo.param as string;
    })
  }
}