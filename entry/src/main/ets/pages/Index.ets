import { DatabaseManager } from '../utils/DatabaseManager';
import { WordImporter } from '../utils/WordImporter';
import { DashboardStats, Word } from '../model/WordModel';
import { common } from '@kit.AbilityKit';
import { ReviewPage } from './ReviewPage';
import { VocabularyPage } from './VocabularyPage';
import { SettingsPage } from './SettingsPage';
import { ZenPage } from './ZenPage';
import { WelcomePage } from './WelcomePage';
import { AboutPage } from './AboutPage';
import { PracticeHubPage } from './PracticeHubPage';
import { SpellChallengePage } from './SpellChallengePage';
import { DictationPage } from './DictationPage';
import { FlashTFPage } from './FlashTFPage';
import { MatchPairsPage } from './MatchPairsPage';
import { TimeAttackPage } from './TimeAttackPage';
import { SimpleLineChart, CleanCard } from '../components/CustomComponents';
import { PreferenceManager } from '../utils/PreferenceManager';
import { promptAction } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  @Provide('pageStack') pageStack: NavPathStack = new NavPathStack();
  @Provide refreshFlag: number = 0;

  @State isFirstLaunch: boolean = false;
  @State isReady: boolean = false;

  async aboutToAppear(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    await PreferenceManager.getInstance().init(context);
    await DatabaseManager.getInstance().init(context);

    this.isFirstLaunch = await PreferenceManager.getInstance().isFirstLaunch();
    if (this.isFirstLaunch) {
      await this.initDefaultBook(context);
    }
    this.isReady = true;
    this.refreshFlag++;
  }

  async initDefaultBook(context: common.Context): Promise<void> {
    try {
      const defaultBookName = "CET-4";
      const count = await WordImporter.importFromRawFile(context as common.UIAbilityContext, 'CET4.json', defaultBookName);
      if (count > 0) {
        await PreferenceManager.getInstance().setCurrentBook(defaultBookName);
      }
    } catch (e) {
      console.error('[Lumina] Failed to init default book:', e);
    }
  }

  onPageShow(): void {
    this.refreshFlag++;
  }

  @Builder
  PagesMap(name: string) {
    if (name === 'ReviewPage') { ReviewPage() }
    else if (name === 'VocabularyPage') { VocabularyPage() }
    else if (name === 'SettingsPage') { SettingsPage() }
    else if (name === 'ZenPage') { ZenPage() }
    else if (name === 'AboutPage') { AboutPage() }
    else if (name === 'SpellChallengePage') { SpellChallengePage() }
    else if (name === 'DictationPage') { DictationPage() }
    else if (name === 'FlashTFPage') { FlashTFPage() }
    else if (name === 'MatchPairsPage') { MatchPairsPage() }
    else if (name === 'TimeAttackPage') { TimeAttackPage() }
  }

  build() {
    Stack() {
      if (this.isReady) {
        if (this.isFirstLaunch) {
          WelcomePage({
            onFinish: () => {
              animateTo({ duration: 300 }, () => { this.isFirstLaunch = false; })
              this.refreshFlag++;
            }
          }).zIndex(999)
        } else {
          Navigation(this.pageStack) {
            HomePage()
          }
          .navDestination(this.PagesMap)
          .mode(NavigationMode.Stack)
          .hideTitleBar(true)
        }
      }
    }
    .width('100%')
    .height('100%')
  }
}

@Component
struct HomePage {
  @Consume('pageStack') pageStack: NavPathStack;
  @Consume @Watch('onRefreshTriggered') refreshFlag: number;

  @State currentIndex: number = 0;
  @State stats: DashboardStats = new DashboardStats();
  @State chartData: number[] = [0, 0, 0, 0, 0];
  @State heatmapData: Map<string, number> = new Map();
  @State dateList: string[] = [];
  @State focusWords: Word[] = [];
  @State planNote: string = '';
  @State completionProgress: number = 0;
  @State selectedBook: string = "请选择词书";
  @State reviewMode: number = 0;
  @State dailyLimit: number = 20;
  @State todayRemaining: number = 20;

