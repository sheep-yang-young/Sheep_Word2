import { DatabaseManager } from '../utils/DatabaseManager';
import { PreferenceManager } from '../utils/PreferenceManager';
import { Word } from '../model/WordModel';
import { CleanCard } from '../components/CustomComponents';

@Component
export struct SpellChallengePage {
  @Consume('pageStack') pageStack: NavPathStack;

  @State words: Word[] = [];
  @State currentIndex: number = 0;
  @State userInput: string = '';
  @State feedback: string = '';
  @State showHint: boolean = false;

  async aboutToAppear() {
    const book = await PreferenceManager.getInstance().getCurrentBook();
    // [核心] 获取单词，如果为空则自动全库搜索
    this.words = await DatabaseManager.getInstance().getRandomWords(book, 10);
  }

  checkAnswer() {
    if (this.words.length === 0) return;
    const current = this.words[this.currentIndex];
    if (this.userInput.trim().toLowerCase() === current.spelling.toLowerCase()) {
      this.feedback = '正确！';
      // 记录进度 (简单版)
      if (current.id) DatabaseManager.getInstance().updateWordStats(current.id, 1, 1, 2.6);
      this.nextWord();
    } else {
      this.feedback = '错误，请重试';
    }
  }

  nextWord() {
    setTimeout(() => {
      if (this.currentIndex < this.words.length - 1) {
        this.currentIndex++;
        this.userInput = '';
        this.feedback = '';
        this.showHint = false;
      } else {
        this.feedback = '练习完成！';
      }
    }, 800);
  }

  build() {
    NavDestination() {
      Column() {
        // 顶部导航栏
        Row() {
          Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(20) }
          .backgroundColor('#F5F5F5').onClick(() => this.pageStack.pop())
          Text('拼写挑战').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 12 })
        }
        .width('100%').padding(20)

        if (this.words.length > 0) {
          Column({ space: 20 }) {
            Text(`${this.currentIndex + 1} / ${this.words.length}`).fontSize(14).fontColor('#999')

            CleanCard() {
              Column({ space: 15 }) {
                Text(this.words[this.currentIndex].meaning)
                  .fontSize(18).fontWeight(FontWeight.Medium).textAlign(TextAlign.Center)

                if (this.showHint) {
                  Text(this.words[this.currentIndex].spelling).fontSize(24).fontColor('#0A59F7').fontWeight(FontWeight.Bold)
                } else {
                  Text('? ? ?').fontSize(24).fontColor('#DDD').fontWeight(FontWeight.Bold)
                }

                TextInput({ text: this.userInput, placeholder: '输入单词...' })
                  .height(50).backgroundColor('#F5F7FA').borderRadius(12)
                  .onChange((val) => this.userInput = val)

                Text(this.feedback).fontSize(14).fontColor(this.feedback === '正确！' ? '#52C41A' : '#FF4D4F')

                Row({ space: 10 }) {
                  Button('提示').backgroundColor('#FFF7E6').fontColor('#FA8C16').onClick(() => this.showHint = true)
                  Button('提交').backgroundColor('#0A59F7').onClick(() => this.checkAnswer())
                }
              }
            }
          }
          .padding(20)
        } else {
          Text('加载中或无题目...').margin(50)
        }
      }
      .height('100%').backgroundColor('#F5F7FA')
    }
    .hideTitleBar(true)
  }
}