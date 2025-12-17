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
    const db = DatabaseManager.getInstance();
    this.bookId = await PreferenceManager.getInstance().getCurrentBook();

    // [核心修复] 强制检查：如果当前书没数据，就找一本有数据的书
    const hasData = await db.checkBookExists(this.bookId);
    if (!hasData) {
      const validBook = await db.findAnyValidBook();
      if (validBook && validBook !== "Default Library") {
        this.bookId = validBook;
        await PreferenceManager.getInstance().setCurrentBook(validBook);
      }
    }

    // 获取预览单词
    this.previewWords = await db.getRandomWords(this.bookId, 5);
  }

  build() {
    Column() {
      // 标题栏
      Text('练习中心')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
        .width('100%')
        .padding({ top: 60, left: 24, bottom: 20 })

      Scroll() {
        Column({ space: 14 }) {
          // 预览卡片
          if (this.previewWords.length > 0) {
            CleanCard() {
              Column({ space: 10 }) {
                Text('热身预览').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
                ForEach(this.previewWords, (item: Word) => {
                  Row() {
                    Text(item.spelling).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#0A59F7')
                    Blank()
                    Text(item.meaning).fontSize(14).fontColor('#666').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).width('60%').textAlign(TextAlign.End)
                  }
                  .width('100%')
                })
              }
            }
          } else {
            Text('暂无单词数据，请先在设置页导入词书').fontSize(14).fontColor('#999').margin(20)
          }

          // 功能入口列表
          this.PracticeItem('拼写挑战', '根据释义拼写单词', '#E6F7FF', '#0A59F7', 'SpellChallengePage')
          this.PracticeItem('听写练习', '听音辩词，倒计时模式', '#FFF7E6', '#FA8C16', 'DictationPage')
          this.PracticeItem('闪卡判断', '快速判断释义对错', '#F6FFED', '#52C41A', 'FlashTFPage')
          this.PracticeItem('配对消消乐', '单词与释义连连看', '#FFF0F6', '#EB2F96', 'MatchPairsPage')
          this.PracticeItem('60秒冲刺', '极速选择题挑战', '#E6F7FF', '#1890FF', 'TimeAttackPage')
          this.PracticeItem('随身听', '磨耳朵，自动播放', '#F9F0FF', '#722ED1', 'PodcastPage') // 新增
          this.PracticeItem('拼写挑战', '根据释义拼写单词', '#E6F7FF', '#0A59F7', 'SpellChallengePage')
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 40 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FA')
  }

  @Builder PracticeItem(title: string, desc: string, bg: string, color: string, pageName: string) {
    Stack({ alignContent: Alignment.End }) {
      Column() {
        Text(title).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
        Text(desc).fontSize(12).fontColor('#666').margin({ top: 4 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(20)
      .backgroundColor(Color.White)
      .borderRadius(16)
      .shadow({ radius: 10, color: 'rgba(0,0,0,0.05)' })

      Button('GO')
        .width(60)
        .height(36)
        .backgroundColor(bg)
        .fontColor(color)
        .fontWeight(FontWeight.Bold)
        .margin({ right: 20 })
        .onClick(() => {
          this.pageStack.pushPath({ name: pageName })
        })
    }
    .width('100%')
  }
}