  async aboutToAppear(): Promise<void> {
    this.reviewMode = await PreferenceManager.getInstance().getReviewMode();
    this.selectedBook = await PreferenceManager.getInstance().getCurrentBook();
    if (this.selectedBook === "Default Library") {
      const db = DatabaseManager.getInstance();
      const hasData = await db.checkBookExists("CET-4");
      if (hasData) {
        this.selectedBook = "CET-4";
        await PreferenceManager.getInstance().setCurrentBook("CET-4");
      }
    }
    this.refreshStats();
  }

  onRefreshTriggered(): void { this.refreshStats(); }

  async refreshStats(): Promise<void> {
    const db = DatabaseManager.getInstance();
    this.selectedBook = await PreferenceManager.getInstance().getCurrentBook();
    if (this.selectedBook === "Default Library" || this.selectedBook === "请选择词书") {
      const valid = await db.findAnyValidBook();
      if (valid !== "Default Library") {
        this.selectedBook = valid;
        await PreferenceManager.getInstance().setCurrentBook(valid);
      }
    }

    this.dailyLimit = await PreferenceManager.getInstance().getDailyLimit();
    this.stats = await db.getDashboardStats(this.selectedBook);
    this.todayRemaining = Math.max(0, this.dailyLimit - this.stats.learnedToday);
    this.chartData = await db.getProficiencyDistribution(this.selectedBook);
    this.heatmapData = await db.getActivityStats(this.selectedBook);
    this.focusWords = await db.getSpellingReviewWords(this.selectedBook, 3);
    this.generateDateList();
    this.updatePlanNote();
    this.calculateCompletion();
  }

  calculateCompletion(): void {
    if (this.stats.total === 0) { this.completionProgress = 0; return; }
    this.completionProgress = Math.min(100, Math.round((this.stats.mastered / this.stats.total) * 100));
  }

  updatePlanNote(): void {
    if (this.stats.total === 0) { this.planNote = '导入词书后即可开始计划'; return; }
    if (this.stats.due > this.dailyLimit) { this.planNote = '复习任务较重，加油！'; }
    else if (this.stats.learnedToday >= this.dailyLimit) { this.planNote = '今日目标已完成！'; }
    else { this.planNote = '按计划学习即可达成目标'; }
  }

  async toggleMode(mode: number): Promise<void> {
    this.reviewMode = mode;
    await PreferenceManager.getInstance().setReviewMode(mode);
  }

  async handleSwitchBook(): Promise<void> {
    promptAction.showActionMenu({
      title: '切换词书',
      buttons: [
        { text: '英语四级 (CET4)', color: '#333' },
        { text: '英语六级 (CET6)', color: '#333' },
        { text: 'GRE 8000词', color: '#333' },
        { text: '托福 (TOEFL)', color: '#333' }
      ]
    }).then(async (res) => {
      let fileName = ''; let bookName = '';
      switch (res.index) {
        case 0: fileName = 'CET4.json'; bookName = 'CET-4'; break;
        case 1: fileName = 'CET6.json'; bookName = 'CET-6'; break;
        case 2: fileName = 'GRE8000.json'; bookName = 'GRE8000'; break;
        case 3: fileName = 'TOEFL.json'; bookName = 'TOEFL'; break;
      }
      if (fileName) {
        try {
          const context = getContext(this) as common.UIAbilityContext;
          const exists = await DatabaseManager.getInstance().checkBookExists(bookName);
          if (exists) {
            this.selectedBook = bookName;
            await PreferenceManager.getInstance().setCurrentBook(bookName);
            await this.refreshStats();
            promptAction.showToast({ message: `已切换至 ${bookName}` });
          } else {
            promptAction.showToast({ message: '正在初始化词库...' });
            const count = await WordImporter.importFromRawFile(context, fileName, bookName);
            if (count > 0) {
              this.selectedBook = bookName;
              await PreferenceManager.getInstance().setCurrentBook(bookName);
              await this.refreshStats();
              promptAction.showToast({ message: `成功导入：${count} 词` });
            } else {
              promptAction.showToast({ message: `未找到文件: ${fileName}` });
            }
          }
        } catch (e) {}
      }
    });
  }

  generateDateList(): void {
    const list: string[] = []; const today = new Date();
    for (let i = 27; i >= 0; i--) {
      const d = new Date(); d.setDate(today.getDate() - i);
      list.push(`${d.getFullYear()}-${(d.getMonth()+1).toString().padStart(2, '0')}-${d.getDate().toString().padStart(2, '0')}`);
    }
    this.dateList = list;
  }

