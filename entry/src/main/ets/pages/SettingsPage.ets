import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI'; // 引入提示框
import { PreferenceManager } from '../utils/PreferenceManager';
import { FloatingCapsuleManager } from '../utils/FloatingCapsuleManager';

@Component
export struct SettingsPage {
  @Link dailyLimit: number;
  @State hapticEnabled: boolean = true;
  @State currentBook: string = "Default Library";

  async aboutToAppear() {
    const pm = PreferenceManager.getInstance();
    // this.dailyLimit = await pm.getDailyLimit(); // [删除] 依赖 @Link
    this.hapticEnabled = await pm.isHapticEnabled();
    this.currentBook = await pm.getCurrentBook();
  }

  build() {
    Column() {
      // [新增] 手动模拟 DragHandle (消除白条问题的关键)
      Row() {
        Row()
          .width(40)
          .height(4)
          .backgroundColor('#D1D1D6') // iOS/鸿蒙风格的灰色条
          .borderRadius(2)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 12 })

      // === 标题栏 ===
      Row() {
        Text('设置')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
      }
      .width('100%')
      .padding({ top: 20, bottom: 10, left: 24, right: 24 })
      .justifyContent(FlexAlign.Start)

      // === 设置列表 ===
      List({ space: 16 }) {

        // --- 第一组：学习计划 ---
        ListItem() {
          Column({ space: 0 }) {
            // 每日新词量
            Row() {
              Column({ space: 4 }) {
                Text('每日新词量')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#333')
                Text('每天想要学习的新单词数量')
                  .fontSize(12)
                  .fontColor('#999')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Row() {
                SymbolGlyph($r('sys.symbol.minus_circle'))
                  .fontSize(24)
                  .fontColor(this.dailyLimit > 5 ? ['#0A59F7'] : ['#CCC'])
                  .onClick(async () => {
                    if (this.dailyLimit > 5) {
                      this.dailyLimit--;
                      await PreferenceManager.getInstance().setDailyLimit(this.dailyLimit);
                    }
                  })

                Text(this.dailyLimit.toString())
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .margin({ left: 12, right: 12 })
                  .width(36)
                  .textAlign(TextAlign.Center)

                SymbolGlyph($r('sys.symbol.plus_circle'))
                  .fontSize(24)
                  .fontColor(['#0A59F7'])
                  .onClick(async () => {
                    this.dailyLimit++;
                    await PreferenceManager.getInstance().setDailyLimit(this.dailyLimit);
                  })
              }
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })
          }
          .padding({ left: 16, right: 16 })
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
        }

        // --- 第二组：辅助工具 ---
        ListItem() {
          Column() {
            Row() {
              Column({ space: 4 }) {
                Row({ space: 6 }) {
                  Text('悬浮取词胶囊')
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#333')
                  Text('BETA')
                    .fontSize(10)
                    .fontColor('#FFF')
                    .backgroundColor('#FA8C16')
                    .padding({ left: 4, right: 4, top: 2, bottom: 2 })
                    .borderRadius(4)
                }
                Text('在桌面显示悬浮球，支持截图导入查词')
                  .fontSize(12)
                  .fontColor('#999')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Button('开启')
                .fontSize(14)
                .height(30)
                .backgroundColor('#0A59F7')
                .onClick(async () => {
                  try {
                    const context = getContext(this) as common.UIAbilityContext;
                    await FloatingCapsuleManager.getInstance().showCapsule(context);
                  } catch (e) {
                    promptAction.showToast({ message: '开启失败，请检查悬浮窗权限' });
                  }
                })
            }
            .width('100%')
            .padding(16)
          }
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
        }

        // --- 第三组：通用 ---
        ListItem() {
          Column() {
            // 触感反馈
            Row() {
              Text('触感反馈')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#333')
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.hapticEnabled })
                .selectedColor('#0A59F7')
                .onChange(async (isOn: boolean) => {
                  this.hapticEnabled = isOn;
                  await PreferenceManager.getInstance().setHapticEnabled(isOn);
                })
            }
            .width('100%')
            .padding(16)

            Divider().color('#F5F5F5').padding({ left: 16, right: 16 })

            // 当前词书
            Row() {
              Text('当前词书')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#333')
              Blank()
              Text(this.currentBook)
                .fontSize(14)
                .fontColor('#999')
            }
            .width('100%')
            .padding(16)
          }
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
        }

        // --- 第四组：关于 ---
        ListItem() {
          Row() {
            Text('关于 Lumina')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333')
            Blank()
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(20)
              .fontColor(['#CCCCCC'])
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .onClick(() => {
            // 路由跳转
            router.pushUrl({ url: 'pages/AboutPage' });
          })
        }

        // 底部垫高，防止被圆角遮挡
        ListItem().height(40)

      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 16, right: 16 })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7FA') // 确保背景色统一
  }
}