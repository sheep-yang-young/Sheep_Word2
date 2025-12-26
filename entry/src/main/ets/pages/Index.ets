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
import { PracticeHubPage } from './PracticeHubPage';
import { SpellChallengePage } from './SpellChallengePage';
import { DictationPage } from './DictationPage';
import { FlashTFPage } from './FlashTFPage';
import { MatchPairsPage } from './MatchPairsPage';
import { TimeAttackPage } from './TimeAttackPage';
import { DailyNewsPage } from './DailyNewsPage';
import { SimpleLineChart, CleanCard } from '../components/CustomComponents';
import { PreferenceManager } from '../utils/PreferenceManager';
import { NewsReaderPage } from './NewsReaderPage';
import { PodcastPage } from './PodcastPage';
import { CustomImportPage } from './CustomImportPage';
import { promptAction, router } from '@kit.ArkUI'; // [修复] 补充 router 导入
import { StorePage } from './StorePage';
import { CloudBook, CloudBookManager } from '../utils/CloudBookManager';
import { ScreenshotGalleryPage } from './ScreenshotGalleryPage';

const LOCAL_BOOKS: CloudBook[] = [
  { id: 'local_cet4', name: 'CET-4', category: 'English', size: '内置', desc: '大学英语四级核心词汇', version: 1 },
  { id: 'local_cet6', name: 'CET-6', category: 'English', size: '内置', desc: '大学英语六级进阶词汇', version: 1 },
  { id: 'local_gre', name: 'GRE8000', category: 'English', size: '内置', desc: 'GRE 核心 8000 词', version: 1 },
  { id: 'local_toefl', name: 'TOEFL', category: 'English', size: '内置', desc: '托福高频词汇', version: 1 },
  // { id: 'linux_cmd', name: 'Linux_cmd', category: 'Code', size: '内置', desc: '常用Linux指令', version: 1 }
];

@Entry
@Component
struct Index {
  @Provide('pageStack') pageStack: NavPathStack = new NavPathStack();
  @Provide refreshFlag: number = 0;

  @State isShowSettingsSheet: boolean = false;
  @State dailyLimit: number = 20;

  @State isFirstLaunch: boolean = false;
  @State isReady: boolean = false;

  // [修复] 监听全局跳转请求 (必须定义在 struct 内部)
  @StorageProp('NavigateToCapsuleImport') @Watch('onNavigateRequest') navigateFlag: boolean = false;
  @StorageProp('NavigateToScreenshotBox') @Watch('onNavigateScreenshotRequest') navigateScreenshotFlag: boolean = false;

  onNavigateRequest() {
    if (this.navigateFlag) {
      // 重置标记，防止重复跳转
      AppStorage.setOrCreate('NavigateToCapsuleImport', false);
      // 跳转到截图导入页
      router.pushUrl({ url: 'pages/CapsuleImportPage' });
    }
  }

  onNavigateScreenshotRequest() {
    if (this.navigateScreenshotFlag) {
      AppStorage.setOrCreate('NavigateToScreenshotBox', false);
      router.pushUrl({ url: 'pages/ScreenshotGalleryPage' });
    }
  }