  getHeatmapColor(count: number): string {
    if (count === 0) return '#F0F0F0';
    if (count <= 5) return '#BAE0FF';
    if (count <= 10) return '#69B1FF';
    if (count <= 20) return '#1890FF';
    return '#0050B3';
  }

  getProficiencyColor(p: number): string {
    if (p < 20) return '#FF4D4F';
    if (p < 60) return '#FAAD14';
    return '#52C41A';
  }

  @Builder StatItem(count: string, label: string) {
    Column({ space: 4 }) {
      Text(count).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
      Text(label).fontSize(12).fontColor('#666')
    }
  }

  @Builder StepPill(title: string, desc: string, bg: string, color: string) {
    Column({ space: 4 }) {
      Text(title).fontSize(12).fontColor(color).fontWeight(FontWeight.Medium)
      Text(desc).fontSize(12).fontColor('#1A1A1A')
    }
    .padding({ top: 12, bottom: 12, left: 14, right: 14 })
    .backgroundColor(bg)
    .borderRadius(16)
  }

  @Builder TagChip(text: string, value: string, color: string) {
    Row({ space: 6 }) {
      Text(text).fontSize(11).fontColor('#666')
      Text(value).fontSize(12).fontWeight(FontWeight.Medium).fontColor(color)
    }
    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
    .backgroundColor('rgba(10, 89, 247, 0.06)')
    .borderRadius(16)
  }

  // [关键修复] 补全 TabBuilder 方法
  @Builder TabBuilder(title: string, targetIndex: number, icon: Resource) {
    Column() {
      SymbolGlyph(icon)
        .fontSize(24)
        .fontColor(this.currentIndex === targetIndex ? ['#0A59F7'] : ['#999'])
        .symbolEffect(new BounceSymbolEffect(EffectScope.WHOLE, this.currentIndex === targetIndex ? 1 : 0))

      Text(title).fontSize(10).fontColor(this.currentIndex === targetIndex ? '#0A59F7' : '#999').margin({ top: 4 })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center)
  }

  @Builder PlanCard() {
    CleanCard() {
      Column({ space: 12 }) {
        Row() {
          Column({ space: 4 }) {
            Text('Daily Goals').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
            Text(this.planNote).fontSize(12).fontColor('#666')
          }
          .layoutWeight(1)
        }

        Row({ space: 8 }) {
          this.StepPill('Review Due', `${this.stats.due}`, '#FFF7E6', '#FAAD14')
          this.StepPill('New Words', `${this.todayRemaining} left`, '#E6F4FF', '#1677FF')
          this.StepPill('Practice', 'Unlocked', '#F6FFED', '#52C41A')
        }
      }
    }
  }

  @Builder OverviewCard() {
    CleanCard() {
      Column({ space: 12 }) {
        Row() {
          Column() {
            Text('Library Stats').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
            Text(this.selectedBook).fontSize(12).fontColor('#666')
          }
          .layoutWeight(1)

          Row({ space: 6 }) {
            this.TagChip('Mastered', `${this.stats.mastered}`, '#52C41A')
            this.TagChip('Total', `${this.stats.total}`, '#1677FF')
          }
        }

        Column({ space: 6 }) {
          Row() { Text('Mastery Progress').fontSize(12).fontColor('#666') }
          Row() {
            Progress({
              value: this.completionProgress,
              total: 100,
              type: ProgressType.Linear
            })
              .color('#0A59F7')
              .width('100%')
          }
          .width('100%')
          .backgroundColor('#F0F2F5')
          .borderRadius(6)
          .padding({ left: 4, right: 4 })

          Row() {
            Text(`${this.completionProgress}%`).fontSize(14).fontColor('#0A59F7').fontWeight(FontWeight.Medium)
            Blank().layoutWeight(1)
            Text(`${this.stats.due} Due`).fontSize(12).fontColor('#666')
          }
        }
      }
    }
  }

