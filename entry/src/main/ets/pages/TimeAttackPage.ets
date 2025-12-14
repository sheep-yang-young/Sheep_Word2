import { DatabaseManager } from '../utils/DatabaseManager';
import { PreferenceManager } from '../utils/PreferenceManager';
import { Word } from '../model/WordModel';
import { CleanCard } from '../components/CustomComponents';

@Component
export struct TimeAttackPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @State words: Word[] = [];
  @State currentIndex: number = 0;
  @State options: string[] = [];
  @State score: number = 0;
  @State timeLeft: number = 60;
  @State isGameOver: boolean = false;

  async aboutToAppear() {
    const book = await PreferenceManager.getInstance().getCurrentBook();
    this.words = await DatabaseManager.getInstance().getRandomWords(book, 50);
    this.nextQuestion();
    this.startTimer();
  }

  startTimer() {
    let interval = setInterval(() => {
      this.timeLeft--;
      if (this.timeLeft <= 0) { clearInterval(interval); this.isGameOver = true; }
    }, 1000);
  }

  nextQuestion() {
    if (this.currentIndex >= this.words.length - 1) return;
    const correct = this.words[this.currentIndex].meaning;
    let opts = [correct];
    while (opts.length < 4) {
      const rand = this.words[Math.floor(Math.random() * this.words.length)].meaning;
      if (!opts.includes(rand)) opts.push(rand);
    }
    this.options = opts.sort(() => Math.random() - 0.5);
  }

  answer(opt: string) {
    if (this.isGameOver) return;
    const correct = this.words[this.currentIndex].meaning;
    if (opt === correct) { this.score++; }
    this.currentIndex++;
    this.nextQuestion();
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([Color.Black]) }
          .backgroundColor(Color.Transparent).width(48).height(48).onClick(() => this.pageStack.pop())
          Text('60秒冲刺').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 4 })
          Blank()
          Text(`${this.timeLeft}s`).fontSize(20).fontColor('#FF4D4F').fontWeight(FontWeight.Bold)
        }.width('100%').padding({ top: 56, left: 16, right: 16, bottom: 10 }).alignItems(VerticalAlign.Center)

        if (!this.isGameOver && this.words.length > 0) {
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
            Button('返回').onClick(() => this.pageStack.pop())
          }.justifyContent(FlexAlign.Center).height('80%')
        } else {
          Text('加载中...').margin(50)
        }
      }.height('100%').backgroundColor('#F5F7FA')
    }.hideTitleBar(true)
  }
}