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

    if (!this.selectedBook || this.selectedBook === "Default Library") {
      const db = DatabaseManager.getInstance();
      const hasData = await db.checkBookExists("CET-4");
      if (hasData) {
        this.selectedBook = "CET-4";
        await PreferenceManager.getInstance().setCurrentBook("CET-4");
      } else {
        const fallback = await db.findAnyValidBook();
        const fallbackHasData = await db.checkBookExists(fallback);
        if (fallback && fallbackHasData) {
          this.selectedBook = fallback;
          await PreferenceManager.getInstance().setCurrentBook(fallback);
        } else {
          this.selectedBook = fallback || "Default Library";
        }
      }
    }

    this.refreshStats();
  }

  onRefreshTriggered(): void { this.refreshStats(); }

  async refreshStats(): Promise<void> {
    const db = DatabaseManager.getInstance();
    this.selectedBook = await PreferenceManager.getInstance().getCurrentBook();
    if (!this.selectedBook || this.selectedBook === "Default Library" || this.selectedBook === "请选择词书") {
      const valid = await db.findAnyValidBook();
      const validHasData = await db.checkBookExists(valid);
      if (valid && validHasData) {
        this.selectedBook = valid;
        await PreferenceManager.getInstance().setCurrentBook(valid);
      } else {
        this.selectedBook = valid || "Default Library";
      }
    }

    this.dailyLimit = await PreferenceManager.getInstance().getDailyLimit();
    this.stats = await db.getDashboardStats(this.selectedBook, this.dailyLimit, this.reviewMode);

    this.chartData = await db.getProficiencyDistribution(this.selectedBook);
    this.heatmapData = await db.getActivityStats();
    this.todayRemaining = this.getTotalPending();
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
    const pendingReviews = this.stats.dueReviews || 0;
    const pendingNew = this.stats.newToday || 0;
    const pendingTotal = pendingReviews + pendingNew;

    if (this.stats.total === 0) { this.planNote = '导入词书后即可开始计划'; return; }
    if (pendingTotal === 0) { this.planNote = '已完成今日计划，可以巩固难词或预习'; return; }
    if (pendingReviews > this.dailyLimit) { this.planNote = '今日复习量较多，先完成复习再解锁新词'; }
    else if (this.stats.learnedToday >= this.dailyLimit && pendingReviews === 0) { this.planNote = '已完成今日新词目标，可以巩固难词或预习'; }
    else { this.planNote = '按计划学习即可达成今日目标，加油！'; }
  }

  getTotalPending(): number { return Math.max(0, (this.stats.dueReviews || 0) + (this.stats.newToday || 0)); }

  async toggleMode(mode: number): Promise<void> {
    this.reviewMode = mode;
    await PreferenceManager.getInstance().setReviewMode(mode);
    await this.refreshStats();
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

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        Column() {
          Row() {
            Column({ space: 4 }) {
              Text('当前词书').fontSize(12).fontColor('#999')
              Row() {
                Text(this.selectedBook).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
                SymbolGlyph($r('sys.symbol.chevron_down')).fontSize(16).fontColor(['#1A1A1A']).margin({ left: 4 })
              }.onClick(() => { this.handleSwitchBook() })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Button({ type: ButtonType.Circle }) {
              // 1. 图标改为月亮，颜色改为白色 (#FFF)
              SymbolGlyph($r('sys.symbol.moon'))
                .fontSize(22)
                .fontColor(['#FFFFFF'])
                .fontWeight(FontWeight.Medium)
            }
            .width(36).height(36)
            .backgroundColor('#ffb689ff') // 2. 背景色改为紫色
            .margin({ right: 12 })      // 与右边的设置按钮保持间距
            .onClick(() => {
              this.pageStack.pushPath({ name: 'ZenPage' })
            })

            Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.gearshape')).fontSize(22).fontColor(['#333']).fontWeight(FontWeight.Medium) }
            .width(36).height(36).backgroundColor('#F0F2F5').onClick(() => { this.pageStack.pushPath({ name: 'SettingsPage' }) })
          }
          .width('100%').padding({ top: 60, left: 24, right: 24 })

          Scroll() {
            Column({ space: 20 }) {
              Stack({ alignContent: Alignment.Center }) {
                Progress({
                  value: this.stats.learnedToday,
                  total: Math.max(1, this.stats.learnedToday + this.getTotalPending()),
                  type: ProgressType.Ring
                })
                  .width(220)
                  .color('#0A59F7')
                  .style({ strokeWidth: 20 })

                Column() {
                  Text(this.getTotalPending().toString()).fontSize(64).fontWeight(FontWeight.Bolder).fontColor('#1A1A1A')
                  Text(`${this.reviewMode === 0 ? 'Card' : 'Spelling'} Due Today`).fontSize(14).fontColor('#999').margin({ top: 5 })
                  Text(`Done: ${this.stats.learnedToday}`)
                    .fontSize(14).fontColor('#0A59F7').fontWeight(FontWeight.Medium)
                    .backgroundColor('rgba(10, 89, 247, 0.1)')
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .borderRadius(10).margin({ top: 10 })
                }
              }
              .height(260)
              .margin({ top: 20 })
            }
            .width('100%')
          }
          .layoutWeight(1).scrollBar(BarState.Off)

          Row({ space: 16 }) {
            Row() {
              Image($r('sys.media.ohos_ic_public_paste')).width(18).height(18).fillColor(this.reviewMode === 0 ? '#FFF' : '#999')
              Text('卡片').fontSize(14).fontColor(this.reviewMode === 0 ? '#FFF' : '#999').fontWeight(FontWeight.Medium).margin({ left: 6 })
            }
            .padding({ top: 10, bottom: 10, left: 24, right: 24 })
            .backgroundColor(this.reviewMode === 0 ? '#0A59F7' : '#FFFFFF')
            .border({ width: 1, color: this.reviewMode === 0 ? '#0A59F7' : '#E5E7EB' })
            .borderRadius(20)
            .animation({ duration: 300 })
            .onClick(() => { this.toggleMode(0) })

            Row() {
              Image($r('sys.media.ohos_ic_public_edit')).width(18).height(18).fillColor(this.reviewMode === 1 ? '#FFF' : '#999')
              Text('拼写').fontSize(14).fontColor(this.reviewMode === 1 ? '#FFF' : '#999').fontWeight(FontWeight.Medium).margin({ left: 6 })
            }
            .padding({ top: 10, bottom: 10, left: 24, right: 24 })
            .backgroundColor(this.reviewMode === 1 ? '#0A59F7' : '#FFFFFF')
            .border({ width: 1, color: this.reviewMode === 1 ? '#0A59F7' : '#E5E7EB' })
            .borderRadius(20)
            .animation({ duration: 300 })
            .onClick(() => { this.toggleMode(1) })
          }
          .justifyContent(FlexAlign.Center)
          .margin({ bottom: 10 })

          Button(this.getTotalPending() > 0 ? '开始背词' : '今日任务完成了！')
            .height(56)
            .padding({ left: 40, right: 40 })
            .backgroundColor(this.getTotalPending() > 0 ? '#0A59F7' : '#52C41A')
            .fontColor(Color.White).fontSize(18).fontWeight(FontWeight.Medium)
            .shadow({ radius: 20, color: this.getTotalPending() > 0 ? 'rgba(10, 89, 247, 0.3)' : 'rgba(82, 196, 26, 0.3)', offsetY: 10 })
            .onClick(() => { this.pageStack.pushPath({ name: 'ReviewPage' }); })
            .margin({ bottom: 30, top: 5 })
        }
        .width('100%').height('100%').backgroundColor('#F5F7FA')
      }
      .tabBar(this.TabBuilder('主页', 0, $r('sys.symbol.clock')))

      TabContent() {
        PracticeHubPage()
      }
      .tabBar(this.TabBuilder('练习', 1, $r('sys.symbol.square_grid_2x2')))

      TabContent() {
        Column() {
          Text('学习分析').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#1A1A1A').width('100%').padding({ top: 60, left: 24, bottom: 20 })
          Scroll() {
            Column({ space: 20 }) {
              Column() {
                Text('学习热力榜 (最近 28 天)').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333').width('100%').margin({ bottom: 15 })
                Grid() {
                  ForEach(this.dateList, (date: string) => { GridItem() { Rect().width('100%').height(24).radius(4).fill(this.getHeatmapColor(this.heatmapData.get(date) || 0)) } })
                }.columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr').rowsGap(6).columnsGap(6).height(130)
              }.width('90%').padding(20).backgroundColor(Color.White).borderRadius(16).shadow({ radius: 10, color: 'rgba(0,0,0,0.05)' })

              Column() {
                Text('效率分析').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333').width('100%').margin({ bottom: 20 })
                SimpleLineChart({ data: this.chartData })
              }.width('90%').padding(20).backgroundColor(Color.White).borderRadius(16).shadow({ radius: 10, color: 'rgba(0,0,0,0.05)' })
            }.width('100%')
          }.layoutWeight(1)
        }
        .width('100%').height('100%').backgroundColor('#F5F7FA')
      }
      .tabBar(this.TabBuilder('分析', 2, $r('sys.symbol.calendar_fill')))
    }
    // [关键修改] 这里 barHeight 调整为 80，提高导航栏高度
    .scrollable(false).barHeight(80).onChange((index) => { this.currentIndex = index; this.refreshStats(); })
  }

  @Builder TabBuilder(title: string, targetIndex: number, icon: Resource) {
    Column() {
      SymbolGlyph(icon)
      // [微调] 稍微增大图标尺寸 (24 -> 28) 以适配更高的导航栏
        .fontSize(28)
        .fontColor(this.currentIndex === targetIndex ? ['#0A59F7'] : ['#999'])
        .symbolEffect(new BounceSymbolEffect(EffectScope.WHOLE, this.currentIndex === targetIndex ? 1 : 0))

      // [微调] 稍微增大文字尺寸 (10 -> 12)
      Text(title).fontSize(12).fontColor(this.currentIndex === targetIndex ? '#0A59F7' : '#999').margin({ top: 4 })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center)
  }
}