import { CloudBook, CloudBookManager } from '../utils/CloudBookManager';
import { WordImporter } from '../utils/WordImporter';
import { PreferenceManager } from '../utils/PreferenceManager';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';

@Component
export struct StorePage {
  @Consume('pageStack') pageStack: NavPathStack;
  @Consume refreshFlag: number;

  @State books: CloudBook[] = [];
  @State isLoading: boolean = true;
  @State isCodeMode: boolean = false;

  async aboutToAppear() {
    this.isCodeMode = await PreferenceManager.getInstance().isProgrammingMode();
    this.loadBooks();
  }

  async loadBooks() {
    this.isLoading = true;
    const allBooks = await CloudBookManager.getManifest();

    // 🎯 核心逻辑：根据当前模式过滤书单
    const targetCategory = this.isCodeMode ? 'Code' : 'English';
    this.books = allBooks.filter(b => b.category === targetCategory);

    this.isLoading = false;
  }

  async downloadAndImport(book: CloudBook) {
    try {
      promptAction.showToast({ message: `正在下载 ${book.name}...` });

      const context = getContext(this) as common.UIAbilityContext;
      // 1. 下载
      const filePath = await CloudBookManager.downloadBook(book.category, book.id, context);

      if (filePath) {
        promptAction.showToast({ message: '下载完成，正在导入数据库...' });

        // 2. 导入 (现在 WordImporter 已经修复了)
        const count = await WordImporter.importJsonFileFromPath(context, filePath, book.name);

        if (count > 0) {
          // 3. 自动切换到这本书
          const pref = PreferenceManager.getInstance();
          await pref.registerBookCategory(book.name, book.category);
          const isCodeMode = await pref.setCurrentBook(book.name);
          this.refreshFlag++; // 刷新首页
          promptAction.showDialog({
            title: '导入成功',
            message: `已导入 ${count} 条数据到《${book.name}》，并已设为当前词书。${isCodeMode ? '\n编程模式已同步开启。' : ''}`,
            buttons: [{ text: '去背诵', color: '#0A59F7' }]
          }).then(() => {
            this.pageStack.pop(); // 返回上一页
          });
        }
      } else {
        promptAction.showToast({ message: '下载失败，请检查服务器日志' });
      }
    } catch (e) {
      console.error('Import failed', e);
      promptAction.showToast({ message: '导入出错' });
    }
  }

  build() {
    NavDestination() {
      Column() {
        // 标题栏
        Row() {
          Image($r('sys.media.ohos_ic_public_arrow_left')).width(24).height(24).fillColor('#1A1A1A').onClick(() => this.pageStack.pop())
          Blank()
          Text(this.isCodeMode ? 'Dev Store (云端仓库)' : 'Cloud Library (云端书库)')
            .fontSize(18).fontWeight(FontWeight.Bold)
            .fontFamily(this.isCodeMode ? 'Monospace' : '')
          Blank().width(24)
        }.width('100%').padding(20)

        if (this.isLoading) {
          LoadingProgress().width(50).height(50).color('#0A59F7').margin({ top: 100 })
        } else if (this.books.length === 0) {
          Column({ space: 10 }) {
            // 使用通用的错误/警告图标
            Image($r('sys.media.ohos_ic_public_fail')).width(60).height(60).fillColor('#CCC')
            Text('暂无相关书籍').fontColor('#999')
            Button('刷新').onClick(() => this.loadBooks()).height(30).backgroundColor('#F0F2F5').fontColor('#333')
          }.margin({ top: 100 })
        } else {
          List({ space: 12 }) {
            ForEach(this.books, (book: CloudBook) => {
              ListItem() {
                Row() {
                  // [修复] 使用存在的系统图标
                  Image(book.category === 'Code' ? $r('sys.media.ohos_ic_public_paste') : $r('sys.media.ohos_ic_public_paste'))
                    .width(40).height(40)
                    .fillColor(this.isCodeMode ? '#0A59F7' : '#FFB02E')
                    .padding(8)
                    .backgroundColor(this.isCodeMode ? '#E8F1FF' : '#FFF7E6')
                    .borderRadius(12)

                  Column({ space: 4 }) {
                    Text(book.name)
                      .fontSize(16).fontWeight(FontWeight.Medium)
                      .fontColor('#1A1A1A')
                      .fontFamily(this.isCodeMode ? 'Monospace' : '')
                    Text(book.desc)
                      .fontSize(12).fontColor('#999').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  }.alignItems(HorizontalAlign.Start).layoutWeight(1).margin({ left: 12 })

                  Button('GET')
                    .height(28)
                    .fontSize(12)
                    .backgroundColor(this.isCodeMode ? '#1E1E1E' : '#0A59F7')
                    .onClick(() => this.downloadAndImport(book))
                }
                .width('100%').padding(16).backgroundColor(Color.White).borderRadius(16)
              }
            })
          }.layoutWeight(1).padding({ left: 20, right: 20 })
        }
      }
      .width('100%').height('100%').backgroundColor('#F5F7FA')
    }.hideTitleBar(true)
  }
}