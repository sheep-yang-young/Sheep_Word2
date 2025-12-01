import { DatabaseManager } from '../utils/DatabaseManager';
import { WordImporter } from '../utils/WordImporter';
import { DashboardStats } from '../model/WordModel';
import { common } from '@kit.AbilityKit';
import { ReviewPage } from './ReviewPage';
import { SimpleLineChart } from '../components/CustomComponents';

@Entry
@Component
struct Index {
  @Provide('pageStack') pageStack: NavPathStack = new NavPathStack();

  @Provide refreshFlag: number = 0;

  async aboutToAppear(): Promise<void> {
    await DatabaseManager.getInstance().init(getContext(this) as common.UIAbilityContext);
  }

  @Builder
  PagesMap(name: string) {
    if (name === 'ReviewPage') {
      ReviewPage()
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
  }

  async handleImport(): Promise<void> {
    const count = await WordImporter.selectAndImportFile(getContext(this) as common.UIAbilityContext);
    if (count > 0) {
      this.refreshStats();
    }
  }

  async handleClean(): Promise<void> {
    await DatabaseManager.getInstance().cleanAllData();
    this.refreshStats();
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {

      // --- Tab 1: 仪表盘 ---
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

            Button({ type: ButtonType.Circle }) {
              Image($r('sys.media.ohos_ic_public_remove')).width(20).height(20).fillColor('#FF4D4F')
            }
            .width(36).height(36).backgroundColor('#FFF0F0')
            .onClick(() => { this.handleClean() })

            Button({ type: ButtonType.Circle }) {
              Image($r('sys.media.ohos_ic_public_add')).width(24).height(24).fillColor(Color.White)
            }
            .width(40).height(40).backgroundColor('#0A59F7').margin({ left: 12 })
            .onClick(() => { this.handleImport() })
          }
          .width('100%').padding({ top: 60, left: 24, right: 24 })

          // 可滚动区域
          Scroll() {
            Column({ space: 20 }) {
              // --- 核心仪表盘 (今日进度) ---
              Stack({ alignContent: Alignment.Center }) {
                // 底环
                Circle({ width: 220, height: 220 })
                  .strokeWidth(20).fill(Color.Transparent).stroke('#F0F2F5')

                // 进度环 (计算今日完成度)
                // 计算公式：已学 / (已学 + 待办)
                Circle({ width: 220, height: 220 })
                  .strokeWidth(20).fill(Color.Transparent).stroke('#0A59F7')
                  .rotate({ angle: -90 })
                  .strokeDashArray([
                    (this.stats.learnedToday + this.stats.due) > 0
                      ? (this.stats.learnedToday / (this.stats.learnedToday + this.stats.due)) * 600
                      : 0,
                    1000
                  ])
                  .animation({ duration: 500, curve: Curve.EaseOut }) // 增加动画

                Column() {
                  // 显示今日剩余
                  Text(this.stats.due.toString()).fontSize(64).fontWeight(FontWeight.Bolder).fontColor('#1A1A1A')
                  Text('Due Today').fontSize(14).fontColor('#999').margin({ top: 5 })

                  // 显示今日已完成小字
                  Text(`Done: ${this.stats.learnedToday}`)
                    .fontSize(14).fontColor('#0A59F7').fontWeight(FontWeight.Medium)
                    .backgroundColor('rgba(10, 89, 247, 0.1)')
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .borderRadius(10)
                    .margin({ top: 10 })
                }
              }
              .margin({ top: 40 })

              // 数据概览条
              Row() {
                this.StatItem(this.stats.total.toString(), 'Total')
                Divider().vertical(true).height(30).color('#EEE')
                this.StatItem(this.stats.mastered.toString(), 'Mastered')
                Divider().vertical(true).height(30).color('#EEE')
                this.StatItem(this.stats.learnedToday.toString(), 'Today') // 改为显示今日总量
              }
              .width('90%').justifyContent(FlexAlign.SpaceEvenly)
              .padding(20).backgroundColor(Color.White).borderRadius(16)
              .shadow({ radius: 20, color: 'rgba(0,0,0,0.05)' })
            }
            .width('100%')
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)

          // 开始按钮
          Button(this.stats.due > 0 ? 'Start Review Session' : 'All Done for Today!')
            .width('85%').height(56)
            .backgroundColor(this.stats.due > 0 ? '#0A59F7' : '#52C41A') // 完成变绿
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

      // --- Tab 2: 统计分析 ---
      TabContent() {
        Column() {
          Text('Learning Analytics')
            .fontSize(28).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
            .width('100%').padding({ top: 60, left: 24, bottom: 20 })

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