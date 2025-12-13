import { DatabaseManager } from '../utils/DatabaseManager';
import { PreferenceManager } from '../utils/PreferenceManager';
import { Word } from '../model/WordModel';
import { CleanCard } from '../components/CustomComponents';

@Component
export struct DictationPage {
  @Consume('pageStack') pageStack: NavPathStack;

  @State words: Word[] = [];
  @State currentIndex: number = 0;
  @State inputText: string = '';
  @State feedback: string = '';
  @State countdown: number = 20;
  timer: number | undefined = undefined;

  async aboutToAppear(): Promise<void> {
    await this.loadWords();
    this.startTimer();
  }

  aboutToDisappear(): void {
    this.stopTimer();
  }

  async loadWords(): Promise<void> {
    const book = await PreferenceManager.getInstance().getCurrentBook();
    this.words = await DatabaseManager.getInstance().getRandomWords(book, 15);
    this.currentIndex = 0;
    this.inputText = '';
    this.feedback = '';
    this.countdown = 20;
  }

  get currentWord(): Word | undefined {
    return this.words[this.currentIndex];
  }

  startTimer(): void {
    this.stopTimer();
    this.countdown = 20;
    this.timer = setInterval(() => {
      if (this.countdown > 0) {
        this.countdown--;
      } else {
        this.feedback = '时间到！点击重播提示后再尝试';
        this.stopTimer();
      }
    }, 1000);
  }

  stopTimer(): void {
    if (this.timer !== undefined) {
      clearInterval(this.timer);
      this.timer = undefined;
    }
  }

  async updateWordProgress(word: Word, correct: boolean): Promise<void> {
    if (!word.id) return;
    const newInterval = correct ? Math.min(word.interval + 1, 25) : 1;
    const newRepetition = correct ? word.repetition + 1 : Math.max(0, word.repetition - 1);
    const newEase = Math.max(1.3, correct ? word.easeFactor + 0.05 : word.easeFactor - 0.1);
    await DatabaseManager.getInstance().updateWordStats(word.id, newInterval, newRepetition, newEase);
    await DatabaseManager.getInstance().logActivity();
  }

  submit(): void {
    const word = this.currentWord;
    if (!word) return;
    if (this.inputText.trim().toLowerCase() === word.spelling.toLowerCase()) {
      this.feedback = '正确，计入熟练度';
      this.updateWordProgress(word, true);
      this.nextQuestion();
    } else {
      this.feedback = `正确答案：${word.spelling}`;
      this.updateWordProgress(word, false);
    }
  }

  nextQuestion(): void {
    if (this.currentIndex < this.words.length - 1) {
      this.currentIndex++;
      this.inputText = '';
      this.feedback = '';
      this.startTimer();
    } else {
      this.feedback = '全部完成，回到练习中心看看吧';
      this.stopTimer();
    }
  }

  replayHint(): void {
    this.feedback = `${this.currentWord?.meaning ?? ''}${this.currentWord?.example ? ' | 例句：' + this.currentWord.example : ''}`;
    this.startTimer();
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(20).fontColor(['#1A1A1A']) }
          .backgroundColor('#F5F5F5').onClick(() => { this.pageStack.pop(); })
        Text('听写练习').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#1A1A1A').margin({ left: 12 })
        Blank().layoutWeight(1)
        Text(`倒计时 ${this.countdown}s`).fontSize(14).fontColor('#FA541C')
      }
      .padding({ top: 20, left: 16, right: 16 })

      if (!this.currentWord) {
        Text('暂无题目').fontSize(14).fontColor('#666').padding(16)
      } else {
        Column({ space: 14 }) {
          CleanCard() {
            Column({ space: 10 }) {
              Text('根据提示拼写单词').fontSize(14).fontColor('#666')
              Text(this.feedback || '点击重播按钮查看释义/例句').fontSize(14).fontColor('#1A1A1A')

              TextInput({ placeholder: '写下听到的单词', text: this.inputText })
                .caretColor('#0A59F7')
                .onChange((val: string) => { this.inputText = val })
                .backgroundColor('#F5F5F5')
                .height(48)
                .borderRadius(12)

              Row({ space: 12 }) {
                Button('重播提示')
                  .backgroundColor('#FFF7E6')
                  .fontColor('#FA8C16')
                  .borderRadius(18)
                  .onClick(() => this.replayHint())

                Button('提交')
                  .backgroundColor('#0A59F7')
                  .fontColor(Color.White)
                  .borderRadius(18)
                  .onClick(() => this.submit())

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