  async aboutToAppear(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    await PreferenceManager.getInstance().init(context);
    await DatabaseManager.getInstance().init(context);
    this.dailyLimit = await PreferenceManager.getInstance().getDailyLimit();

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
      const pref = PreferenceManager.getInstance();
      const exists = await DatabaseManager.getInstance().checkBookExists(defaultBookName);
      if (!exists) {
        const count = await WordImporter.importFromRawFile(context as common.UIAbilityContext, 'CET4.json', defaultBookName);
        if (count > 0) {
          await pref.registerBookCategory(defaultBookName, 'English');
          await pref.setCurrentBook(defaultBookName);
        }
      } else {
        await pref.registerBookCategory(defaultBookName, 'English');
        await pref.setCurrentBook(defaultBookName);
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
    else if (name === 'ZenPage') { ZenPage() }
    else if (name === 'AboutPage') { AboutPage() }
    else if (name === 'SpellChallengePage') { SpellChallengePage() }
    else if (name === 'DictationPage') { DictationPage() }
    else if (name === 'FlashTFPage') { FlashTFPage() }
    else if (name === 'MatchPairsPage') { MatchPairsPage() }
    else if (name === 'TimeAttackPage') { TimeAttackPage() }
    else if (name === 'DailyNewsPage') { DailyNewsPage() }
    else if (name === 'NewsWebPage') { NewsReaderPage() }
    else if (name === 'PodcastPage') { PodcastPage() }
    else if (name === 'CustomImportPage') { CustomImportPage() }
    else if (name === 'StorePage') { StorePage() }
    else if (name === 'ScreenshotGalleryPage') { ScreenshotGalleryPage() }
  }

  @Builder
  SettingsSheetBuilder() {
    Column() {
      SettingsPage({ dailyLimit: $dailyLimit, isShowSettingsSheet: $isShowSettingsSheet })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FA')
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
            HomePage({
              isShowSettingsSheet: $isShowSettingsSheet,
              dailyLimit: $dailyLimit
            })
          }
          .navDestination(this.PagesMap)
          .mode(NavigationMode.Stack)
          .hideTitleBar(true)
        }
      }
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.isShowSettingsSheet, this.SettingsSheetBuilder(), {
      detents: [SheetSize.LARGE],
      backgroundColor: '#F5F7FA',
      dragBar: true,
      blurStyle: BlurStyle.Thick
    })
  }
}

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

  @Link isShowSettingsSheet: boolean;
  @Link dailyLimit: number;

  @State currentIndex: number = 0;
  @State stats: DashboardStats = new DashboardStats();
  @State chartData: number[] = [0, 0, 0, 0, 0];
  @State heatmapData: Map<string, number> = new Map();
  @State activityTrend: number[] = [];
  @State dateList: string[] = [];

  @State selectedBook: string = "请选择词书";
  @State reviewMode: number = 0;
  @State currentSkinIndex: number = 0;
  @State sheepScale: number = 1;

  @State isShowBookSheet: boolean = false;
  @State bookList: CloudBook[] = [];
  @State downloadedBooks: string[] = [];
  @State isSheetLoading: boolean = false;
  @State downloadingBookId: string = '';

  skins: SheepSkin[] = [
    { id: 0, name: '初级小羊', limit: 0, icon: $r('app.media.sheep_skin_0') },
    { id: 1, name: '学霸小羊', limit: 100, icon: $r('app.media.sheep_skin_1') },
    { id: 2, name: '单词之王', limit: 500, icon: $r('app.media.sheep_skin_2') }
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
    this.refreshStats();
    this.bookList = [...LOCAL_BOOKS];
    await this.checkDownloadedStatus();
  }

  async checkDownloadedStatus() {
    const db = DatabaseManager.getInstance();
    const existingBooks = new Set(await db.listAllBooks());
    const newDownloadedList: string[] = [];

    for (const book of this.bookList) {
      if (book.size === '内置' || existingBooks.has(book.name)) {
        newDownloadedList.push(book.name);
      }
    }
    this.downloadedBooks = Array.from(new Set(newDownloadedList));
  }

  async loadBooks() {
    this.isSheetLoading = true;
    const db = DatabaseManager.getInstance();
    const pref = PreferenceManager.getInstance();
    const mergedList: CloudBook[] = [...LOCAL_BOOKS];
    const seenNames = new Set<string>(LOCAL_BOOKS.map(book => book.name));

    try {
      const cloud = await CloudBookManager.getManifest();
      if (cloud && cloud.length > 0) {
        cloud.forEach(book => {
          if (!seenNames.has(book.name)) {
            mergedList.push(book);
            seenNames.add(book.name);
          }
        });
      }

      const localBooks = await db.listAllBooks();
      for (const name of localBooks) {
        if (!name || name === 'Default Library') continue;
        if (seenNames.has(name)) continue;

        const category = await pref.getBookCategory(name) ?? 'User';
        mergedList.push({
          id: name,
          name,
          category,
          size: '本地',
          desc: '用户自定义词书',
          version: 1
        });
        seenNames.add(name);
      }
    } catch (e) {
      console.error('Fetch cloud books error:', e);
      promptAction.showToast({ message: '获取云端列表失败，请检查服务器配置' });
    } finally {
      this.bookList = mergedList;
      await this.checkDownloadedStatus();
      this.isSheetLoading = false;
    }
  }

  onRefreshTriggered(): void {
    this.refreshStats();
  }

  async refreshStats(): Promise<void> {
    const db = DatabaseManager.getInstance();
    const pref = PreferenceManager.getInstance();

    this.reviewMode = await pref.getReviewMode();
    this.selectedBook = await pref.getCurrentBook();

    const isValid = this.selectedBook && this.selectedBook !== "Default Library" && this.selectedBook !== "请选择词书";
    if (!isValid) {
      const valid = await db.findAnyValidBook();
      if (valid && await db.checkBookExists(valid)) {
        this.selectedBook = valid;
        const inferredCategory = this.getBookCategoryFromRegistry(valid);
        if (inferredCategory) {
          await pref.registerBookCategory(valid, inferredCategory);
        }
        await pref.setCurrentBook(valid);
      } else {
        this.selectedBook = "Default Library";
      }
    }

    const results = await Promise.all([
      db.getDashboardStats(this.selectedBook, this.dailyLimit, this.reviewMode),
      db.getProficiencyDistribution(this.selectedBook),
      db.getActivityStats()
    ]);

    this.stats = results[0] as DashboardStats;
    this.chartData = results[1] as number[];
    this.heatmapData = results[2] as Map<string, number>;

    this.generateDateList();
    this.activityTrend = this.dateList.map(date => this.heatmapData.get(date) || 0);
  }

  getTotalPending(): number {
    return Math.max(0, (this.stats.dueReviews || 0) + (this.stats.newToday || 0));
  }

  getSheepImage(): Resource {
    if (this.getTotalPending() > 0) {
      return $r('app.media.sheep_hungry');
    }
    return this.skins[this.currentSkinIndex].icon;
  }

  interactWithSheep() {
    animateTo({ duration: 100, onFinish: () => { animateTo({ duration: 100 }, () => this.sheepScale = 1) } }, () => { this.sheepScale = 1.2; });
    const pending = this.getTotalPending();
    promptAction.showToast({ message: pending > 0 ? `咩~ 我好饿，还有 ${pending} 堆草(单词)没吃！` : '咩~ 吃得好饱！身上的羊毛更亮了！' });
  }

  async handleBookClick(book: CloudBook) {
    if (this.selectedBook === book.name) return;

    const db = DatabaseManager.getInstance();
    const isLocalBook = book.size === '本地' || book.category === 'User';

    if (isLocalBook) {
      const wordCount = await db.getBookWordCount(book.name);
      if (wordCount === 0) {
        promptAction.showToast({ message: '该本地词书暂无内容，切换后请先导入词条' });
      }
      await this.switchBookLogic(book);
      return;
    }

    const context = getContext(this) as common.UIAbilityContext;

    const exists = await db.checkBookExists(book.name);

    if (exists) {
      await this.switchBookLogic(book);
    } else {
      if (book.size === '内置') {
        await this.importLocalBook(context, book);
      } else {
        await this.downloadAndImportBook(book, context);
      }
    }
  }

  async importLocalBook(context: common.UIAbilityContext, book: CloudBook) {
    this.downloadingBookId = book.id;
    let fileName = '';

    if (book.name === 'CET-4') fileName = 'CET4.json';
    else if (book.name === 'CET-6') fileName = 'CET6.json';
    else if (book.name === 'GRE8000') fileName = 'GRE8000.json';
    else if (book.name === 'TOEFL') fileName = 'TOEFL.json';
    // else if (book.name === 'linux_cmd')fileName = 'linux_cmd.json';

    if (fileName) {
      const count = await WordImporter.importFromRawFile(context, fileName, book.name);
      if (count > 0) {
        await this.checkDownloadedStatus();
        await this.switchBookLogic(book);
      } else {
        promptAction.showToast({ message: '内置词库加载失败' });
      }
    }
    this.downloadingBookId = '';
  }

  async downloadAndImportBook(book: CloudBook, context: common.UIAbilityContext) {
    this.downloadingBookId = book.id;
    try {
      const path = await CloudBookManager.downloadBook(book.category, book.id, context);
      if (path) {
        const count = await WordImporter.importJsonFileFromPath(context, path, book.name);
        if (count > 0) {
          await this.checkDownloadedStatus();
          await this.switchBookLogic(book);
        } else {
          promptAction.showToast({ message: '导入失败：文件格式错误' });
        }
      } else {
        promptAction.showToast({ message: '下载失败，请检查网络' });
      }
    } catch (e) {
      promptAction.showToast({ message: `错误: ${e.message}` });
    } finally {
      this.downloadingBookId = '';
    }
  }

  async switchBookLogic(book: CloudBook | string) {
    const bookName = typeof book === 'string' ? book : book.name;
    const categoryFromBook = typeof book === 'string' ? undefined : book.category;
    const pref = PreferenceManager.getInstance();

    const storedCategory = await pref.getBookCategory(bookName);
    const bookCategory = categoryFromBook ?? storedCategory ?? 'User';

    if (bookCategory) {
      await pref.registerBookCategory(bookName, bookCategory);
    }

    this.selectedBook = bookName;
    await pref.setCurrentBook(bookName);
    await this.refreshStats();
    this.isShowBookSheet = false;
    promptAction.showToast({ message: `已切换至 ${bookName}` });
  }

  private getBookCategoryFromRegistry(bookName: string): string | undefined {
    const target = this.bookList.find(item => item.name === bookName);
    return target?.category;
  }

  generateDateList(): void {
    const list: string[] = [];
    const today = new Date();
    for (let i = 27; i >= 0; i--) {
      const d = new Date();
      d.setDate(today.getDate() - i);
      list.push(`${d.getFullYear()}-${(d.getMonth() + 1).toString().padStart(2, '0')}-${d.getDate().toString().padStart(2, '0')}`);
    }
    this.dateList = list;
  }

  getHeatmapColor(count: number): string {
    if (count === 0) return '#F0F0F0';
    if (count <= 5) return '#BAE0FF';
    if (count <= 10) return '#69B1FF';
    return '#1890FF';
  }

  @Builder BookSheetBuilder() {
    Column() {
      Row() {
        if (this.isSheetLoading) {
          LoadingProgress().width(20).height(20).color('#999').margin({ right: 12 })
        } else {
          SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize(20).fontColor(['#999']).margin({ right: 12 }).onClick(() => this.loadBooks())
        }
        Text('我的书架').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333')
        Blank()
      }.width('100%').padding(20).alignItems(VerticalAlign.Center)

      List({ space: 12 }) {
        ForEach(this.bookList, (book: CloudBook) => {
          ListItem() {
              Row() {
                Column() {
                  if (book.size === '内置') {
                    SymbolGlyph($r('sys.symbol.bookmark')).fontSize(24).fontColor(this.selectedBook === book.name ? ['#0A59F7'] : ['#FA8C16'])
                  } else if (book.category === 'English') {
                    SymbolGlyph($r('sys.symbol.a_square_fill')).fontSize(28).fontColor(this.selectedBook === book.name ? ['#0A59F7'] : ['#888'])
                  } else if (book.category === 'User' || book.size === '本地') {
                    SymbolGlyph($r('sys.symbol.bookmark_filled_on_bookmark')).fontSize(24).fontColor(this.selectedBook === book.name ? ['#0A59F7'] : ['#888'])
                  } else {
                    Text('</>').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.selectedBook === book.name ? '#0A59F7' : '#888')
                  }
                }
                .width(48).height(48).backgroundColor(this.selectedBook === book.name ? '#E6F7FF' : '#F5F5F5')
                .borderRadius(12).justifyContent(FlexAlign.Center).margin({ right: 16 })

                Column({ space: 4 }) {
                  Row({ space: 6 }) {
                    Text(book.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#333')

                    if (this.selectedBook === book.name) {
                      Text('当前使用').fontSize(10).fontColor('#0A59F7').backgroundColor('#E6F7FF').padding({ left:6, right:6, top:2, bottom:2 }).borderRadius(8)
                    } else if (book.size === '内置') {
                      Text('内置').fontSize(10).fontColor('#FA8C16').backgroundColor('#FFF7E6').padding({ left:6, right:6, top:2, bottom:2 }).borderRadius(8)
                    } else if (book.category === 'User' || book.size === '本地') {
                      Text('本地').fontSize(10).fontColor('#389e0d').backgroundColor('#f6ffed').padding({ left:6, right:6, top:2, bottom:2 }).borderRadius(8)
                    } else {
                      Text('云端').fontSize(10).fontColor('#13c2c2').backgroundColor('#e6fffb').padding({ left:6, right:6, top:2, bottom:2 }).borderRadius(8)
                    }
                  }
                  Text(`${book.desc} · ${book.size}`).fontSize(12).fontColor('#999').maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)

              if (this.downloadingBookId === book.id) {
                LoadingProgress().width(24).height(24).color('#0A59F7')
              } else {
                Button(this.selectedBook === book.name ? '使用中' : (this.downloadedBooks.includes(book.name) ? '切换' : '下载'))
                  .fontSize(12)
                  .height(28)
                  .backgroundColor(this.selectedBook === book.name ? 'rgba(0,0,0,0.05)' : '#0A59F7')
                  .fontColor(this.selectedBook === book.name ? '#999' : '#FFF')
                  .onClick(() => this.handleBookClick(book))
                  .enabled(this.selectedBook !== book.name)
              }
            }
            .width('100%').padding(16).backgroundColor('#FFF').borderRadius(16)
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 16, right: 16, bottom: 30 })
      .edgeEffect(EdgeEffect.Spring)
      .cachedCount(10)
      .nestedScroll({
        scrollForward: NestedScrollMode.PARENT_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FA')
  }

  @Builder HomeContent() {
    Column() {
      // Top Bar
      Row() {
        Column({ space: 4 }) {
          Text('当前牧场').fontSize(12).fontColor('#999')
          Row() {
            Text(this.selectedBook).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
            SymbolGlyph($r('sys.symbol.chevron_down')).fontSize(16).fontColor(['#1A1A1A']).margin({ left: 4 })
          }
        }
        .layoutWeight(1).alignItems(HorizontalAlign.Start)
        .onClick(() => {
          this.isShowBookSheet = true;
          this.loadBooks();
        })

        Button({ type: ButtonType.Capsule }) {
          Row({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.gift')).fontSize(16).fontColor([Color.White])
            Text('羊毛仓库').fontSize(12).fontColor(Color.White)
          }
        }.height(32).backgroundColor('#FA8C16').margin({ right: 10 }).onClick(() => { this.warehouseController.open() })

        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.moon')).fontSize(22).fontColor(['#FFFFFF']).fontWeight(FontWeight.Medium)
        }.width(36).height(36).backgroundColor('#ffb689ff').margin({ right: 12 }).onClick(() => { this.pageStack.pushPath({ name: 'ZenPage' }) })

        SymbolGlyph($r('sys.symbol.gearshape'))
          .fontSize(24)
          .fontColor(['#333'])
          .onClick(() => {
            this.isShowSettingsSheet = true;
          })
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.85 })
      }
      .width('100%').padding({ top: 50, left: 24, right: 24, bottom: 10 })

      Scroll() {
        Column({ space: 20 }) {
          Stack({ alignContent: Alignment.Bottom }) {
            Column()
              .width('100%').height(280)
              .backgroundColor(this.getTotalPending() > 0 ? '#E6F7FF' : '#F6FFED')
              .borderRadius(24).shadow({ radius: 20, color: 'rgba(0,0,0,0.05)' })

            Column() {
              if (this.getTotalPending() > 0) {
                Text(`还有 ${this.getTotalPending()} 个词没背...`).fontSize(12).fontColor('#fff').backgroundColor('#FF4D4F').padding(8).borderRadius(12).margin({ bottom: 10 })
              } else {
                Text(`今日任务达成！`).fontSize(12).fontColor('#fff').backgroundColor('#52C41A').padding(8).borderRadius(12).margin({ bottom: 10 })
              }
              Image(this.getSheepImage())
                .height(160)
                .objectFit(ImageFit.Contain)
                .scale({ x: this.sheepScale, y: this.sheepScale })
                .onClick(() => this.interactWithSheep())
            }
            .padding({ bottom: 40 })
            .zIndex(2)

            Row() {
              Text(`Mastered: ${this.stats.mastered}`).fontSize(12).fontColor('#666').fontWeight(FontWeight.Bold)
              Blank()
              Text(`Daily Goal: ${this.stats.learnedToday}/${this.dailyLimit}`).fontSize(12).fontColor('#666').fontWeight(FontWeight.Bold)
            }
            .width('100%')
            .padding(20)
            .hitTestBehavior(HitTestMode.Transparent)
          }
          .height(300).width('100%').padding({ left: 20, right: 20 })

          Row({ space: 12 }) {
            this.QuickActionCard('开始喂草', '背单词', '#0A59F7', $r('sys.symbol.play_circle'), () => { this.pageStack.pushPath({ name: 'ReviewPage' }) })
            this.QuickActionCard('经典晨读', 'English', '#FA8C16', $r('sys.symbol.doc_text'), () => { this.pageStack.pushPath({ name: 'DailyNewsPage' }) })
          }.padding({ left: 20, right: 20 })

          Column() {
            Text('近期活跃').fontSize(16).fontWeight(FontWeight.Bold).width('100%').margin({ bottom: 10 })
            Grid() {
              ForEach(this.dateList, (date: string) => {
                GridItem() { Rect().width('100%').height(16).radius(4).fill(this.getHeatmapColor(this.heatmapData.get(date) || 0)) }
              })
            }.columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr').height(80).rowsGap(4).columnsGap(4)
          }.padding(20).backgroundColor(Color.White).borderRadius(16).margin({ left: 20, right: 20 })
        }.padding({ bottom: 100 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#F5F7FA')
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        if (this.currentIndex === 0) {
          Column() { this.HomeContent() }.transition({ type: TransitionType.All, opacity: 0 })
        } else {
          Column().width('100%').height('100%').backgroundColor('#F5F7FA')
        }
      }
      .tabBar(this.TabBuilder('牧场', 0, $r('sys.symbol.house')))

      TabContent() {
        if (this.currentIndex === 1) {
          Column() { PracticeHubPage() }.transition({ type: TransitionType.All, opacity: 0 })
        } else {
          Column().width('100%').height('100%').backgroundColor('#F5F7FA')
        }
      }
      .tabBar(this.TabBuilder('游乐场', 1, $r('sys.symbol.square_grid_2x2')))

      TabContent() {
        if (this.currentIndex === 2) {
          ArchiveView({ stats: $stats, chartData: $chartData, activityTrend: $activityTrend }).transition({ type: TransitionType.All, opacity: 0 })
        } else {
          Column().width('100%').height('100%').backgroundColor('#F5F7FA')
        }
      }
      .tabBar(this.TabBuilder('档案', 2, $r('sys.symbol.doc_plaintext')))
    }
    .scrollable(false)
    .barHeight(75)
    .onChange((index) => {
      animateTo({ duration: 300, curve: Curve.EaseInOut }, () => { this.currentIndex = index; })
      this.refreshStats();
    })
    .bindSheet($$this.isShowBookSheet, this.BookSheetBuilder(), {
      detents: [SheetSize.LARGE],
      backgroundColor: '#F5F7FA',
      dragBar: true,
      onDisappear: () => { this.downloadingBookId = '' }
    })
  }

  @Builder TabBuilder(title: string, targetIndex: number, icon: Resource) {
    Column() {
      SymbolGlyph(icon).fontSize(24)
        .fontColor(this.currentIndex === targetIndex ? ['#0A59F7'] : ['#999'])
        .symbolEffect(new BounceSymbolEffect(EffectScope.WHOLE, this.currentIndex === targetIndex ? 1 : 0))
      Text(title).fontSize(10).fontColor(this.currentIndex === targetIndex ? '#0A59F7' : '#999').margin({ top: 4 })
    }.width('100%').height('100%').justifyContent(FlexAlign.Center).offset({ y: -5 })
  }

  @Builder QuickActionCard(title: string, sub: string, color: string, icon: Resource, action: () => void) {
    Row() {
      Column({ space: 4 }) { Text(title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(Color.White); Text(sub).fontSize(12).fontColor('rgba(255,255,255,0.8)') }.alignItems(HorizontalAlign.Start)
      Blank(); SymbolGlyph(icon).fontSize(24).fontColor([Color.White])
    }.layoutWeight(1).height(80).backgroundColor(color).borderRadius(16).padding(16).shadow({ radius: 10, color: color + '40', offsetY: 5 }).onClick(action)
  }
}

@Component
struct ArchiveView {
  @Link stats: DashboardStats;
  @Link chartData: number[];
  @Link activityTrend: number[];

  build() {
    Column() {
      Text('数据档案').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#1A1A1A').width('100%').padding({ top: 60, left: 24, bottom: 20 })
      Scroll() {
        Column({ space: 16 }) {
          Grid() {
            GridItem() { this.StatCard('累计单词', this.stats.total.toString(), '#E6F7FF', '#0A59F7') }
            GridItem() { this.StatCard('已掌握', this.stats.mastered.toString(), '#F6FFED', '#52C41A') }
            GridItem() { this.StatCard('连续打卡', `${this.stats.streak} 天`, '#FFF7E6', '#FA8C16') }
            GridItem() { this.StatCard('今日学习', this.stats.learnedToday.toString(), '#FFF0F6', '#EB2F96') }
          }.columnsTemplate('1fr 1fr').rowsGap(12).columnsGap(12).height(180).padding({ left: 20, right: 20 })

          CleanCard() {
            Column() {
              Text('词汇熟练度分布').fontSize(16).fontWeight(FontWeight.Bold).width('100%').margin({ bottom: 20 })
              this.ProficiencyBarChart()
            }
          }

          CleanCard() {
            Column() {
              Text('近30天学习趋势').fontSize(16).fontWeight(FontWeight.Bold).width('100%').margin({ bottom: 20 })
              SimpleLineChart({ data: this.activityTrend })
            }
          }
        }.padding({ bottom: 100 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor('#F5F7FA')
  }

  @Builder StatCard(title: string, value: string, bgColor: string, accentColor: string) {
    Column() {
      Text(title).fontSize(12).fontColor('#666').margin({ bottom: 8 })
      Text(value).fontSize(24).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
    }.width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Start).padding(16).backgroundColor(Color.White).borderRadius(16).border({ width: 1, color: bgColor }).shadow({ radius: 10, color: 'rgba(0,0,0,0.02)' })
  }

  @Builder ProficiencyBarChart() {
    Row({ space: 8 }) {
      this.BarItem('陌生', this.chartData[0], '#FF4D4F')
      this.BarItem('初识', this.chartData[1], '#FAAD14')
      this.BarItem('了解', this.chartData[2], '#FADB14')
      this.BarItem('熟悉', this.chartData[3], '#A0D911')
      this.BarItem('掌握', this.chartData[4], '#52C41A')
    }.width('100%').height(180).alignItems(VerticalAlign.Bottom)
  }

  @Builder BarItem(label: string, value: number, color: string) {
    Column() {
      Column().width('60%').height(`${Math.max(5, (value / (Math.max(...this.chartData, 10))) * 70)}%`).backgroundColor(color).borderRadius({ topLeft: 8, topRight: 8 }).animation({ duration: 500, curve: Curve.EaseOut })
      Text(value.toString()).fontSize(10).fontColor('#999').margin({ top: 4, bottom: 2 })
      Text(label).fontSize(12).fontColor('#666')
    }.layoutWeight(1).height('100%').justifyContent(FlexAlign.End)
  }
}

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
                if (this.masteredCount >= skin.limit) {
                  Text(skin.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#333')
                  Text('已解锁').fontSize(12).fontColor('#52C41A')
                } else {
                  Text(skin.name).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#999')
                  Text(`还需 ${skin.limit - this.masteredCount} 词解锁`).fontSize(12).fontColor('#FF4D4F')
                }
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)

              if (this.masteredCount >= skin.limit) {
                Radio({ value: skin.id.toString(), group: 'skins' }).checked(index === this.currentSkinIndex).onChange((isChecked: boolean) => { if (isChecked) this.onSelectSkin(index); })
              } else {
                SymbolGlyph($r('sys.symbol.lock')).fontSize(20).fontColor(['#CCC'])
              }
            }.width('100%').padding(12).backgroundColor('#F9F9F9').borderRadius(12)
          }
        })
      }.width('100%').height(300)
      Button('关闭').width('90%').height(40).margin({ top: 20, bottom: 20 }).backgroundColor('#F0F2F5').fontColor('#333').onClick(() => { this.controller.close() })
    }.width('90%').backgroundColor(Color.White).borderRadius(24)
  }
}