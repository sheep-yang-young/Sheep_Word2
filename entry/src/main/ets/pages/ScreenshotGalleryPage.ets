import { promptAction, router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { FloatingCapsuleManager } from '../utils/FloatingCapsuleManager';
import { SavedScreenshotInfo, ScreenshotManager } from '../utils/ScreenshotManager';
import { ScreenshotFlow } from '../utils/ScreenshotFlow';

@Entry
@Component
export struct ScreenshotGalleryPage {
  @State items: SavedScreenshotInfo[] = [];
  @State loading: boolean = false;
  @State recognizingPath: string = '';

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    ScreenshotManager.getInstance().init(ctx);
    FloatingCapsuleManager.getInstance().init(ctx);
    this.refreshList();

    const pendingPath = ScreenshotFlow.consumePendingPath();
    const shouldAuto = ScreenshotFlow.consumeAutoRecognize();
    if (pendingPath) {
      this.recognize(pendingPath, shouldAuto);
    }
  }

  private async refreshList(): Promise<void> {
    const list = await ScreenshotManager.getInstance().getAll();
    list.sort((a, b) => b.createdAt - a.createdAt);
    this.items = list;
  }

  private formatTime(ts: number): string {
    const d = new Date(ts);
    return `${d.getFullYear()}-${(d.getMonth() + 1).toString().padStart(2, '0')}-${d.getDate().toString().padStart(2, '0')} ${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`;
  }

  private async recognize(path: string, autoNavigate: boolean = true): Promise<void> {
    if (!path) return;
    this.loading = true;
    this.recognizingPath = path;

    const count = await FloatingCapsuleManager.getInstance().triggerImportFromFile(path);
    this.loading = false;

    if (count > 0) {
      promptAction.showToast({ message: `识别到 ${count} 个候选词` });
      if (autoNavigate) {
        router.pushUrl({ url: 'pages/CapsuleImportPage' });
      }
    } else {
      promptAction.showToast({ message: '未识别到单词，请尝试其他截图' });
    }
  }

  private async remove(item: SavedScreenshotInfo): Promise<void> {
    await ScreenshotManager.getInstance().remove(item.path);
    await this.refreshList();
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Text('截图盒').fontSize(20).fontWeight(FontWeight.Medium).layoutWeight(1);
        Button('刷新').enabled(!this.loading).onClick(() => this.refreshList());
        Button('返回').onClick(() => { try { router.back(); } catch (e) {} });
      }.width('100%').padding({ top: 16, left: 16, right: 16 });

      if (this.items.length <= 0) {
        Column() {
          Text('暂无截图').fontSize(16).fontWeight(FontWeight.Medium).margin({ bottom: 8 });
          Text('点击悬浮球将自动截图并保存到此处').fontSize(13).opacity(0.7).textAlign(TextAlign.Center);
        }.width('100%').height('80%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center);
      } else {
        List({ space: 12 }) {
          ForEach(this.items, (item: SavedScreenshotInfo) => {
            ListItem() {
              Column({ space: 8 }) {
                Image(item.path).width('100%').height(200).objectFit(ImageFit.Cover).borderRadius(12);
                Row() {
                  Column({ space: 4 }) {
                    Text(this.formatTime(item.createdAt)).fontSize(14).fontWeight(FontWeight.Medium);
                    Text(item.path).fontSize(12).opacity(0.6).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis });
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start);

                  Button(this.loading && this.recognizingPath === item.path ? '识别中…' : 'OCR 导入')
                    .enabled(!this.loading)
                    .onClick(() => this.recognize(item.path))
                    .margin({ right: 8 });

                  Button('删除').type(ButtonType.Normal).onClick(() => this.remove(item));
                }.width('100%');
              }
              .padding(12)
              .backgroundColor('#FFFFFF')
              .borderRadius(16)
              .shadow({ radius: 6, color: 'rgba(0,0,0,0.06)', offsetY: 4 });
            }
          }, (item: SavedScreenshotInfo) => `${item.path}_${item.createdAt}`)
        }
        .width('100%')
        .height('85%')
        .padding({ left: 16, right: 16, bottom: 30 })
        .edgeEffect(EdgeEffect.Spring);
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FA');
  }
}
