import { PreferenceManager } from '../utils/PreferenceManager';
import { DatabaseManager } from '../utils/DatabaseManager';
import { WordImporter } from '../utils/WordImporter';
import { WordExporter } from '../utils/WordExporter';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';

@Component
export struct SettingsPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @Consume refreshFlag: number;

  @State dailyLimit: number = 20;
  @State accentType: number = 2; // 1=UK, 2=US
  @State isHapticOn: boolean = true;

  async aboutToAppear(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    await PreferenceManager.getInstance().init(context);

    // 加载配置
    this.dailyLimit = await PreferenceManager.getInstance().getDailyLimit();
    this.accentType = await PreferenceManager.getInstance().getAccentType();
    this.isHapticOn = await PreferenceManager.getInstance().isHapticEnabled();
  }

  async saveLimit(value: number): Promise<void> {
    this.dailyLimit = value;
    await PreferenceManager.getInstance().setDailyLimit(value);
  }

  async saveAccent(value: number): Promise<void> {
    this.accentType = value;
    await PreferenceManager.getInstance().setAccentType(value);
  }

  async saveHaptic(value: boolean): Promise<void> {
    this.isHapticOn = value;
    await PreferenceManager.getInstance().setHapticEnabled(value);
  }

  async handleImport(): Promise<void> {
    const count = await WordImporter.selectAndImportFile(getContext(this) as common.UIAbilityContext);
    if (count > 0) {
      this.refreshFlag++;
      try { promptAction.showToast({ message: `Imported ${count} words` }); } catch(e){}
    }
  }

  async handleExport(): Promise<void> {
    const success = await WordExporter.exportData(getContext(this) as common.UIAbilityContext);
    if (success) {
      try { promptAction.showToast({ message: 'Backup saved successfully' }); } catch(e){}
    } else {
      try { promptAction.showToast({ message: 'Export failed or no data' }); } catch(e){}
    }
  }

  async handleClean(): Promise<void> {
    promptAction.showDialog({
      title: 'Clear All Data?',
      message: 'This will DELETE ALL words. Cannot be undone.',
      buttons: [
        { text: 'Cancel', color: '#666' },
        { text: 'Delete All', color: '#FF4D4F' }
      ]
    }).then(async (res) => {
      if (res.index === 1) {
        await DatabaseManager.getInstance().cleanAllData();
        this.refreshFlag++;
        try { promptAction.showToast({ message: 'All data cleared' }); } catch(e){}
      }
    });
  }

  async handleResetProgress(): Promise<void> {
    promptAction.showDialog({
      title: 'Reset Progress?',
      message: 'Keep words, but reset memory state to 0.',
      buttons: [
        { text: 'Cancel', color: '#666' },
        { text: 'Reset', color: '#FAAD14' }
      ]
    }).then(async (res) => {
      if (res.index === 1) {
        await DatabaseManager.getInstance().resetLearningProgress();
        this.refreshFlag++;
        try { promptAction.showToast({ message: 'Learning progress reset' }); } catch(e){}
      }
    });
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Image($r('sys.media.ohos_ic_public_arrow_left'))
            .width(24).height(24).fillColor('#1A1A1A')
            .onClick(() => { this.pageStack.pop() })
          Blank()
          Text('Settings').fontSize(18).fontWeight(FontWeight.Bold)
          Blank().width(24)
        }
        .width('100%').padding(20)

        List({ space: 16 }) {

          // --- 1. 学习偏好 ---
          ListItem() {
            Column({ space: 16 }) {
              Text('Learning Preferences').fontSize(14).fontColor('#666').width('100%')

              // 每日目标
              Column({ space: 10 }) {
                Row() {
                  Text('Daily Goal').fontSize(16).fontWeight(FontWeight.Medium)
                  Blank()
                  Text(`${this.dailyLimit}`).fontSize(16).fontColor('#0A59F7').fontWeight(FontWeight.Bold)
                }
                .width('100%')

                Slider({ value: this.dailyLimit, min: 5, max: 100, step: 5 })
                  .onChange((value, mode) => {
                    this.dailyLimit = value;
                    if (mode === SliderChangeMode.End) this.saveLimit(value);
                  })
              }

              Divider().color('#F0F0F0')

              // 口音选择
              Row() {
                Text('Accent (TTS)').fontSize(16).fontWeight(FontWeight.Medium)
                Blank()
                Row({ space: 10 }) {
                  Button('US')
                    .height(32).fontSize(12)
                    .backgroundColor(this.accentType === 2 ? '#0A59F7' : '#F0F2F5')
                    .fontColor(this.accentType === 2 ? Color.White : '#666')
                    .onClick(() => { this.saveAccent(2) })

                  Button('UK')
                    .height(32).fontSize(12)
                    .backgroundColor(this.accentType === 1 ? '#0A59F7' : '#F0F2F5')
                    .fontColor(this.accentType === 1 ? Color.White : '#666')
                    .onClick(() => { this.saveAccent(1) })
                }
              }
              .width('100%')

              Divider().color('#F0F0F0')

              // 振动开关
              Row() {
                Text('Haptic Feedback').fontSize(16).fontWeight(FontWeight.Medium)
                Blank()
                Toggle({ type: ToggleType.Switch, isOn: this.isHapticOn })
                  .selectedColor('#0A59F7')
                  .onChange((isOn) => { this.saveHaptic(isOn) })
              }
              .width('100%')
            }
            .padding(16).backgroundColor(Color.White).borderRadius(16)
          }

          // --- 2. 数据管理 ---
          ListItem() {
            Column() {
              Text('Data Management').fontSize(14).fontColor('#666').width('100%').margin({ bottom: 8 })

              // 导入
              this.SettingsItem('Import JSON', $r('sys.media.ohos_ic_public_add'), () => { this.handleImport() })

              // 导出
              this.SettingsItem('Export Backup', $r('sys.media.ohos_ic_public_share'), () => { this.handleExport() })

              // [修复] 重置进度 - 图标换为 Clock
              this.SettingsItem('Reset Progress', $r('sys.media.ohos_ic_public_clock'), () => { this.handleResetProgress() }, '#FAAD14')

              // 清空所有
              this.SettingsItem('Delete All Data', $r('sys.media.ohos_ic_public_remove'), () => { this.handleClean() }, '#FF4D4F')
            }
          }

          // --- 3. 关于 ---
          ListItem() {
            Column() {
              Text('About').fontSize(14).fontColor('#666').width('100%').margin({ bottom: 8 })
              Row() {
                Column() {
                  Text('Lumina').fontSize(16).fontWeight(FontWeight.Bold)
                  Text('Version 2.1.0').fontSize(12).fontColor('#999').margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                Blank()
              }
              .width('100%').padding(16).backgroundColor(Color.White).borderRadius(16)
            }
          }
        }
        .layoutWeight(1)
        .padding({ left: 20, right: 20 })
      }
      .width('100%').height('100%').backgroundColor('#F5F7FA').padding({ top: 36 })
    }
    .hideTitleBar(true)
  }

  @Builder SettingsItem(title: string, icon: Resource, action: () => void, color: string = '#333') {
    Row() {
      Image(icon).width(20).height(20).fillColor(color)
      Text(title).fontSize(16).fontColor(color).margin({ left: 12 })
      Blank()
      Image($r('sys.media.ohos_ic_public_arrow_right')).width(16).height(16).fillColor('#CCC')
    }
    .width('100%').padding(16).backgroundColor(Color.White).borderRadius(16)
    .onClick(action)
    .margin({ bottom: 12 })
  }
}