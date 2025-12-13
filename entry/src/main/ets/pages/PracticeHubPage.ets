import { DatabaseManager } from '../utils/DatabaseManager';
import { PreferenceManager } from '../utils/PreferenceManager';
import { Word } from '../model/WordModel';
import { CleanCard } from '../components/CustomComponents';

@Component
export struct PracticeHubPage {
  @Consume('pageStack') pageStack: NavPathStack;

  @State bookId: string = '';
  @State previewWords: Word[] = [];

  async aboutToAppear(): Promise<void> {
    this.bookId = await PreferenceManager.getInstance().getCurrentBook();
    this.previewWords = await DatabaseManager.getInstance().getRandomWords(this.bookId, 6);
  }

  build() {
    Column({ space: 16 }) {
      Row() {
        Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(20).fontColor(['#1A1A1A']) }
          .backgroundColor('#F5F5F5').onClick(() => { this.pageStack.pop(); })
        Text('练习中心').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#1A1A1A').margin({ left: 12 })
      }
      .padding({ top: 20, left: 16, right: 16 })

      Scroll() {
        Column({ space: 14 }) {
          this.previewWords.length === 0
            ? Text('当前词书暂无单词，先去导入或学习吧~').fontSize(14).fontColor('#666').padding({ left: 16, right: 16 })
            : CleanCard() {
                Column({ space: 8 }) {
                  Text('今日精选').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
                  Text('从当前词书随机挑选，帮助快速进入状态').fontSize(12).fontColor('#666')
                  ForEach(this.previewWords, (item: Word) => {
                    Row() {
                      Column() {
                        Text(item.spelling).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#0A59F7')
                        Text(item.meaning).fontSize(12).fontColor('#666').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                      }
                      .layoutWeight(1)
                      if (item.phonetic) { Text(item.phonetic).fontSize(12).fontColor('#999') }
                    }
                  }, (item: Word) => item.id?.toString() ?? item.spelling)
                }
              }

          this.ModeCard('拼写挑战', '根据释义拼写单词，错误高亮立即反馈', '#E6F4FF', '#1677FF', () => {
            this.pageStack.pushPath({ name: 'SpellChallengePage' })
          })

          this.ModeCard('听写练习', '倒计时写出听到的单词，可重复播放提示', '#FFF7E6', '#FA8C16', () => {
            this.pageStack.pushPath({ name: 'DictationPage' })
          })

          this.ModeCard('闪卡判断', '快速判断释义是否匹配，训练反应', '#F6FFED', '#52C41A', () => {
            this.pageStack.pushPath({ name: 'FlashTFPage' })
          })

          this.ModeCard('配对消消乐', '单词与释义配对消除，巩固记忆', '#FFF0F6', '#EB2F96', () => {
            this.pageStack.pushPath({ name: 'MatchPairsPage' })
          })

          this.ModeCard('60 秒冲刺', '限时连答，专注击破高频词', '#E6F7FF', '#1890FF', () => {
            this.pageStack.pushPath({ name: 'TimeAttackPage' })
          })
        }
        .padding(16)
      }
    }
    .backgroundColor('#F5F7FA')
    .height('100%')
    .width('100%')
  }

  @Builder ModeCard(title: string, desc: string, bg: string, color: string, action: () => void) {
    CleanCard() {
      Row() {
        Column({ space: 6 }) {
          Text(title).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
          Text(desc).fontSize(12).fontColor('#666')
        }
        .layoutWeight(1)

        Button('开始')
          .backgroundColor(bg)
          .fontColor(color)
          .borderRadius(16)
          .onClick(() => action())
      }
    }
  }
}
