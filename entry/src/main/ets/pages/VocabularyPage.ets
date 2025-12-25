import { DatabaseManager } from '../utils/DatabaseManager';
import { Word } from '../model/WordModel';
import { promptAction } from '@kit.ArkUI';
import { PreferenceManager } from '../utils/PreferenceManager';
import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { CurrentWordService } from '../utils/CurrentWordService';

@Component
export struct VocabularyPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @State words: Word[] = [];
  @State keyword: string = '';
  @State sortMode: number = 0;
  @State currentBookId: string = "默认词库";
  @State selectedWord: Word = { id: 0, bookId: '', spelling: '', meaning: '', phonetic: '', note: '', roots: [], affixes: [], collocations: [], synonyms: [], antonyms: [], derivatives: [], senses: [], knowledgeScore: 0, proficiency: 0, repetition: 0, interval: 0, easeFactor: 0, lastReviewTime: 0, nextReviewTime: 0 };

  private avPlayer: media.AVPlayer | undefined = undefined;

  dialogController: CustomDialogController = new CustomDialogController({ builder: EditWordDialog({ editingWord: this.selectedWord, onConfirm: (word: Word) => { this.saveEdit(word) } }), alignment: DialogAlignment.Bottom, autoCancel: true, customStyle: true });
  knowledgeController: CustomDialogController = new CustomDialogController({ builder: KnowledgeDialog({ word: this.selectedWord, onPractice: (word: Word, correct: boolean) => { this.recordKnowledgePractice(word, correct) } }), alignment: DialogAlignment.Bottom, autoCancel: true, customStyle: true });

  async aboutToAppear(): Promise<void> {
    this.currentBookId = await PreferenceManager.getInstance().getCurrentBook();
    this.refreshList();
  }

  // 页面销毁时释放资源
  aboutToDisappear(): void {
    if (this.avPlayer) {
      this.avPlayer.release();
      this.avPlayer = undefined;
    }
  }

  async playWordAudio(word: string) {
    if (!word) return;
    try {
      if (!this.avPlayer) {
        this.avPlayer = await media.createAVPlayer();
        this.setAVPlayerCallback();
      }

      // 只有在 idle, initialized, prepared, stopped, completed 状态下才能 reset
      // 为了稳健，直接重置到 idle 状态
      if (this.avPlayer.state !== 'idle') {
        await this.avPlayer.reset();
      }

      // 设置 URL 触发 initialized 状态
      this.avPlayer.url = `https://dict.youdao.com/dictvoice?audio=${word}&type=2`;
    } catch (e) {
      console.error(`Audio Play Failed: ${JSON.stringify(e)}`);
      promptAction.showToast({ message: '发音失败，请检查网络' });
    }
  }

  setAVPlayerCallback() {
    if (!this.avPlayer) return;
    this.avPlayer.on('stateChange', (state: media.AVPlayerState) => {
      switch (state) {
        case 'initialized':
          this.avPlayer?.prepare();
          break;
        case 'prepared':
          this.avPlayer?.play();
          break;
        case 'error':
          console.error('AVPlayer state error');
          this.avPlayer?.reset();
          break;
      }
    });
    this.avPlayer.on('error', (err: BusinessError) => {
      console.error(`AVPlayer error: ${JSON.stringify(err)}`);
    });
  }

  async refreshList(): Promise<void> { this.words = await DatabaseManager.getInstance().searchWords(this.currentBookId, this.keyword, this.sortMode); }
  async saveEdit(newWord: Word): Promise<void> { if (newWord.id !== undefined) { await DatabaseManager.getInstance().updateWordInfo(newWord); this.refreshList(); try { promptAction.showToast({ message: '已更新' }); } catch (e) {} } }
  async recordKnowledgePractice(word: Word, correct: boolean): Promise<void> { if (!word.id) return; await DatabaseManager.getInstance().recordKnowledgePractice(word.id, correct); await this.refreshList(); try { promptAction.showToast({ message: correct ? '已记录搭配练习' : '已记录纠错' }); } catch (e) {} }
  async deleteWord(id: number): Promise<void> { await DatabaseManager.getInstance().deleteWord(id); this.refreshList(); try { promptAction.showToast({ message: '已删除' }); } catch (e) {} }

  build() {
    NavDestination() {
      Column() {
        Row() { Image($r('sys.media.ohos_ic_public_arrow_left')).width(24).height(24).fillColor('#333').onClick(() => { this.pageStack.pop() }); Search({ value: this.keyword, placeholder: '搜索...' }).layoutWeight(1).margin({ left: 12, right: 12 }).height(40).backgroundColor('#F5F7FA').onChange((value: string) => { this.keyword = value; this.refreshList(); }); Image($r('sys.media.ohos_ic_public_arrow_down')).width(24).height(24).fillColor('#333').bindMenu([ { value: 'A-Z 排序', action: () => { this.sortMode = 0; this.refreshList(); } }, { value: '最难优先', action: () => { this.sortMode = 1; this.refreshList(); } }, { value: '最熟优先', action: () => { this.sortMode = 2; this.refreshList(); } }, { value: '最近添加', action: () => { this.sortMode = 3; this.refreshList(); } } ]) }.width('100%').padding({ left: 20, right: 20, top: 12, bottom: 12 }).backgroundColor(Color.White)

        if (this.words.length > 0) {
          List() {
            ForEach(this.words, (item: Word) => {
              ListItem() {
                Row() {
                  Column({ space: 4 }) {
                    Row() {
                      Text(item.spelling).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
                      SymbolGlyph($r('sys.symbol.speaker_wave_2'))
                        .fontSize(16)
                        .fontColor(['#0A59F7'])
                        .margin({ left: 8 })
                    }
                    .onClick(() => {
                      this.playWordAudio(item.spelling);
                    })

                    Text(item.meaning).fontSize(14).fontColor('#666').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .layoutWeight(1).alignItems(HorizontalAlign.Start);

                  Row({ space: 6 }) {
                    Text(`${item.proficiency}%`).fontSize(10).fontColor('#999').margin({right: 4});
                    Circle({ width: 8, height: 8 }).fill(this.getProficiencyColor(item.proficiency));
                      Button('知识卡').type(ButtonType.Capsule).height(26).padding({ left: 10, right: 10 }).fontSize(12).backgroundColor('#EEF2FF').fontColor('#374151').onClick(() => { this.selectedWord = item; CurrentWordService.getInstance().setCurrentWord(item); this.knowledgeController.open(); })
                  }.margin({ right: 12 });
                  Image($r('sys.media.ohos_ic_public_edit')).width(20).height(20).fillColor('#CCC').onClick(() => { this.selectedWord = item; CurrentWordService.getInstance().setCurrentWord(item); this.dialogController.open(); })
                }.width('100%').padding(16).backgroundColor(Color.White).borderRadius(12).margin({ bottom: 8 })
              }.swipeAction({ end: this.DeleteButton(item.id!) })
            }, (item: Word) => item.id!.toString())
          }.width('100%').layoutWeight(1).padding({ left: 16, right: 16, top: 10 }).scrollBar(BarState.Auto)
        } else {
          Column({ space: 10 }) { Image($r('sys.media.ohos_ic_public_add')).width(60).height(60).fillColor('#DDD'); Text('本书暂无单词').fontSize(16).fontColor('#999') }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        }
      }.width('100%').height('100%').backgroundColor('#F5F7FA').padding({ top: 36 })
    }.hideTitleBar(true)
  }

  getProficiencyColor(p: number): string { if (p < 20) return '#FF4D4F'; if (p < 60) return '#FAAD14'; return '#52C41A'; }
  @Builder DeleteButton(id: number) { Button() { Image($r('sys.media.ohos_ic_public_remove')).width(24).height(24).fillColor(Color.White) }.width(60).height('100%').backgroundColor('#FF4D4F').type(ButtonType.Normal).borderRadius({ topRight: 12, bottomRight: 12 }).onClick(() => { this.deleteWord(id); }) }
}

