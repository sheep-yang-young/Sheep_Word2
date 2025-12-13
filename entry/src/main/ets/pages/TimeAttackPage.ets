import { DatabaseManager } from '../utils/DatabaseManager';
import { PreferenceManager } from '../utils/PreferenceManager';
import { Word } from '../model/WordModel';
import { CleanCard } from '../components/CustomComponents';

interface ChoiceOption {
  label: string;
  isCorrect: boolean;
}

@Component
export struct TimeAttackPage {
  @Consume('pageStack') pageStack: NavPathStack;

  @State words: Word[] = [];
  @State currentIndex: number = 0;
  @State options: ChoiceOption[] = [];
  @State score: number = 0;
  @State remaining: number = 60;
  @State feedback: string = '';
  timer: number | undefined = undefined;

  async aboutToAppear(): Promise<void> {
    await this.loadWords();
    this.prepareQuestion();
    this.startTimer();
  }

  aboutToDisappear(): void {
    this.stopTimer();
  }

  async loadWords(): Promise<void> {
    const book = await PreferenceManager.getInstance().getCurrentBook();
    this.words = await DatabaseManager.getInstance().getRandomWords(book, 30);
    this.currentIndex = 0;
    this.score = 0;
    this.feedback = '';
    this.remaining = 60;
  }

  get currentWord(): Word | undefined {
    return this.words[this.currentIndex];
  }

  startTimer(): void {
    this.stopTimer();
    this.timer = setInterval(() => {
      if (this.remaining > 0) {
        this.remaining--;
      } else {
        this.feedback = '时间结束，查看成绩吧';
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
    const newInterval = correct ? Math.min(word.interval + 1, 30) : 1;
    const newRepetition = correct ? word.repetition + 1 : Math.max(0, word.repetition - 1);
    const newEase = Math.max(1.3, correct ? word.easeFactor + 0.05 : word.easeFactor - 0.1);
    await DatabaseManager.getInstance().updateWordStats(word.id, newInterval, newRepetition, newEase);
    await DatabaseManager.getInstance().logActivity();
  }

  prepareQuestion(): void {
    const word = this.currentWord;
    if (!word) return;
    const options: ChoiceOption[] = [{ label: word.spelling, isCorrect: true }];
    while (options.length < 4 && options.length < this.words.length) {
      const other = this.words[Math.floor(Math.random() * this.words.length)];
      if (other && !options.find((o) => o.label === other.spelling)) {
        options.push({ label: other.spelling, isCorrect: false });
      }
    }
    this.options = options.sort(() => Math.random() - 0.5);
  }

  selectOption(option: ChoiceOption): void {
    const word = this.currentWord;
    if (!word || this.remaining <= 0) return;
    if (option.isCorrect) {
      this.score++;
      this.feedback = '正确！继续冲刺';
      this.updateWordProgress(word, true);
    } else {
      this.feedback = `答案：${word.spelling}`;
      this.updateWordProgress(word, false);
    }
    this.nextQuestion();
  }

  nextQuestion(): void {
    if (this.currentIndex < this.words.length - 1) {
      this.currentIndex++;
      this.prepareQuestion();
    } else {
      this.feedback = `冲刺完成，得分 ${this.score}/${this.words.length}`;
      this.stopTimer();
    }
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(20).fontColor(['#1A1A1A']) }
          .backgroundColor('#F5F5F5').onClick(() => { this.pageStack.pop(); })
        Text('60 秒冲刺').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#1A1A1A').margin({ left: 12 })
        Blank().layoutWeight(1)
        Text(`剩余 ${this.remaining}s`).fontSize(14).fontColor('#FA541C')
      }
      .padding({ top: 20, left: 16, right: 16 })

      if (!this.currentWord) {
        Text('暂无题目').fontSize(14).fontColor('#666').padding(16)
      } else {
        Column({ space: 14 }) {
          CleanCard() {
            Column({ space: 10 }) {
              Text(this.currentWord.meaning).fontSize(16).fontColor('#1A1A1A')
              Text(this.feedback).fontSize(14).fontColor(this.feedback.includes('正确') ? '#52C41A' : '#FA8C16')

              Column({ space: 10 }) {
                ForEach(this.options, (op: ChoiceOption) => {
                  Button(op.label)
                    .backgroundColor('#E6F7FF')
                    .fontColor('#0A59F7')
                    .borderRadius(14)
                    .onClick(() => this.selectOption(op))
                })
              }

              Text(`得分 ${this.score}`).fontSize(14).fontColor('#0A59F7')
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
