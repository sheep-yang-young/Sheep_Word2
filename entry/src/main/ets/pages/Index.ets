import { DatabaseManager } from '../utils/DatabaseManager';
import { WordImporter } from '../utils/WordImporter';
import { DashboardStats } from '../model/WordModel';
import { common } from '@kit.AbilityKit';
import { ReviewPage } from './ReviewPage';
import { VocabularyPage } from './VocabularyPage';
import { SettingsPage } from './SettingsPage';
import { SimpleLineChart, CleanCard } from '../components/CustomComponents';
import { PreferenceManager } from '../utils/PreferenceManager';

@Entry
@Component
struct Index {
  @Provide('pageStack') pageStack: NavPathStack = new NavPathStack();
  @Provide refreshFlag: number = 0;

  async aboutToAppear(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    await PreferenceManager.getInstance().init(context);
    await DatabaseManager.getInstance().init(context);
  }

  @Builder
  PagesMap(name: string) {
    if (name === 'ReviewPage') {
      ReviewPage()
    } else if (name === 'VocabularyPage') {
      VocabularyPage()
    } else if (name === 'SettingsPage') {
      SettingsPage()
    }
  }

  build() {
    Navigation(this.pageStack) {
      HomePage()
    }
    .navDestination(this.PagesMap)
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
  }
}

@Component
struct HomePage {
  @Consume('pageStack') pageStack: NavPathStack;
  @Consume @Watch('onRefreshTriggered') refreshFlag: number;

  @State currentIndex: number = 0;
  @State stats: DashboardStats = new DashboardStats();
  @State chartData: number[] = [0, 0, 0, 0, 0];
  @State selectedBook: string = "默认词库 (Default)";

  // [新增] 热力图数据
  @State heatmapData: Map<string, number> = new Map();
  // 生成最近28天的日期数组
  @State dateList: string[] = [];

  aboutToAppear(): void {
    this.refreshStats();
  }

  onRefreshTriggered(): void {
    this.refreshStats();
  }

  async refreshStats(): Promise<void> {
    const db = DatabaseManager.getInstance();
    this.stats = await db.getDashboardStats();
    this.chartData = await db.getProficiencyDistribution();
    this.heatmapData = await db.getActivityStats();
    this.generateDateList();
  }

  generateDateList(): void {
    const list: string[] = [];
    const today = new Date();
    // 生成过去28天
    for (let i = 27; i >= 0; i--) {
      const d = new Date();
      d.setDate(today.getDate() - i);
      const dateStr = `${d.getFullYear()}-${(d.getMonth()+1).toString().padStart(2, '0')}-${d.getDate().toString().padStart(2, '0')}`;
      list.push(dateStr);
    }
    this.dateList = list;
  }

