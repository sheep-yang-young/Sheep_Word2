import { DatabaseManager } from '../utils/DatabaseManager';
import { WordImporter } from '../utils/WordImporter';
import { DashboardStats } from '../model/WordModel';
import { common } from '@kit.AbilityKit';
import { ReviewPage } from './ReviewPage';
import { VocabularyPage } from './VocabularyPage';
import { SettingsPage } from './SettingsPage';
import { ZenPage } from './ZenPage';
import { WelcomePage } from './WelcomePage';
import { AboutPage } from './AboutPage';
import { ListenPracticePage } from './ListenPracticePage';
import { SentencePracticePage } from './SentencePracticePage';
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

    // 检查是否首次启动
    this.isFirstLaunch = await PreferenceManager.getInstance().isFirstLaunch();

    // [核心新增] 如果是首次启动，自动初始化默认词库 (CET-4)
    if (this.isFirstLaunch) {
      await this.initDefaultBook(context);
    }

    this.isReady = true;
    this.refreshFlag++;
  }

  // 自动导入 CET-4 作为默认书
  async initDefaultBook(context: common.Context): Promise<void> {
    try {
      const defaultBookName = "CET-4";
      // 尝试导入 rawfile/dicts/CET4.json
      const count = await WordImporter.importFromRawFile(context as common.UIAbilityContext, 'CET4.json', defaultBookName);
      if (count > 0) {
        await PreferenceManager.getInstance().setCurrentBook(defaultBookName);
        console.info('[Lumina] Default book initialized:', defaultBookName);
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
    else if (name === 'ListenPracticePage') { ListenPracticePage() }
    else if (name === 'SentencePracticePage') { SentencePracticePage() }
  }

  build() {
    Stack() {
      if (this.isReady) {
        if (this.isFirstLaunch) {
          // 引导页
          WelcomePage({
            onFinish: () => {
              animateTo({ duration: 300 }, () => {
                this.isFirstLaunch = false;
              })
              // 引导结束后再刷一次数据，确保主页显示正确
              this.refreshFlag++;
            }
          })
            .zIndex(999)
        } else {
          // 主应用
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

  // 默认显示占位符，数据加载后会更新
  @State selectedBook: string = "请选择词书";
  @State reviewMode: number = 0;
  @State dailyLimit: number = 20;
  @State todayRemaining: number = 20;

  async aboutToAppear(): Promise<void> {
    this.reviewMode = await PreferenceManager.getInstance().getReviewMode();
    this.selectedBook = await PreferenceManager.getInstance().getCurrentBook();

    // 如果读出来是 Default Library 但实际上可能是还没初始化的状态
    // 这里做一个防御性显示
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

    // [逻辑优化] 每次刷新前，重新确认一下当前书名
    // 防止如果是首次启动，aboutToAppear 时还没拿到正确的书名
    this.selectedBook = await PreferenceManager.getInstance().getCurrentBook();

    // 如果还是默认值且没数据，尝试找一本有数据的
    if (this.selectedBook === "Default Library" || this.selectedBook === "请选择词书") {
      const valid = await db.findAnyValidBook();
      if (valid !== "Default Library") {
        this.selectedBook = valid;
        await PreferenceManager.getInstance().setCurrentBook(valid);
      } else {
        this.selectedBook = "请选择词书";
      }
    }

    this.stats = await db.getDashboardStats(this.selectedBook);
    this.todayRemaining = Math.max(0, this.dailyLimit - this.stats.learnedToday);
    this.chartData = await db.getProficiencyDistribution(this.selectedBook);
    this.heatmapData = await db.getActivityStats();
    this.dailyLimit = await PreferenceManager.getInstance().getDailyLimit();
    this.generateDateList();
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
      let fileName = '';
      let bookName = '';
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
    const list: string[] = [];
    const today = new Date();
    for (let i = 27; i >= 0; i--) {
      const d = new Date(); d.setDate(today.getDate() - i);
      const dateStr = `${d.getFullYear()}-${(d.getMonth()+1).toString().padStart(2, '0')}-${d.getDate().toString().padStart(2, '0')}`;
      list.push(dateStr);
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

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        Column() {
          // 顶部栏
          Row() {
            Column({ space: 4 }) {
              Text('当前计划').fontSize(12).fontColor('#999')
              Row() {
                Text(this.selectedBook).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
                SymbolGlyph($r('sys.symbol.chevron_down')).fontSize(16).fontColor(['#1A1A1A']).margin({ left: 4 })
              }.onClick(() => { this.handleSwitchBook() })
            }
            .layoutWeight(1)

            Blank().width(12)

            // Streak
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
                    this.dailyLimit > 0
                      ? Math.min(1, this.stats.learnedToday / this.dailyLimit) * 692
                      : 0,
                    692
                  ])
                  .animation({ duration: 600, curve: Curve.EaseOut })

                Column() {
                  Text(this.todayRemaining.toString())
                    .fontSize(64).fontWeight(FontWeight.Bolder).fontColor('#1A1A1A')

                  Text('今日剩余').fontSize(14).fontColor('#999').margin({ top: 5 })

                  Text(`已学: ${this.stats.learnedToday} / ${this.dailyLimit}`)
                    .fontSize(14).fontColor('#0A59F7').fontWeight(FontWeight.Medium)
                    .backgroundColor('rgba(10, 89, 247, 0.1)')
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .borderRadius(10).margin({ top: 10 })
                }
              }.margin({ top: 40 })
            }
            .width('100%')
          }
          .layoutWeight(1).scrollBar(BarState.Off)

          // 模式切换
          Column({ space: 8 }) {
            Row() {
              Row() {
                Image($r('sys.media.ohos_ic_public_paste')).width(18).height(18).fillColor(this.reviewMode === 0 ? '#FFF' : '#666')
                Text('卡片模式').fontSize(14).fontColor(this.reviewMode === 0 ? '#FFF' : '#666').fontWeight(FontWeight.Medium).margin({ left: 6 })
              }
              .padding({ top: 10, bottom: 10, left: 24, right: 24 }).backgroundColor(this.reviewMode === 0 ? '#0A59F7' : 'transparent').borderRadius(20).animation({ duration: 300 }).onClick(() => { this.toggleMode(0) })

              Row() {
                Image($r('sys.media.ohos_ic_public_edit')).width(18).height(18).fillColor(this.reviewMode === 1 ? '#FFF' : '#666')
                Text('拼写模式').fontSize(14).fontColor(this.reviewMode === 1 ? '#FFF' : '#666').fontWeight(FontWeight.Medium).margin({ left: 6 })
              }
              .padding({ top: 10, bottom: 10, left: 24, right: 24 }).backgroundColor(this.reviewMode === 1 ? '#0A59F7' : 'transparent').borderRadius(20).animation({ duration: 300 }).onClick(() => { this.toggleMode(1) })
            }

            Row({ space: 10 }) {
              Button('听写')
                .layoutWeight(1)
                .height(44)
                .backgroundColor('#FFF')
                .fontColor('#0A59F7')
                .fontWeight(FontWeight.Medium)
                .borderRadius(16)
                .onClick(() => { this.pageStack.pushPath({ name: 'ListenPracticePage' }) })

              Button('例句练习')
                .layoutWeight(1)
                .height(44)
                .backgroundColor('#FFF')
                .fontColor('#7C3AED')
                .fontWeight(FontWeight.Medium)
                .borderRadius(16)
                .onClick(() => { this.pageStack.pushPath({ name: 'SentencePracticePage' }) })
            }
          }
          .backgroundColor('#E6E8EB').borderRadius(24).padding(8).margin({ bottom: 10 })

          Button(this.todayRemaining > 0 ? '开始背单词' : '今日目标已达成')
            .width('85%').height(56)
            .backgroundColor(this.todayRemaining > 0 ? '#0A59F7' : '#52C41A')
            .fontColor(Color.White).fontSize(18).fontWeight(FontWeight.Medium)
            .shadow({ radius: 20, color: this.todayRemaining > 0 ? 'rgba(10, 89, 247, 0.3)' : 'rgba(82, 196, 26, 0.3)', offsetY: 10 })
            .onClick(() => { this.pageStack.pushPath({ name: 'ReviewPage' }); })
            .margin({ bottom: 30, top: 5 })
        }
        .width('100%').height('100%').backgroundColor('#F5F7FA')
      }
      .tabBar(this.TabBuilder('学习', 0, $r('sys.symbol.clock')))

      // --- Tab 2: 数据分析 ---
      TabContent() {
        Column() {
          Text('学习数据分析').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#1A1A1A').width('100%').padding({ top: 60, left: 24, bottom: 20 })
          Scroll() {
            Column({ space: 20 }) {
              Column() {
                Text('学习热力图 (近30天)').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333').width('100%').margin({ bottom: 15 })
                Grid() {
                  ForEach(this.dateList, (date: string) => { GridItem() { Rect().width('100%').height(24).radius(4).fill(this.getHeatmapColor(this.heatmapData.get(date) || 0)) } })
                }.columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr').rowsGap(6).columnsGap(6).height(130)
              }.width('90%').padding(20).backgroundColor(Color.White).borderRadius(16).shadow({ radius: 10, color: 'rgba(0,0,0,0.05)' })

              Column() {
                Text('单词熟练度分布').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333').width('100%').margin({ bottom: 20 })
                SimpleLineChart({ data: this.chartData })
              }.width('90%').padding(20).backgroundColor(Color.White).borderRadius(16).shadow({ radius: 10, color: 'rgba(0,0,0,0.05)' })
            }.width('100%')
          }.layoutWeight(1)
        }
        .width('100%').height('100%').backgroundColor('#F5F7FA')
      }
      .tabBar(this.TabBuilder('分析', 1, $r('sys.symbol.calendar_fill')))
    }
    .scrollable(false).barHeight(60).onChange((index) => { this.currentIndex = index; this.refreshStats(); })
  }

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
}