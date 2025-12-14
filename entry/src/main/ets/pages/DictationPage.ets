import { DatabaseManager } from '../utils/DatabaseManager';
import { PreferenceManager } from '../utils/PreferenceManager';
import { Word } from '../model/WordModel';

@Component
export struct DictationPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @State words: Word[] = [];
  @State currentIndex: number = 0;
  @State userInput: string = '';
  @State reveal: boolean = false;

  async aboutToAppear() {
    const book = await PreferenceManager.getInstance().getCurrentBook();
    this.words = await DatabaseManager.getInstance().getRandomWords(book, 10);
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          // 系统级返回按钮
          Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([Color.Black]) }
          .backgroundColor(Color.Transparent).width(48).height(48).onClick(() => this.pageStack.pop())
          Text('听写练习').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 4 })
        }.width('100%').padding({ top: 56, left: 16, right: 16, bottom: 10 }).alignItems(VerticalAlign.Center)

        if (this.words.length > 0) {
          Column({ space: 20 }) {
            Text('请拼写听到的单词').fontSize(16).fontColor('#666')
            Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.music_fill')).fontSize(30).fontColor([Color.White]) }
            .width(60).height(60).backgroundColor('#0A59F7').onClick(() => { /* Play sound */ })
            if (this.reveal) {
              Text(this.words[this.currentIndex].spelling).fontSize(24).fontWeight(FontWeight.Bold)
              Text(this.words[this.currentIndex].meaning).fontSize(14).fontColor('#666')
            }
            TextInput({ text: this.userInput, placeholder: 'Type here...' }).height(50).backgroundColor(Color.White).borderRadius(12).width('80%').onChange((val) => this.userInput = val)
            Button(this.reveal ? '下一个' : '查看答案').width('80%').height(50).backgroundColor('#0A59F7').onClick(() => { if (this.reveal) { if (this.currentIndex < this.words.length - 1) { this.currentIndex++; this.userInput = ''; this.reveal = false; } } else { this.reveal = true; } })
          }.width('100%').justifyContent(FlexAlign.Center).height('80%')
        } else {
          Text('正在加载题目...').margin(50)
        }
      }.height('100%').backgroundColor('#F5F7FA')
    }.hideTitleBar(true)
  }
}