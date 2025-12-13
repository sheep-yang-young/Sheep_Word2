import { DatabaseManager } from '../utils/DatabaseManager';
import { PreferenceManager } from '../utils/PreferenceManager';
import { Word } from '../model/WordModel';
import { Sm2Algorithm, ReviewGrade } from '../utils/Sm2Algorithm';
import { promptAction } from '@kit.ArkUI';

@Component
export struct SentencePracticePage {
  @Consume('pageStack') pageStack: NavPathStack;
  @Consume refreshFlag: number;

  @State words: Word[] = [];
  @State currentIndex: number = 0;
  @State userSentence: string = '';
  @State feedback: string = '';
  @State loading: boolean = true;

  private currentBookId: string = 'Default Library';

  async aboutToAppear(): Promise<void> {
    const prefs = PreferenceManager.getInstance();
    const limit = await prefs.getDailyLimit();
    this.currentBookId = await prefs.getCurrentBook();

    this.words = await DatabaseManager.getInstance().getTodayReviewWords(this.currentBookId, limit);
    if (this.words.length === 0) {
      this.words = await DatabaseManager.getInstance().getRandomWords(this.currentBookId, limit);
    }
    this.loading = false;
  }

  getHint(): string {
    if (this.words.length === 0) return '';
    const word = this.words[this.currentIndex];
    if (word.example && word.example.length > 0) {
      return word.example.replace(new RegExp(word.spelling, 'i'), '____');
    }
    return `${word.meaning} -> 请写一句包含 ${word.spelling} 的句子`;
  }

  async submitSentence(): Promise<void> {
    if (this.words.length === 0) return;
    const word = this.words[this.currentIndex];
    const normalized = this.userSentence.toLowerCase();
    if (normalized.includes(word.spelling.toLowerCase())) {
      this.feedback = '很好！句子中包含了目标单词。';
      await this.updateProgress(ReviewGrade.GOOD);
    } else {
      this.feedback = '请确保句子包含目标单词。';
    }
  }

  async updateProgress(grade: ReviewGrade): Promise<void> {
    const currentWord = this.words[this.currentIndex];
    const result = Sm2Algorithm.calculate(currentWord, grade);
    if (currentWord.id !== undefined) {
      await DatabaseManager.getInstance().updateWordStats(currentWord.id, result.interval, result.repetition, result.easeFactor);
      await DatabaseManager.getInstance().logActivity();
    }

    if (this.currentIndex < this.words.length - 1) {
      this.currentIndex++;
      this.userSentence = '';
      this.feedback = '';
    } else {
      promptAction.showToast({ message: '例句练习完成，继续加油！' });
      this.pageStack.pop();
      this.refreshFlag++;
    }
  }

  build() {
    NavDestination() {
      Column({ space: 20 }) {
        Row() {
          Image($r('sys.media.ohos_ic_public_arrow_left')).width(24).height(24).fillColor('#1A1A1A').onClick(() => { this.pageStack.pop(); });
          Blank();
          Text('例句造句').fontSize(18).fontWeight(FontWeight.Bold);
          Blank().width(24);
        }.width('100%').padding({ left: 20, right: 20, top: 20 })

        if (this.loading) {
          LoadingProgress().width(50).height(50).color('#0A59F7');
        } else if (this.words.length === 0) {
          Text('当前词书暂无数据').fontSize(16).fontColor('#999').padding(20);
        } else {
          Column({ space: 16 }) {
            Text(`${this.currentIndex + 1} / ${this.words.length}`).fontColor('#666').fontSize(14);
            Text(`单词：${this.words[this.currentIndex].spelling}`).fontSize(24).fontWeight(FontWeight.Bold).fontColor('#1A1A1A');
            Text(`释义：${this.words[this.currentIndex].meaning}`).fontSize(16).fontColor('#666');
            Text(this.getHint()).fontSize(14).fontColor('#999').backgroundColor('#F7F9FC').padding(12).borderRadius(12);

            TextArea({ placeholder: '写一句包含该单词的句子', text: this.userSentence })
              .height(140).backgroundColor('#F7F9FC').fontSize(16)
              .onChange((val) => { this.userSentence = val; this.feedback = ''; })

            if (this.feedback) {
              Text(this.feedback).fontColor('#0A59F7').fontSize(14)
            }

            Row({ space: 12 }) {
              Button('提交').layoutWeight(1).height(44).backgroundColor('#0A59F7').fontColor(Color.White).onClick(() => { this.submitSentence(); })
              Button('跳过').layoutWeight(1).height(44).backgroundColor('#F0F2F5').fontColor('#666').onClick(() => { this.updateProgress(ReviewGrade.AGAIN); })
            }.width('100%')
          }.padding(20).backgroundColor(Color.White).borderRadius(16).margin({ left: 20, right: 20 })
        }
      }
      .width('100%').height('100%').backgroundColor('#F5F7FA')
    }.hideTitleBar(true)
  }
}
