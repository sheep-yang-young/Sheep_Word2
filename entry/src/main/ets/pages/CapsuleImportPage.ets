import { promptAction, router } from '@kit.ArkUI';
import { FloatingCapsuleManager, CapsuleRecognitionResult, CapsuleWordCandidate } from '../utils/FloatingCapsuleManager';
import { CapsuleFlow } from '../utils/CapsuleFlow';
import { common } from '@kit.AbilityKit';

@Entry
@Component
struct CapsuleImportPage {
  @State loading: boolean = false;
  @State flash: number = 0;
  @State bookId: string = '';
  @State result: CapsuleRecognitionResult = new CapsuleRecognitionResult();
  @State selected: boolean[] = [];

  private started: boolean = false;

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    FloatingCapsuleManager.getInstance().init(ctx);

    FloatingCapsuleManager.getInstance().setRecognitionListener((payload: CapsuleRecognitionResult) => {
      this.result = payload;
      this.bookId = (this.bookId && this.bookId.length > 0) ? this.bookId : payload.suggestedBook;
      this.selected = payload.words.map(() => true);
      this.loading = false;
    });

    if (!this.started && CapsuleFlow.consumeAutoPickPending()) {
      this.started = true;
      this.pickAndRecognize();
    } else {
      const last = FloatingCapsuleManager.getInstance().getLastResult();
      if (last && last.words.length > 0) {
        this.result = last;
        this.bookId = (this.bookId && this.bookId.length > 0) ? this.bookId : last.suggestedBook;
        this.selected = last.words.map(() => true);
      }
    }
  }

  private async pickAndRecognize(): Promise<void> {
    if (this.loading) return;
    this.loading = true;

    // “白一下”作为反馈（你之前想要的闪一下）
    this.flash = 1;
    animateTo({ duration: 160 }, () => { this.flash = 0; });

    const cnt = await FloatingCapsuleManager.getInstance().triggerImportByUserPicker();
    if (cnt <= 0) {
      this.loading = false;
      promptAction.showToast({ message: '未识别到可用单词（或未选择图片）' });
    }
  }

  private toggleAll(v: boolean): void {
    this.selected = this.result.words.map(() => v);
  }

  private collectSelected(): CapsuleWordCandidate[] {
    const out: CapsuleWordCandidate[] = [];
    for (let i = 0; i < this.result.words.length; i++) {
      if (this.selected[i]) out.push(this.result.words[i]);
    }
    return out;
  }

  private async saveSelected(): Promise<void> {
    const pick = this.collectSelected();
    if (pick.length <= 0) {
      promptAction.showToast({ message: '请先勾选要保存的单词' });
      return;
    }

    this.loading = true;
    const r = await FloatingCapsuleManager.getInstance().confirmImport(this.bookId, pick);
    this.loading = false;

    promptAction.showToast({ message: `已添加 ${r.added} 个单词` });
  }

  build() {
    Stack() {
      // 白闪层
      if (this.flash > 0) {
        Column().width('100%').height('100%').backgroundColor('#FFFFFFFF').opacity(this.flash);
      }

      Column({ space: 12 }) {
        Row() {
          Text('截图导入单词').fontSize(20).fontWeight(FontWeight.Medium).layoutWeight(1);
          Button('返回')
            .onClick(() => {
              try { router.back(); } catch (e) {}
            });
        }.width('100%');

        Row({ space: 8 }) {
          Button(this.loading ? '识别中…' : '选择截图并识别')
            .enabled(!this.loading)
            .onClick(async () => { await this.pickAndRecognize(); });

          Button('全选').enabled(!this.loading).onClick(() => this.toggleAll(true));
          Button('全不选').enabled(!this.loading).onClick(() => this.toggleAll(false));
        }.width('100%');

        Row({ space: 8 }) {
          Text('保存到词库ID:').fontSize(14);
          TextInput({ text: this.bookId, placeholder: '例如 CET4 / Captured_Words' })
            .onChange((v: string) => { this.bookId = v; })
            .layoutWeight(1);
        }.width('100%');

        if (this.result.words.length <= 0) {
          Text('暂无识别结果').fontSize(14).opacity(0.6).margin({ top: 12 });
        } else {
          Text(`识别到 ${this.result.words.length} 个候选词（未翻译 ${this.result.untranslated.length} 个）`)
            .fontSize(13).opacity(0.7);

          List() {
            ForEach(this.result.words, (item: CapsuleWordCandidate, idx: number) => {
              ListItem() {
                Row({ space: 10 }) {
                  Checkbox({ name: String(idx), group: 'w' })
                    .select(this.selected[idx])
                    .onChange((val: boolean) => {
                      const next = this.selected.slice();
                      next[idx] = val;
                      this.selected = next;
                    });

                  Column({ space: 2 }) {
                    Text(item.spelling).fontSize(16).fontWeight(FontWeight.Medium);
                    Text(item.meaning && item.meaning.length > 0 ? item.meaning : '(无本地释义)')
                      .fontSize(13).opacity(item.hasMeaning ? 0.8 : 0.5);
                  }.layoutWeight(1);
                }.width('100%').padding(10);
              }
            }, (it: CapsuleWordCandidate, i: number) => it.spelling + '_' + String(i))
          }
          .width('100%')
          .height('60%');
        }

        Button(this.loading ? '保存中…' : '保存已选单词')
          .enabled(!this.loading)
          .onClick(async () => { await this.saveSelected(); })
          .width('100%')
          .margin({ top: 8 });

      }
      .padding(16)
      .width('100%')
      .height('100%');
    }
    .width('100%')
    .height('100%');
  }
}