  @Builder FocusCard() {
    CleanCard() {
      Column({ space: 12 }) {
        Row() {
          Column() {
            Text('Review Focus').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
            Text('Hardest words for you').fontSize(12).fontColor('#666')
          }
          .layoutWeight(1)
          Button('View All').backgroundColor('#F5F7FA').fontColor('#0A59F7').height(34).onClick(() => {
            this.pageStack.pushPath({ name: 'VocabularyPage' });
          })
        }

        ForEach(this.focusWords, (item: Word) => {
          Column() {
            Row({ space: 8 }) {
              Column({ space: 2 }) {
                Text(item.spelling).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
                Text(item.meaning).fontSize(12).fontColor('#666').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .layoutWeight(1)

              this.TagChip('Proficiency', `${item.proficiency}%`, this.getProficiencyColor(item.proficiency))
            }
          }
          .width('100%')
          .padding({ top: 4, bottom: 4 })
        }, (item: Word) => item.id?.toString() ?? item.spelling)
      }
    }
  }

  @Builder ModeToggleButton(label: string, mode: number, icon: Resource) {
    Button() {
      Row() {
        Image(icon).width(18).height(18).fillColor(this.reviewMode === mode ? '#FFF' : '#999')
        Text(label).fontSize(14).fontColor(this.reviewMode === mode ? '#FFF' : '#999').fontWeight(FontWeight.Medium).margin({ left: 6 })
      }
    }
    .type(ButtonType.Normal)
    .padding({ top: 10, bottom: 10, left: 24, right: 24 })
    .backgroundColor(this.reviewMode === mode ? '#0A59F7' : Color.Transparent)
    .border({ width: 1, color: this.reviewMode === mode ? '#0A59F7' : '#E5E7EB' })
    .borderRadius(20)
    .animation({ duration: 300 })
    .onClick(() => { this.toggleMode(mode) })
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      // --- Tab 1: 学习 (Home) ---
      TabContent() {
        Column() {
          // 顶部栏
          Row() {
            Column({ space: 4 }) {
              Text('Current Plan').fontSize(12).fontColor('#999')
              Row() {
                Text(this.selectedBook).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
                SymbolGlyph($r('sys.symbol.chevron_down')).fontSize(16).fontColor(['#1A1A1A']).margin({ left: 4 })
              }.onClick(() => { this.handleSwitchBook() })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            if (this.stats.streak > 0) {
              Row() {
                SymbolGlyph($r('sys.symbol.clock_fill')).fontSize(14).fontColor(['#FF4D4F'])
                Text(`${this.stats.streak} 天`).fontSize(12).fontColor('#FF4D4F').fontWeight(FontWeight.Bold).margin({ left: 4 })
              }
              .padding({ left: 8, right: 8, top: 4, bottom: 4 }).backgroundColor('#FFF0F0').borderRadius(12).margin({ right: 12 })
            }

            Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.list_bullet')).fontSize(22).fontColor(['#333']).fontWeight(FontWeight.Medium) }
            .width(36).height(36).backgroundColor('#F0F2F5').margin({ right: 10 }).onClick(() => { this.pageStack.pushPath({ name: 'VocabularyPage' }) })

            Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.moon')).fontSize(22).fontColor(['#5C2D91']).fontWeight(FontWeight.Medium).symbolEffect(new AppearSymbolEffect(EffectScope.WHOLE)) }
            .width(36).height(36).backgroundColor('#F3E5F5').margin({ right: 10 }).onClick(() => { this.pageStack.pushPath({ name: 'ZenPage' }) })

            Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.gearshape')).fontSize(22).fontColor(['#333']).fontWeight(FontWeight.Medium) }
            .width(36).height(36).backgroundColor('#F0F2F5').onClick(() => { this.pageStack.pushPath({ name: 'SettingsPage' }) })
          }
          .width('100%').padding({ top: 60, left: 24, right: 24 })

          Scroll() {
            Column({ space: 20 }) {
              // 仪表盘
              Stack({ alignContent: Alignment.Center }) {
                Circle({ width: 220, height: 220 }).strokeWidth(20).fill(Color.Transparent).stroke('#F0F2F5')
                Circle({ width: 220, height: 220 })
                  .strokeWidth(20).fill(Color.Transparent).stroke('#0A59F7')
                  .rotate({ angle: -90 })
                  .strokeDashArray([
                    (this.stats.learnedToday + this.stats.due) > 0
                      ? (this.stats.learnedToday / (this.stats.learnedToday + this.stats.due)) * 692
                      : 0,
                    692
                  ])
                  .animation({ duration: 500, curve: Curve.EaseOut })
                Column() {
                  Text(this.stats.due.toString()).fontSize(64).fontWeight(FontWeight.Bolder).fontColor('#1A1A1A')
                  Text('Due Today').fontSize(14).fontColor('#999').margin({ top: 5 })
                  Text(`Done: ${this.stats.learnedToday}`)
                    .fontSize(14).fontColor('#0A59F7').fontWeight(FontWeight.Medium)
                    .backgroundColor('rgba(10, 89, 247, 0.1)')
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .borderRadius(10).margin({ top: 10 })
                }
              }
              .height(260)
              .margin({ top: 20 })

              // 统计数据
              Row() {
                this.StatItem(this.stats.total.toString(), 'Total')
                Divider().vertical(true).height(30).color('#EEE')
                this.StatItem(this.stats.mastered.toString(), 'Mastered')
                Divider().vertical(true).height(30).color('#EEE')
                this.StatItem(this.stats.learnedToday.toString(), 'Today')
              }
              .width('90%').justifyContent(FlexAlign.SpaceEvenly)
              .padding(20).backgroundColor(Color.White).borderRadius(16)
              .shadow({ radius: 10, color: 'rgba(0,0,0,0.05)' })

              this.PlanCard()
              this.OverviewCard()
              if (this.focusWords.length > 0) { this.FocusCard() }
            }
            .width('100%')
          }
          .layoutWeight(1).scrollBar(BarState.Off)

          // 模式切换
          Row() {
            this.ModeToggleButton('Card', 0, $r('sys.media.ohos_ic_public_paste')).margin({ right: 16 })
            this.ModeToggleButton('Spelling', 1, $r('sys.media.ohos_ic_public_edit'))
          }
          .justifyContent(FlexAlign.Center)
          .margin({ bottom: 10 })

          Button(this.stats.due > 0 ? 'Start Review Session' : 'All Done for Today!')
            .height(56)
            .padding({ left: 40, right: 40 })
            .backgroundColor(this.stats.due > 0 ? '#0A59F7' : '#52C41A')
            .fontColor(Color.White).fontSize(18).fontWeight(FontWeight.Medium)
            .shadow({ radius: 20, color: this.stats.due > 0 ? 'rgba(10, 89, 247, 0.3)' : 'rgba(82, 196, 26, 0.3)', offsetY: 10 })
            .onClick(() => { this.pageStack.pushPath({ name: 'ReviewPage' }); })
            .margin({ bottom: 30, top: 5 })
        }
        .width('100%').height('100%').backgroundColor('#F5F7FA')
      }
      .tabBar(this.TabBuilder('Study', 0, $r('sys.symbol.clock')))

      // --- Tab 2: 练习 (Practice) ---
      TabContent() {
        PracticeHubPage()
      }
      .tabBar(this.TabBuilder('Practice', 1, $r('sys.symbol.square_grid_2x2')))

      // --- Tab 3: 分析 (Analysis) ---
      TabContent() {
        Column() {
          Text('Learning Analytics').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#1A1A1A').width('100%').padding({ top: 60, left: 24, bottom: 20 })
          Scroll() {
            Column({ space: 20 }) {
              Column() {
                Text('Study Consistency (Last 28 Days)').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333').width('100%').margin({ bottom: 15 })
                Grid() {
                  ForEach(this.dateList, (date: string) => { GridItem() { Rect().width('100%').height(24).radius(4).fill(this.getHeatmapColor(this.heatmapData.get(date) || 0)) } })
                }.columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr').rowsGap(6).columnsGap(6).height(130)
              }.width('90%').padding(20).backgroundColor(Color.White).borderRadius(16).shadow({ radius: 10, color: 'rgba(0,0,0,0.05)' })

              Column() {
                Text('Proficiency Distribution').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333').width('100%').margin({ bottom: 20 })
                SimpleLineChart({ data: this.chartData })
              }.width('90%').padding(20).backgroundColor(Color.White).borderRadius(16).shadow({ radius: 10, color: 'rgba(0,0,0,0.05)' })
            }.width('100%')
          }.layoutWeight(1)
        }
        .width('100%').height('100%').backgroundColor('#F5F7FA')
      }
      .tabBar(this.TabBuilder('Analytics', 2, $r('sys.symbol.calendar_fill')))
    }
    .scrollable(false).barHeight(60).onChange((index) => { this.currentIndex = index; this.refreshStats(); })
  }
}