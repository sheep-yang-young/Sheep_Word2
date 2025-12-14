import { DatabaseManager } from '../utils/DatabaseManager';
import { PreferenceManager } from '../utils/PreferenceManager';
import { Word } from '../model/WordModel';
import { CleanCard } from '../components/CustomComponents';

interface TimeAttackState {
  bookId: string;
  words: Word[];
  currentIndex: number;
  timeLeft: number;
  score: number;
  isGameOver: boolean;
  isWordPoolExhausted: boolean;
}

@Component
export struct TimeAttackPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @State words: Word[] = [];
  @State currentIndex: number = 0;
  @State options: string[] = [];
  @State score: number = 0;
  @State timeLeft: number = 60;
  @State isGameOver: boolean = false;
  @State isWordPoolExhausted: boolean = false;

  private currentBookId: string = "Default Library";
  private timerId: number = -1;

  async aboutToAppear() {
    this.currentBookId = await PreferenceManager.getInstance().getCurrentBook();
    const restored = await this.restoreSession();

    if (!restored) {
      await this.startNewSession();
    } else {
      this.buildOptionsForCurrent();
    }

    if (!this.isGameOver && !this.isWordPoolExhausted && this.words.length > 0) {
      this.startTimer();
    }
  }

  async aboutToDisappear() {
    this.stopTimer();
    await this.persistSession();
  }

  startTimer() {
    if (this.timeLeft <= 0 || this.isGameOver || this.isWordPoolExhausted) return;
    this.stopTimer();
    this.timerId = setInterval(() => {
      this.timeLeft = Math.max(0, this.timeLeft - 1);
      if (this.timeLeft <= 0) {
        this.isGameOver = true;
        this.stopTimer();
      }
      this.persistSession();
    }, 1000);
  }

  stopTimer() {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  buildOptionsForCurrent() {
    if (this.words.length === 0 || this.currentIndex >= this.words.length) return;

    const correct = this.words[this.currentIndex].meaning;
    let opts = [correct];
    while (opts.length < 4 && this.words.length > 0) {
      const rand = this.words[Math.floor(Math.random() * this.words.length)].meaning;
      if (!opts.includes(rand)) opts.push(rand);
    }
    this.options = opts.sort(() => Math.random() - 0.5);
  }

  async startNewSession() {
    this.isWordPoolExhausted = false;
    this.isGameOver = false;
    const db = DatabaseManager.getInstance();
    const dailyLimit = await PreferenceManager.getInstance().getDailyLimit();
    const stats = await db.getDashboardStats(this.currentBookId, dailyLimit);
    const pendingToday = (stats.dueReviews || 0) + (stats.newToday || 0);
    const dueCap = Math.min(pendingToday || 0, dailyLimit || 0);
    const limit = dueCap > 0 ? Math.min(50, dueCap) : 50;

    this.words = await db.getRandomWords(this.currentBookId, limit);
    this.currentIndex = 0;
    this.score = 0;
    this.timeLeft = 60;
    this.buildOptionsForCurrent();
    await this.persistSession();
  }

  async restoreSession(): Promise<boolean> {
    const saved = await PreferenceManager.getInstance().getTimeAttackState<TimeAttackState>();
    if (saved && saved.bookId === this.currentBookId && saved.words && saved.words.length > 0) {
      this.words = saved.words;
      this.currentIndex = Math.min(saved.currentIndex ?? 0, saved.words.length - 1);
      this.timeLeft = saved.timeLeft ?? 60;
      this.score = saved.score ?? 0;
      this.isGameOver = saved.isGameOver ?? false;
      this.isWordPoolExhausted = saved.isWordPoolExhausted ?? false;
      return true;
    }
    await PreferenceManager.getInstance().clearTimeAttackState();
    return false;
  }

  async persistSession() {
    if (this.words.length === 0) return;
    const state: TimeAttackState = {
      bookId: this.currentBookId,
      words: this.words,
      currentIndex: this.currentIndex,
      timeLeft: this.timeLeft,
      score: this.score,
      isGameOver: this.isGameOver,
      isWordPoolExhausted: this.isWordPoolExhausted
    };
    await PreferenceManager.getInstance().setTimeAttackState(state);
  }

  answer(opt: string) {
    if (this.isGameOver || this.words.length === 0 || this.currentIndex >= this.words.length) return;
    const correct = this.words[this.currentIndex].meaning;
    if (opt === correct) { this.score++; }
    this.currentIndex++;

    if (this.currentIndex >= this.words.length) {
      this.isWordPoolExhausted = true;
      this.stopTimer();
    } else {
      this.buildOptionsForCurrent();
    }
    this.persistSession();
  }

  async continuePractice() {
    if (this.timeLeft <= 0) return;
    const db = DatabaseManager.getInstance();
    const dailyLimit = await PreferenceManager.getInstance().getDailyLimit();
    const stats = await db.getDashboardStats(this.currentBookId, dailyLimit);
    const pendingToday = (stats.dueReviews || 0) + (stats.newToday || 0);
    const dueCap = Math.min(pendingToday || 0, dailyLimit || 0);
    const limit = dueCap > 0 ? Math.min(50, dueCap) : 50;

    this.words = await db.getRandomWords(this.currentBookId, limit);
    this.currentIndex = 0;
    this.isWordPoolExhausted = false;
    this.isGameOver = false;
    this.buildOptionsForCurrent();
    if (this.words.length > 0) {
      this.startTimer();
    }
    await this.persistSession();
  }

  async restartGame() {
    this.stopTimer();
    await PreferenceManager.getInstance().clearTimeAttackState();
    await this.startNewSession();
    if (this.words.length > 0) this.startTimer();
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([Color.Black]) }
          .backgroundColor(Color.Transparent).width(48).height(48).onClick(() => this.pageStack.pop())
          Text('60秒冲刺').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 4 })
          Blank()
          Button('重开').type(ButtonType.Normal).size({ width: 72, height: 38 }).onClick(() => this.restartGame())
          Text(`${this.timeLeft}s`).fontSize(20).fontColor('#FF4D4F').fontWeight(FontWeight.Bold)
        }.width('100%').padding({ top: 56, left: 16, right: 16, bottom: 10 }).alignItems(VerticalAlign.Center)

        if (!this.isGameOver && !this.isWordPoolExhausted && this.words.length > 0 && this.currentIndex < this.words.length) {
          Column({ space: 20 }) {
            Text(`当前得分: ${this.score}`).fontSize(16).fontColor('#0A59F7')
            CleanCard() {
              Column() {
                Text(this.words[this.currentIndex].spelling).fontSize(30).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center).margin({ bottom: 20 })
                ForEach(this.options, (opt: string) => {
                  Button(opt).width('100%').backgroundColor('#F5F7FA').fontColor('#333').margin({ bottom: 10 }).height(50).onClick(() => this.answer(opt))
                })
              }.padding(20)
            }
          }.padding(20)
        } else if (this.isGameOver) {
          Column({ space: 20 }) {
            Text('时间到！').fontSize(30).fontWeight(FontWeight.Bold)
            Text(`最终得分: ${this.score}`).fontSize(24).fontColor('#0A59F7')
            Row({ space: 12 }) {
              Button('返回').onClick(() => this.pageStack.pop())
              Button('重新开始').type(ButtonType.Normal).onClick(() => this.restartGame())
            }
          }.justifyContent(FlexAlign.Center).height('80%')
        } else if (this.isWordPoolExhausted) {
          Column({ space: 20 }) {
            Text('已完成题目').fontSize(30).fontWeight(FontWeight.Bold)
            Text(`当前得分: ${this.score}`).fontSize(24).fontColor('#0A59F7')
            Row({ space: 12 }) {
              Button('继续加练').type(ButtonType.Normal).onClick(() => this.continuePractice())
              Button('重新开始').type(ButtonType.Normal).onClick(() => this.restartGame())
              Button('返回').onClick(() => this.pageStack.pop())
            }
          }.justifyContent(FlexAlign.Center).height('80%')
        } else {
          Text('加载中...').margin(50)
        }
      }.height('100%').backgroundColor('#F5F7FA')
    }.hideTitleBar(true)
  }
}