  // 渲染热力块颜色
  getHeatmapColor(count: number): string {
    if (count === 0) return '#F0F0F0';
    if (count <= 5) return '#BAE0FF'; // 浅蓝
    if (count <= 10) return '#69B1FF';
    if (count <= 20) return '#1890FF';
    return '#0050B3'; // 深蓝
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {

      // --- Tab 1: 主页 ---
      TabContent() {
        Column() {
          // 顶部栏
          Row() {
            Column({ space: 4 }) {
              Text('Current Plan').fontSize(12).fontColor('#999')
              Row() {
                Text(this.selectedBook).fontSize(16).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
                Image($r('sys.media.ohos_ic_public_arrow_down')).width(16).height(16).fillColor('#1A1A1A').margin({ left: 4 })
              }
            }
            Blank()

            // 词汇表
            Button({ type: ButtonType.Circle }) {
              Image($r('sys.media.ohos_ic_public_paste'))
                .width(20).height(20).fillColor('#333')
            }
            .width(36).height(36).backgroundColor('#F0F2F5').margin({ right: 10 })
            .onClick(() => { this.pageStack.pushPath({ name: 'VocabularyPage' }) })

            // 设置
            Button({ type: ButtonType.Circle }) {
              SymbolGlyph($r('sys.symbol.gearshape'))
                .fontSize(22).fontColor(['#333']).fontWeight(FontWeight.Medium)
                .symbolEffect(new AppearSymbolEffect(EffectScope.WHOLE))
            }
            .width(36).height(36).backgroundColor('#F0F2F5')
            .onClick(() => { this.pageStack.pushPath({ name: 'SettingsPage' }) })
          }
          .width('100%').padding({ top: 60, left: 24, right: 24 })

          Scroll() {
            Column({ space: 20 }) {
              // 仪表盘
              Stack({ alignContent: Alignment.Center }) {
                Circle({ width: 220, height: 220 })
                  .strokeWidth(20).fill(Color.Transparent).stroke('#F0F2F5')

                Circle({ width: 220, height: 220 })
                  .strokeWidth(20).fill(Color.Transparent).stroke('#0A59F7')
                  .rotate({ angle: -90 })
                  .strokeDashArray([
                    (this.stats.learnedToday + this.stats.due) > 0
                      ? (this.stats.learnedToday / (this.stats.learnedToday + this.stats.due)) * 692
                      : 0,
                    692
                  ])
                  .animation({ duration: 600, curve: Curve.EaseOut })

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
              .margin({ top: 40 })

              // 数据概览
              Row() {
                this.StatItem(this.stats.total.toString(), 'Total')
                Divider().vertical(true).height(30).color('#EEE')
                this.StatItem(this.stats.mastered.toString(), 'Mastered')
                Divider().vertical(true).height(30).color('#EEE')
                this.StatItem(this.stats.learnedToday.toString(), 'Today')
              }
              .width('90%').justifyContent(FlexAlign.SpaceEvenly)
              .padding(20).backgroundColor(Color.White).borderRadius(16)
              .shadow({ radius: 20, color: 'rgba(0,0,0,0.05)' })
            }
            .width('100%')
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)

          Button(this.stats.due > 0 ? 'Start Review Session' : 'All Done for Today!')
            .width('85%').height(56)
            .backgroundColor(this.stats.due > 0 ? '#0A59F7' : '#52C41A')
            .fontColor(Color.White).fontSize(18).fontWeight(FontWeight.Medium)
            .enabled(this.stats.due > 0)
            .shadow({ radius: 20, color: this.stats.due > 0 ? 'rgba(10, 89, 247, 0.3)' : 'rgba(82, 196, 26, 0.3)', offsetY: 10 })
            .onClick(() => {
              this.pageStack.pushPath({ name: 'ReviewPage' });
            })
            .margin({ bottom: 30, top: 10 })
        }
        .width('100%').height('100%').backgroundColor('#F5F7FA')
      }
      .tabBar(this.TabBuilder('Review', 0, $r('sys.media.ohos_ic_public_clock')))

      // --- Tab 2: 分析 ---
      TabContent() {
        Column() {
          Text('Learning Analytics')
            .fontSize(28).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
            .width('100%').padding({ top: 60, left: 24, bottom: 20 })

          Scroll() {
            Column({ space: 20 }) {
              // [新增] 学习热力图区域
              Column() {
                Text('Study Consistency (Last 28 Days)')
                  .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333')
                  .width('100%').margin({ bottom: 15 })

                // 7列 x 4行 的网格
                Grid() {
                  ForEach(this.dateList, (date: string) => {
                    GridItem() {
                      // 颜色方块
                      Rect()
                        .width('100%').height(24) // 宽高自适应
                        .radius(4)
                        .fill(this.getHeatmapColor(this.heatmapData.get(date) || 0))
                    }
                  })
                }
                .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr') // 7列
                .rowsGap(6).columnsGap(6)
                .height(130) // 4行大概的高度
              }
              .width('90%')
              .padding(20)
              .backgroundColor(Color.White)
              .borderRadius(16)
              .shadow({ radius: 10, color: 'rgba(0,0,0,0.05)' })

              // 熟练度分布
              Column() {
                Text('Proficiency Distribution')
                  .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333')
                  .width('100%').margin({ bottom: 20 })

                SimpleLineChart({ data: this.chartData })
              }
              .width('90%')
              .padding(20)
              .backgroundColor(Color.White)
              .borderRadius(16)
              .shadow({ radius: 10, color: 'rgba(0,0,0,0.05)' })
            }
            .width('100%')
          }
          .layoutWeight(1)
        }
        .width('100%').height('100%').backgroundColor('#F5F7FA')
      }
      .tabBar(this.TabBuilder('Analysis', 1, $r('sys.media.ohos_ic_public_paste')))
    }
    .scrollable(false)
    .barHeight(60)
    .onChange((index) => {
      this.currentIndex = index;
      this.refreshStats();
    })
  }

  @Builder TabBuilder(title: string, targetIndex: number, icon: Resource) {
    Column() {
      Image(icon).width(24).height(24).fillColor(this.currentIndex === targetIndex ? '#0A59F7' : '#999').objectFit(ImageFit.Contain)
      Text(title).fontSize(10).fontColor(this.currentIndex === targetIndex ? '#0A59F7' : '#999').margin({ top: 4 })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center)
  }

  @Builder StatItem(val: string, label: string) {
    Column() {
      Text(val).fontSize(20).fontWeight(FontWeight.Bold).fontColor('#333')
      Text(label).fontSize(12).fontColor('#999').margin({ top: 4 })
    }
  }
}