@CustomDialog struct EditWordDialog { controller: CustomDialogController; @State editingWord: Word = { id: 0, bookId: '', spelling: '', meaning: '', phonetic: '', note: '', roots: [], affixes: [], collocations: [], synonyms: [], antonyms: [], derivatives: [], senses: [], knowledgeScore: 0, proficiency: 0, repetition: 0, interval: 0, easeFactor: 0, lastReviewTime: 0, nextReviewTime: 0 }; onConfirm: (word: Word) => void = () => {}; build() { Column({ space: 16 }) { Text('编辑单词').fontSize(20).fontWeight(FontWeight.Bold).width('100%').textAlign(TextAlign.Start); TextInput({ text: this.editingWord.spelling, placeholder: '单词拼写' }).onChange((val) => { this.editingWord.spelling = val }); TextInput({ text: this.editingWord.phonetic, placeholder: '音标 (可选)' }).onChange((val) => { this.editingWord.phonetic = val }); TextArea({ text: this.editingWord.meaning, placeholder: '中文释义' }).height(80).onChange((val) => { this.editingWord.meaning = val }); Row({ space: 12 }) { Button('取消').layoutWeight(1).backgroundColor('#F5F7FA').fontColor('#666').onClick(() => { this.controller.close() }); Button('保存').layoutWeight(1).backgroundColor('#0A59F7').fontColor(Color.White).onClick(() => { this.onConfirm(this.editingWord); this.controller.close(); }) }.width('100%').margin({ top: 10 }) }.padding(24).backgroundColor(Color.White).borderRadius({ topLeft: 24, topRight: 24 }).width('100%') } }
@CustomDialog struct KnowledgeDialog {
  controller: CustomDialogController;
  word: Word = { id: 0, bookId: '', spelling: '', meaning: '', phonetic: '', note: '', roots: [], affixes: [], collocations: [], synonyms: [], antonyms: [], derivatives: [], senses: [], knowledgeScore: 0, proficiency: 0, repetition: 0, interval: 0, easeFactor: 0, lastReviewTime: 0, nextReviewTime: 0 };
  onPractice: (word: Word, correct: boolean) => void = () => {};
  @State selectedSense: string = '';
  @State feedback: string = '';

