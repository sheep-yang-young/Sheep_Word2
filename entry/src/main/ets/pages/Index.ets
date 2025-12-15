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
import { DailyNewsPage } from './DailyNewsPage';
import { SimpleLineChart, CleanCard } from '../components/CustomComponents';
import { PreferenceManager } from '../utils/PreferenceManager';
import { NewsWebPage } from './NewsWebPage';
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
    else if (name === 'DailyNewsPage') { DailyNewsPage() }
    else if (name === 'NewsWebPage') { NewsWebPage() }
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
// --- 数据结构 ---
interface SheepSkin {
  id: number;
  name: string;
  limit: number;
  icon: Resource;
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
  @State selectedBook: string = "请选择词书";
  @State reviewMode: number = 0;
  @State dailyLimit: number = 20;

  @State currentSkinIndex: number = 0;
  @State sheepScale: number = 1;

  skins: SheepSkin[] = [
    { id: 0, name: '初级小羊', limit: 0, icon: $r('app.media.icon') },
    { id: 1, name: '学霸小羊', limit: 100, icon: $r('app.media.icon') },
    { id: 2, name: '单词之王', limit: 500, icon: $r('app.media.icon') }
  ];

  warehouseController: CustomDialogController = new CustomDialogController({
    builder: WoolWarehouseDialog({
      masteredCount: this.stats.mastered,
      skins: this.skins,
      currentSkinIndex: this.currentSkinIndex,
      onSelectSkin: (index: number) => { this.currentSkinIndex = index; }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: true,
    customStyle: true
  });

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
    this.generateDateList();
  }

  getTotalPending(): number { return Math.max(0, (this.stats.dueReviews || 0) + (this.stats.newToday || 0)); }

  getSheepImage(): Resource {
    if (this.getTotalPending() > 0) {
      return $r('app.media.icon');
    }
    return this.skins[this.currentSkinIndex].icon;
  }

  interactWithSheep() {
    animateTo({ duration: 100, onFinish: () => { animateTo({ duration: 100 }, () => this.sheepScale = 1) } }, () => {
      this.sheepScale = 1.2;
    });

    const pending = this.getTotalPending();
    if (pending > 0) {
      promptAction.showToast({ message: `咩~ 我好饿，还有 ${pending} 堆草(单词)没吃！` });
    } else {
      promptAction.showToast({ message: '咩~ 吃得好饱！身上的羊毛更亮了！' });
    }
  }

  // [修复] 加回了切换词书的逻辑函数
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
    return '#1890FF';
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      // 1. 牧场主页
      TabContent() {
        Column() {
          Row() {
            // [修复] 恢复点击事件，点击书名调用 handleSwitchBook
            Column({ space: 4 }) {
              Text('当前牧场').fontSize(12).fontColor('#999')
              Row() {
                Text(this.selectedBook).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
                SymbolGlyph($r('sys.symbol.chevron_down')).fontSize(16).fontColor(['#1A1A1A']).margin({ left: 4 })
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            .onClick(() => { this.handleSwitchBook() }) // 绑定点击事件

            // 羊毛仓库按钮
            Button({ type: ButtonType.Capsule }) {
              Row({ space: 4 }) {
                SymbolGlyph($r('sys.symbol.gift')).fontSize(16).fontColor([Color.White])
                Text('羊毛仓库').fontSize(12).fontColor(Color.White)
              }
            }
            .height(32).backgroundColor('#FA8C16').margin({ right: 10 })
            .onClick(() => { this.warehouseController.open() })

            // ZenPage 月亮按钮
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.moon'))
                .fontSize(22)
                .fontColor(['#FFFFFF'])
                .fontWeight(FontWeight.Medium)
            }
            .width(36).height(36)
            .backgroundColor('#ffb689ff')
            .margin({ right: 12 })
            .onClick(() => {
              this.pageStack.pushPath({ name: 'ZenPage' })
            })

            // 设置按钮
            SymbolGlyph($r('sys.symbol.gearshape')).fontSize(24).fontColor(['#333'])
              .onClick(() => { this.pageStack.pushPath({ name: 'SettingsPage' }) })
          }
          .width('100%').padding({ top: 50, left: 24, right: 24, bottom: 10 })

          Scroll() {
            Column({ space: 20 }) {
              Stack({ alignContent: Alignment.Bottom }) {
                Column()
                  .width('100%').height(280)
                  .backgroundColor(this.getTotalPending() > 0 ? '#E6F7FF' : '#F6FFED')
                  .borderRadius(24)
                  .shadow({ radius: 20, color: 'rgba(0,0,0,0.05)' })

                Column() {
                  if (this.getTotalPending() > 0) {
                    Text(`还有 ${this.getTotalPending()} 个词没背...`).fontSize(12).fontColor('#fff').backgroundColor('#FF4D4F').padding(8).borderRadius(12).margin({bottom: 10})
                      .animation({ duration: 500, curve: Curve.EaseInOut })
                  } else {
                    Text(`今日任务达成！`).fontSize(12).fontColor('#fff').backgroundColor('#52C41A').padding(8).borderRadius(12).margin({bottom: 10})
                  }

                  Image(this.getSheepImage())
                    .height(160)
                    .objectFit(ImageFit.Contain)
                    .scale({ x: this.sheepScale, y: this.sheepScale })
                    .onClick(() => this.interactWithSheep())
                }
                .padding({ bottom: 40 })

                Row() {
                  Text(`Mastered: ${this.stats.mastered}`).fontSize(12).fontColor('#666').fontWeight(FontWeight.Bold)
                  Blank()
                  Text(`Daily Goal: ${this.stats.learnedToday}/${this.dailyLimit}`).fontSize(12).fontColor('#666').fontWeight(FontWeight.Bold)
                }
                .width('100%').padding(20)
              }
              .height(300).width('100%').padding({ left: 20, right: 20 })

              // --- 快捷入口 ---
              Row({ space: 12 }) {
                this.QuickActionCard('开始喂草', '背单词', '#0A59F7', $r('sys.symbol.play_circle'), () => {
                  this.pageStack.pushPath({ name: 'ReviewPage' })
                })

                // 每日新闻入口
                this.QuickActionCard('每日新闻', 'China Daily', '#FA8C16', $r('sys.symbol.doc_text'), () => {
                  this.pageStack.pushPath({ name: 'DailyNewsPage' })
                })
              }.padding({ left: 20, right: 20 })

              Column() {
                Text('近期活跃').fontSize(16).fontWeight(FontWeight.Bold).width('100%').margin({ bottom: 10 })
                Grid() {
                  ForEach(this.dateList, (date: string) => { GridItem() { Rect().width('100%').height(16).radius(4).fill(this.getHeatmapColor(this.heatmapData.get(date) || 0)) } })
                }.columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr').height(80).rowsGap(4).columnsGap(4)
              }
              .padding(20).backgroundColor(Color.White).borderRadius(16).margin({ left: 20, right: 20 })
            }
            .padding({ bottom: 100 })
          }
          .layoutWeight(1).scrollBar(BarState.Off)
        }
        .width('100%').height('100%').backgroundColor('#F5F7FA')
      }
      .tabBar(this.TabBuilder('牧场', 0, $r('sys.symbol.house')))

      // 2. 练习页
      TabContent() { PracticeHubPage() }
      .tabBar(this.TabBuilder('游乐场', 1, $r('sys.symbol.square_grid_2x2')))

      // 3. 分析页
      TabContent() {
        Column() {
          Text('详细数据分析').fontSize(24).padding(30)
          SimpleLineChart({ data: this.chartData })
        }.width('100%').height('100%')
      }
      .tabBar(this.TabBuilder('档案', 2, $r('sys.symbol.doc_plaintext')))
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

  @Builder QuickActionCard(title: string, sub: string, color: string, icon: Resource, action: () => void) {
    Row() {
      Column({ space: 4 }) {
        Text(title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White)
        Text(sub).fontSize(12).fontColor('rgba(255,255,255,0.8)')
      }.alignItems(HorizontalAlign.Start)
      Blank()
      SymbolGlyph(icon).fontSize(24).fontColor([Color.White])
    }
    .layoutWeight(1)
    .height(80)
    .backgroundColor(color)
    .borderRadius(16)
    .padding(16)
    .shadow({ radius: 10, color: color + '40', offsetY: 5 })
    .onClick(action)
  }
}

// --- 羊毛仓库弹窗 (皮肤选择) ---
@CustomDialog
struct WoolWarehouseDialog {
  controller: CustomDialogController;
  masteredCount: number = 0;
  skins: SheepSkin[] = [];
  currentSkinIndex: number = 0;
  onSelectSkin: (index: number) => void = () => {};

  build() {
    Column() {
      Text('羊毛仓库').fontSize(20).fontWeight(FontWeight.Bold).margin({ top: 20, bottom: 5 })
      Text(`已掌握词汇: ${this.masteredCount}`).fontSize(12).fontColor('#666').margin({ bottom: 20 })

      List({ space: 12 }) {
        ForEach(this.skins, (skin: SheepSkin, index: number) => {
          ListItem() {
            Row() {
              Image(skin.icon).width(40).height(40).margin({ right: 12 }).opacity(this.masteredCount >= skin.limit ? 1 : 0.5)
              Column({ space: 4 }) {
                Text(skin.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.masteredCount >= skin.limit ? '#333' : '#999')
                if (this.masteredCount < skin.limit) {
                  Text(`还需 ${skin.limit - this.masteredCount} 词解锁`).fontSize(12).fontColor('#FF4D4F')
                } else {
                  Text('已解锁').fontSize(12).fontColor('#52C41A')
                }
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)

              if (this.masteredCount >= skin.limit) {
                Radio({ value: skin.id.toString(), group: 'skins' })
                  .checked(index === this.currentSkinIndex)
                  .onChange((isChecked: boolean) => {
                    if (isChecked) this.onSelectSkin(index);
                  })
              } else {
                SymbolGlyph($r('sys.symbol.lock')).fontSize(20).fontColor(['#CCC'])
              }
            }
            .width('100%').padding(12).backgroundColor('#F9F9F9').borderRadius(12)
          }
        })
      }
      .width('100%').height(300)

      Button('关闭')
        .width('90%').height(40).margin({ top: 20, bottom: 20 })
        .backgroundColor('#F0F2F5').fontColor('#333')
        .onClick(() => { this.controller.close() })
    }
    .width('90%')
    .backgroundColor(Color.White)
    .borderRadius(24)
  }
}