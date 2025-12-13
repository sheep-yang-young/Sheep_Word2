import { DatabaseManager } from '../utils/DatabaseManager';
import { PreferenceManager } from '../utils/PreferenceManager';
import { Word } from '../model/WordModel';
import { CleanCard } from '../components/CustomComponents';

@Component
export struct SpellChallengePage {
  @Consume('pageStack') pageStack: NavPathStack;

  @State words: Word[] = [];
  @State currentIndex: number = 0;
  @State inputText: string = '';
  @State feedback: string = '';
  @State score: number = 0;
  @State showMeaning: boolean = true;
  @State errorMask: number[] = [];

  async aboutToAppear(): Promise<void> {
    await this.loadWords();
  }

  async loadWords(): Promise<void> {
    const book = await PreferenceManager.getInstance().getCurrentBook();
    this.words = await DatabaseManager.getInstance().getRandomWords(book, 20);
    this.currentIndex = 0;
    this.inputText = '';
    this.feedback = '';
    this.errorMask = [];
    this.score = 0;
  }

  get currentWord(): Word | undefined {
    return this.words[this.currentIndex];
  }

  async updateWordProgress(word: Word, correct: boolean): Promise<void> {
    if (!word.id) return;
    const newInterval = correct ? Math.min(word.interval + 1, 30) : 1;
    const newRepetition = correct ? word.repetition + 1 : Math.max(0, word.repetition - 1);
    const newEase = Math.max(1.3, correct ? word.easeFactor + 0.05 : word.easeFactor - 0.1);
    await DatabaseManager.getInstance().updateWordStats(word.id, newInterval, newRepetition, newEase);
    await DatabaseManager.getInstance().logActivity();
  }

  checkAnswer(): void {
    const word = this.currentWord;
    if (!word) return;
    const target = word.spelling.trim();
    const answer = this.inputText.trim();

    if (target.toLowerCase() === answer.toLowerCase()) {
      this.feedback = '正确！记一分';
      this.score++;
      this.updateWordProgress(word, true);
      this.nextQuestion();
    } else {
      this.feedback = '有些不对，再看看提示';
      const mask: number[] = [];
      const len = Math.max(target.length, answer.length);
      for (let i = 0; i < len; i++) {
        mask.push(target[i]?.toLowerCase() === answer[i]?.toLowerCase() ? 1 : 0);
      }
      this.errorMask = mask;
      this.updateWordProgress(word, false);
    }
  }

  nextQuestion(): void {
    if (this.currentIndex < this.words.length - 1) {
      this.currentIndex++;
      this.inputText = '';
      this.feedback = '';
      this.errorMask = [];
    } else {
      this.feedback = `全部完成！得分 ${this.score}/${this.words.length}`;
    }
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(20).fontColor(['#1A1A1A']) }
          .backgroundColor('#F5F5F5').onClick(() => { this.pageStack.pop(); })
        Text('拼写挑战').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#1A1A1A').margin({ left: 12 })
        Blank().layoutWeight(1)
        Text(`分数 ${this.score}`).fontSize(14).fontColor('#0A59F7')
      }
      .padding({ top: 20, left: 16, right: 16 })

      if (!this.currentWord) {
        Text('暂无题目，请先导入词书').fontSize(14).fontColor('#666').padding(16)
      } else {
        Column({ space: 14 }) {
          CleanCard() {
            Column({ space: 10 }) {
              Row() {
                Text(`第 ${this.currentIndex + 1}/${this.words.length} 题`).fontSize(14).fontColor('#999')
                Blank().layoutWeight(1)
                Button(this.showMeaning ? '隐藏释义' : '显示释义')
                  .fontColor('#0A59F7')
                  .backgroundColor('#E6F4FF')
                  .borderRadius(14)
                  .onClick(() => { this.showMeaning = !this.showMeaning })
              }

              if (this.showMeaning) {
                Text(this.currentWord.meaning).fontSize(16).fontColor('#1A1A1A')
              }

              TextInput({ placeholder: '输入正确拼写', text: this.inputText })
                .caretColor('#0A59F7')
                .onChange((val: string) => { this.inputText = val })
                .backgroundColor('#F5F5F5')
                .height(48)
                .borderRadius(12)

              if (this.errorMask.length > 0) {
                Row({ space: 2 }) {
                  ForEach(this.currentWord.spelling.split(''), (ch: string, index: number) => {
                    Text(ch)
                      .fontSize(18)
                      .fontColor(this.errorMask[index] === 1 ? '#52C41A' : '#FF4D4F')
                      .fontWeight(FontWeight.Bold)
                  })
                }
              }

              Text(this.feedback).fontSize(14).fontColor(this.feedback.includes('正确') ? '#52C41A' : '#FA8C16')

              Row({ space: 12 }) {
                Button('提交')
                  .backgroundColor('#0A59F7')
                  .fontColor(Color.White)
                  .borderRadius(18)
                  .onClick(() => this.checkAnswer())

                Button('下一题')
                  .backgroundColor('#F0F2F5')
                  .fontColor('#0A59F7')
                  .borderRadius(18)
                  .onClick(() => this.nextQuestion())
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