  build() {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Column({ space: 4 }) {
          Text(this.word.spelling).fontSize(24).fontWeight(FontWeight.Bold)
          if (this.word.phonetic) Text(this.word.phonetic!).fontSize(14).fontColor('#6B7280')
          Text(this.word.meaning).fontSize(14).fontColor('#4B5563').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Button('关闭').type(ButtonType.Capsule).height(32).padding({ left: 12, right: 12 }).backgroundColor('#EEF2FF').fontColor('#111827').onClick(() => { this.controller.close(); })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if ((this.word.roots && this.word.roots!.length > 0) || (this.word.affixes && this.word.affixes!.length > 0)) {
        Column({ space: 6 }) {
          Text('词根词缀卡').fontSize(12).fontColor('#0F172A').fontWeight(FontWeight.Medium)
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach([...(this.word.roots || []), ...(this.word.affixes || [])], (item: string, index?: number) => {
              Text(item)
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .margin({ right: 8, bottom: 8 })
                .backgroundColor('#EEF2FF')
                .borderRadius(10)
                .fontSize(12)
            }, (item: string, index?: number) => `${item}-${index}`)
          }
        }
      }

      if (this.word.collocations && this.word.collocations!.length > 0) {
        Column({ space: 8 }) {
          Row({ space: 6 }) {
            Text('搭配练习').fontSize(12).fontWeight(FontWeight.Medium)
            Button('记住了').type(ButtonType.Normal).height(26).padding({ left: 10, right: 10 }).fontSize(12).backgroundColor('#DCFCE7').fontColor('#15803D').onClick(() => { this.onPractice(this.word, true); })
          }
          ForEach(this.word.collocations!, (item: string, index?: number) => {
            Row() {
              Text(item).layoutWeight(1).fontSize(14).fontColor('#111827')
              Button('再看').type(ButtonType.Capsule).height(26).padding({ left: 10, right: 10 }).fontSize(12).backgroundColor('#FFF1F2').fontColor('#DC2626').onClick(() => { this.onPractice(this.word, false); })
            }
            .padding({ top: 2, bottom: 2 })
          }, (item: string, index?: number) => `${item}-${index}`)
        }
        .padding(10)
        .backgroundColor('#F8FAFC')
        .borderRadius(12)
      }

      if (this.word.derivatives && this.word.derivatives!.length > 0) {
        Column({ space: 6 }) {
          Text('词族树').fontSize(12).fontWeight(FontWeight.Medium)
          ForEach(this.word.derivatives!, (item: string, index?: number) => {
            Row({ space: 6 }) {
              Text('⎯').fontColor('#CBD5E1')
              Text(item).fontSize(14).fontColor('#0F172A')
            }
          }, (item: string, index?: number) => `${item}-${index}`)
        }
      }

      if ((this.word.synonyms && this.word.synonyms!.length > 0) || (this.word.antonyms && this.word.antonyms!.length > 0)) {
        Column({ space: 6 }) {
          Text('同反义关联').fontSize(12).fontWeight(FontWeight.Medium)
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach([...(this.word.synonyms || []), ...(this.word.antonyms || [])], (item: string, index?: number) => {
              Text(item)
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .margin({ right: 8, bottom: 8 })
                .backgroundColor('#FEF3C7')
                .borderRadius(10)
                .fontSize(12)
            }, (item: string, index?: number) => `${item}-${index}`)
          }
        }
      }

      if (this.word.senses && this.word.senses!.length > 0) {
        Column({ space: 6 }) {
          Text('多义场景选择题').fontSize(12).fontWeight(FontWeight.Medium)
          ForEach(this.word.senses!, (item: string, index?: number) => {
            Button(item)
              .width('100%')
              .height(36)
              .backgroundColor('#F5F7FA')
              .fontColor('#111827')
              .border({ width: 1, color: this.selectedSense === item ? '#0A59F7' : '#E5E7EB' })
              .onClick(() => {
                this.selectedSense = item;
                const correct = index === 0;
                this.feedback = correct ? '场景匹配成功' : `推荐含义：${this.word.senses![0]}`;
                this.onPractice(this.word, correct);
              })
          }, (item: string, index?: number) => `${item}-${index}`)

          if (this.feedback) Text(this.feedback).fontSize(12).fontColor(this.feedback.includes('推荐') ? '#DC2626' : '#15803D')
        }
      }
    }
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius({ topLeft: 24, topRight: 24 })
    .width('100%')
  }
}