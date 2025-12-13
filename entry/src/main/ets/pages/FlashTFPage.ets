import { DatabaseManager } from '../utils/DatabaseManager';
import { PreferenceManager } from '../utils/PreferenceManager';
import { Word } from '../model/WordModel';
import { CleanCard } from '../components/CustomComponents';

@Component
export struct FlashTFPage {
  @Consume('pageStack') pageStack: NavPathStack;

  @State words: Word[] = [];
  @State currentIndex: number = 0;
  @State displayedMeaning: string = '';
  @State isTruth: boolean = true;
  @State feedback: string = '';
  @State score: number = 0;

  async aboutToAppear(): Promise<void> {
    await this.loadWords();
    this.prepareCard();
  }

  async loadWords(): Promise<void> {
    const book = await PreferenceManager.getInstance().getCurrentBook();
    this.words = await DatabaseManager.getInstance().getRandomWords(book, 25);
    this.currentIndex = 0;
    this.score = 0;
  }

  get currentWord(): Word | undefined {
    return this.words[this.currentIndex];
  }

  prepareCard(): void {
    const word = this.currentWord;
    if (!word) return;
    const random = Math.random() > 0.5;
    this.isTruth = random;
    if (random) {
      this.displayedMeaning = word.meaning;
    } else {
      const other = this.words[Math.floor(Math.random() * this.words.length)];
      this.displayedMeaning = other?.meaning ?? word.meaning;
    }
    this.feedback = '';
  }

  async updateWordProgress(word: Word, correct: boolean): Promise<void> {
    if (!word.id) return;
    const newInterval = correct ? Math.min(word.interval + 1, 22) : 1;
    const newRepetition = correct ? word.repetition + 1 : Math.max(0, word.repetition - 1);
    const newEase = Math.max(1.3, correct ? word.easeFactor + 0.05 : word.easeFactor - 0.1);
    await DatabaseManager.getInstance().updateWordStats(word.id, newInterval, newRepetition, newEase);
    await DatabaseManager.getInstance().logActivity();
  }

  answer(choice: boolean): void {
    const word = this.currentWord;
    if (!word) return;
    const correct = choice === this.isTruth;
    this.feedback = correct ? '回答正确' : `正确释义是：${word.meaning}`;
    if (correct) this.score++;
    this.updateWordProgress(word, correct);
    this.nextCard();
  }

  nextCard(): void {
    if (this.currentIndex < this.words.length - 1) {
      this.currentIndex++;
      this.prepareCard();
    } else {
      this.feedback = `闪卡结束，得分 ${this.score}/${this.words.length}`;
    }
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(20).fontColor(['#1A1A1A']) }
          .backgroundColor('#F5F5F5').onClick(() => { this.pageStack.pop(); })
        Text('闪卡判断').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#1A1A1A').margin({ left: 12 })
        Blank().layoutWeight(1)
        Text(`得分 ${this.score}`).fontSize(14).fontColor('#0A59F7')
      }
      .padding({ top: 20, left: 16, right: 16 })

      if (!this.currentWord) {
        Text('暂无题目').fontSize(14).fontColor('#666').padding(16)
      } else {
        Column({ space: 14 }) {
          CleanCard() {
            Column({ space: 10 }) {
              Text(`单词：${this.currentWord.spelling}`).fontSize(18).fontWeight(FontWeight.Bold)
              Text(`释义：${this.displayedMeaning}`).fontSize(16).fontColor('#1A1A1A')
              Text(this.feedback).fontSize(14).fontColor(this.feedback.includes('正确') ? '#52C41A' : '#FA8C16')

              Row({ space: 12 }) {
                Button('匹配')
                  .backgroundColor('#52C41A')
                  .fontColor(Color.White)
                  .borderRadius(18)
                  .onClick(() => this.answer(true))

                Button('不匹配')
                  .backgroundColor('#FF7875')
                  .fontColor(Color.White)
                  .borderRadius(18)
                  .onClick(() => this.answer(false))
              }
            }
          }
        }
        .padding(16)
      }
    }
    .backgroundColor('#F5F7FA')
    .height('100%')
    .width('100%')
  }
}
