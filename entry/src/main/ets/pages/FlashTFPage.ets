import { DatabaseManager } from '../utils/DatabaseManager';
import { PreferenceManager } from '../utils/PreferenceManager';
import { Word } from '../model/WordModel';
import { CleanCard } from '../components/CustomComponents';

@Component
export struct FlashTFPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @State words: Word[] = [];
  @State currentIndex: number = 0;
  @State displayMeaning: string = '';
  @State isCorrect: boolean = true;
  @State feedback: string = '';

  async aboutToAppear() {
    const book = await PreferenceManager.getInstance().getCurrentBook();
    this.words = await DatabaseManager.getInstance().getRandomWords(book, 20);
    this.nextCard();
  }

  nextCard() {
    if (this.words.length === 0) return;
    const word = this.words[this.currentIndex];
    if (Math.random() > 0.5) {
      this.displayMeaning = word.meaning;
      this.isCorrect = true;
    } else {
      const randomIdx = Math.floor(Math.random() * this.words.length);
      this.displayMeaning = this.words[randomIdx].meaning;
      this.isCorrect = (randomIdx === this.currentIndex);
    }
    this.feedback = '';
  }

  answer(choice: boolean) {
    if (choice === this.isCorrect) {
      this.feedback = '回答正确！';
      if (this.currentIndex < this.words.length - 1) { setTimeout(() => { this.currentIndex++; this.nextCard(); }, 500); }
    } else {
      this.feedback = '错误！';
    }
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([Color.Black]) }
          .backgroundColor(Color.Transparent).width(48).height(48).onClick(() => this.pageStack.pop())
          Text('闪卡判断').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 4 })
        }.width('100%').padding({ top: 40, left: 16, right: 16, bottom: 10 }).alignItems(VerticalAlign.Center)

        if (this.words.length > 0) {
          Column({ space: 30 }) {
            CleanCard() {
              Column({ space: 20 }) {
                Text(this.words[this.currentIndex].spelling).fontSize(32).fontWeight(FontWeight.Bold).fontColor('#0A59F7')
                Divider()
                Text(this.displayMeaning).fontSize(18).textAlign(TextAlign.Center).maxLines(3)
              }.padding(30)
            }
            Text(this.feedback).fontSize(16).fontColor('#FA8C16').height(20)
            Row({ space: 40 }) {
              Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.xmark')).fontSize(40).fontColor([Color.White]) }.width(80).height(80).backgroundColor('#FF4D4F').onClick(() => this.answer(false))
              Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.checkmark')).fontSize(40).fontColor([Color.White]) }.width(80).height(80).backgroundColor('#52C41A').onClick(() => this.answer(true))
            }
          }.padding(20).justifyContent(FlexAlign.Center).layoutWeight(1)
        } else {
          Text('题目加载失败...').margin(50)
        }
      }.height('100%').backgroundColor('#F5F7FA')
    }.hideTitleBar(true)
  }
}