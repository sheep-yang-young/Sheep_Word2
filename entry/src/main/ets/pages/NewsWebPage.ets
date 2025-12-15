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
          Image($r('sys.media.ohos_ic_public_arrow_left'))
            .width(24).height(24)
            .onClick(() => {
              if (this.webviewController.accessBackward()) {
                this.webviewController.backward();
              } else {
                this.pageStack.pop();
              }
            })
          Text('新闻详情')
            .fontSize(18).fontWeight(FontWeight.Bold).margin({ left: 12 })
          Blank()

          // [修复] 将 Image 改为 SymbolGlyph，避免资源报错
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(24)
            .fontColor(['#333'])
            .onClick(() => this.webviewController.refresh())
        }
        .width('100%').padding(16).backgroundColor(Color.White)
        .border({ width: { bottom: 1 }, color: '#E5E7EB' })

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