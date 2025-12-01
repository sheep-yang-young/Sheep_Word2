import { DatabaseManager } from '../utils/DatabaseManager';
import { Word } from '../model/WordModel';
import { promptAction } from '@kit.ArkUI';

@Component
export struct VocabularyPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @State words: Word[] = [];
  @State keyword: string = '';

  @State selectedWord: Word = { spelling: '', meaning: '', phonetic: '', proficiency: 0, repetition: 0, interval: 0, easeFactor: 0, lastReviewTime: 0, nextReviewTime: 0 };

  // 编辑弹窗控制器
  dialogController: CustomDialogController = new CustomDialogController({
    builder: EditWordDialog({
      editingWord: this.selectedWord,
      onConfirm: (word: Word) => { this.saveEdit(word) }
    }),
    alignment: DialogAlignment.Bottom,
    autoCancel: true,
    customStyle: true
  });

  async aboutToAppear(): Promise<void> {
    this.refreshList();
  }

  async refreshList(): Promise<void> {
    this.words = await DatabaseManager.getInstance().searchWords(this.keyword);
  }

  async saveEdit(newWord: Word): Promise<void> {
    if (newWord.id !== undefined) {
      await DatabaseManager.getInstance().updateWordInfo(newWord);
      this.refreshList();
      try {
        promptAction.showToast({ message: 'Updated successfully' });
      } catch (e) {}
    }
  }

  async deleteWord(id: number): Promise<void> {
    await DatabaseManager.getInstance().deleteWord(id);
    this.refreshList();
    try {
      promptAction.showToast({ message: 'Deleted' });
    } catch (e) {}
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Image($r('sys.media.ohos_ic_public_arrow_left'))
            .width(24).height(24).fillColor('#333')
            .onClick(() => { this.pageStack.pop() })

          Search({ value: this.keyword, placeholder: 'Search Vocabulary...' })
            .layoutWeight(1)
            .margin({ left: 12 })
            .height(40)
            .backgroundColor('#F5F7FA')
            .onChange((value: string) => {
              this.keyword = value;
              this.refreshList();
            })
        }
        .width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 })
        .backgroundColor(Color.White)

        if (this.words.length > 0) {
          List() {
            ForEach(this.words, (item: Word) => {
              ListItem() {
                Row() {
                  Column({ space: 4 }) {
                    Text(item.spelling)
                      .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
                    Text(item.meaning)
                      .fontSize(14).fontColor('#666')
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .layoutWeight(1).alignItems(HorizontalAlign.Start)

                  Circle({ width: 8, height: 8 })
                    .fill(this.getProficiencyColor(item.proficiency))
                    .margin({ right: 12 })

                  Image($r('sys.media.ohos_ic_public_edit'))
                    .width(20).height(20).fillColor('#CCC')
                    .onClick(() => {
                      this.selectedWord = item;
                      this.dialogController.open();
                    })
                }
                .width('100%')
                .padding(16)
                .backgroundColor(Color.White)
                .borderRadius(12)
                .margin({ bottom: 8 })
              }
              .swipeAction({ end: this.DeleteButton(item.id!) })
            }, (item: Word) => item.id!.toString())
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16, top: 10 })
          .scrollBar(BarState.Auto)
        } else {
          Column({ space: 10 }) {
            // [修复] 替换为 add 图标 (灰色)
            Image($r('sys.media.ohos_ic_public_add'))
              .width(60).height(60).fillColor('#DDD')
            Text('No words found').fontSize(16).fontColor('#999')
          }
          .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        }
      }
      .width('100%').height('100%').backgroundColor('#F5F7FA')
      .padding({ top: 36 })
    }
    .hideTitleBar(true)
  }

  getProficiencyColor(p: number): string {
    if (p < 20) return '#FF4D4F';
    if (p < 60) return '#FAAD14';
    return '#52C41A';
  }

  @Builder DeleteButton(id: number) {
    Button() {
      Image($r('sys.media.ohos_ic_public_remove'))
        .width(24).height(24).fillColor(Color.White)
    }
    .width(60).height('100%')
    .backgroundColor('#FF4D4F')
    .type(ButtonType.Normal)
    .borderRadius({ topRight: 12, bottomRight: 12 })
    .onClick(() => {
      this.deleteWord(id);
    })
  }
}

@CustomDialog
struct EditWordDialog {
  controller: CustomDialogController;
  @State editingWord: Word = { spelling: '', meaning: '', phonetic: '', proficiency: 0, repetition: 0, interval: 0, easeFactor: 0, lastReviewTime: 0, nextReviewTime: 0 };
  onConfirm: (word: Word) => void = () => {};

  build() {
    Column({ space: 16 }) {
      Text('Edit Word').fontSize(20).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Start)

      TextInput({ text: this.editingWord.spelling, placeholder: 'Spelling' })
        .onChange((val) => { this.editingWord.spelling = val })

      TextInput({ text: this.editingWord.phonetic, placeholder: 'Phonetic (Optional)' })
        .onChange((val) => { this.editingWord.phonetic = val })

      TextArea({ text: this.editingWord.meaning, placeholder: 'Meaning' })
        .height(80)
        .onChange((val) => { this.editingWord.meaning = val })

      Row({ space: 12 }) {
        Button('Cancel')
          .layoutWeight(1).backgroundColor('#F5F7FA').fontColor('#666')
          .onClick(() => { this.controller.close() })

        Button('Save')
          .layoutWeight(1).backgroundColor('#0A59F7').fontColor(Color.White)
          .onClick(() => {
            this.onConfirm(this.editingWord);
            this.controller.close();
          })
      }
      .width('100%').margin({ top: 10 })
    }
    .padding(24)
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 24, topRight: 24 })
    .width('100%')
  }
}