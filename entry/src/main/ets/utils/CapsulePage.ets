import { FloatingCapsuleManager, CapsuleRecognitionResult, CapsuleWordCandidate } from '../utils/FloatingCapsuleManager';
import { DatabaseManager } from './DatabaseManager';

type CapsuleCandidateItem = CapsuleWordCandidate & { selected?: boolean };

@Entry
@Component
struct CapsulePage {
  @State isBusy: boolean = false;
  @State showDialog: boolean = false;
  @State candidates: CapsuleCandidateItem[] = [];
  @State untranslated: string[] = [];
  @State targetBook: string = '';
  @State availableBooks: string[] = [];
  @State importSummary: string = '';

  aboutToAppear() {
    FloatingCapsuleManager.getInstance().setRecognitionListener((payload: CapsuleRecognitionResult) => {
      this.candidates = payload.words.map(item => ({ ...item, selected: true } as CapsuleCandidateItem));
      this.untranslated = payload.untranslated;
      this.targetBook = payload.suggestedBook || this.targetBook;
      this.showDialog = true;
      this.loadBooks();
      this.importSummary = '';
    });
  }

  private async loadBooks() {
    const books = await DatabaseManager.getInstance().listAllBooks();
    this.availableBooks = books;
    if (!this.targetBook || !this.availableBooks.includes(this.targetBook)) {
      this.targetBook = this.availableBooks[0] || '';
    }
  }

  build() {
    Stack() {
      Column() {
        Row() {
          if (this.isBusy) {
            LoadingProgress()
              .width(18)
              .height(18)
              .color('#FFFFFF')
              .margin({ right: 6 })
          } else {
            Text('📷')
              .fontSize(16)
              .margin({ right: 6 })
          }

          Text(this.isBusy ? '识别中' : '截屏')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .height('80%')
        .backgroundColor('#34495E')
        .borderRadius(25)
        .shadow({ radius: 8, color: 'rgba(0,0,0,0.4)', offsetY: 4 })
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(async () => {
          if (this.isBusy) return;

          this.isBusy = true;
          const count = await FloatingCapsuleManager.getInstance().triggerImageImport();
          this.isBusy = false;
          console.info(`已识别 ${count} 个候选单词`);
        })

        if (this.importSummary && !this.showDialog) {
          Text(this.importSummary)
            .fontSize(10)
            .fontColor('#F3F4F6')
            .margin({ top: 4 })
        }
      }
      .width('100%')
      .height('100%')

      if (this.showDialog) {
        this.renderSelectionDialog();
      }
    }
    .width('100%')
    .height('100%')
  }

  private renderSelectionDialog() {
    Column() {
      Text('识别结果')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 8 });

      Text(`未带释义：${this.untranslated.join(', ') || '无'}`)
        .fontSize(12)
        .fontColor('#DC2626')
        .margin({ bottom: 6 });

      List() {
        ForEach(this.candidates, (item: any, index: number) => {
          ListItem() {
            Row() {
              Checkbox({ name: `word-${index}`, group: 'capsule-select' })
                .select(item.selected)
                .onChange((_, isChecked) => this.toggleSelection(index, isChecked));
              Column() {
                Text(item.spelling).fontWeight(FontWeight.Bold);
                Text(item.meaning || '暂无释义').fontColor(item.hasMeaning ? '#111827' : '#DC2626').fontSize(12);
              }.margin({ left: 8 });
            }
            .padding({ top: 6, bottom: 6 });
          }
        }, (_, index: number) => `candidate-${index}`)
      }
      .height(160)
      .margin({ bottom: 8 })
      .divider({ strokeWidth: 0 });

      Row() {
        Text('导入到词书：').fontSize(13);
        TextInput({ text: this.targetBook, placeholder: '输入或选择词书' })
          .width(160)
          .onChange((value: string) => { this.targetBook = value; });
      }
      .margin({ bottom: 4 })
      .alignItems(VerticalAlign.Center);

      Text(`可用词书：${this.availableBooks.join(', ')}`)
        .fontSize(11)
        .fontColor('#6B7280')
        .margin({ bottom: 8 });

      Row() {
        Button('取消').type(ButtonType.Normal).onClick(() => { this.showDialog = false; });
        Button('确认导入')
          .type(ButtonType.Capsule)
          .backgroundColor('#10B981')
          .fontColor('#FFFFFF')
          .onClick(() => this.importSelected());
      }
      .justifyContent(FlexAlign.SpaceBetween)
      .width('100%')
      .margin({ bottom: 6 });

      if (this.importSummary) {
        Text(this.importSummary).fontSize(12).fontColor('#111827');
      }
    }
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({ radius: 10, color: 'rgba(0,0,0,0.15)' })
    .width('100%')
    .margin({ top: 12 })
  }

  private toggleSelection(index: number, checked: boolean) {
    const updated = this.candidates.slice();
    const item = updated[index] as any;
    updated[index] = { ...item, selected: checked } as any;
    this.candidates = updated;
  }

  private async importSelected() {
    const chosen = (this.candidates as any[]).filter(item => item.selected);
    if (chosen.length === 0) {
      this.importSummary = '请先选择要导入的单词';
      return;
    }
    const normalizedBook = this.targetBook.trim();
    if (!normalizedBook) {
      this.importSummary = '请先输入或选择词书名称';
      return;
    }
    const result = await FloatingCapsuleManager.getInstance().confirmImport(normalizedBook, chosen as CapsuleWordCandidate[]);
    this.importSummary = `导入完成：${result.added}/${chosen.length}，未释义：${result.untranslated.join(', ') || '无'}`;
    this.showDialog = false;
  }
}