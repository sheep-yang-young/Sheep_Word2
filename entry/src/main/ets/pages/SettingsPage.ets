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
  @State accentType: number = 2;
  @State isHapticOn: boolean = true;
  @State reviewMode: number = 0;
  @State ttsSpeed: number = 1.0;

  private currentBook: string = "Default Library";

  async aboutToAppear(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    await PreferenceManager.getInstance().init(context);

    this.dailyLimit = await PreferenceManager.getInstance().getDailyLimit();
    this.accentType = await PreferenceManager.getInstance().getAccentType();
    this.isHapticOn = await PreferenceManager.getInstance().isHapticEnabled();
    this.reviewMode = await PreferenceManager.getInstance().getReviewMode();
    this.ttsSpeed = await PreferenceManager.getInstance().getTtsSpeed();
    this.currentBook = await PreferenceManager.getInstance().getCurrentBook();
  }

  async saveLimit(value: number): Promise<void> { this.dailyLimit = value; await PreferenceManager.getInstance().setDailyLimit(value); }
  async saveAccent(value: number): Promise<void> { this.accentType = value; await PreferenceManager.getInstance().setAccentType(value); }
  async saveHaptic(value: boolean): Promise<void> { this.isHapticOn = value; await PreferenceManager.getInstance().setHapticEnabled(value); }
  async saveReviewMode(value: number): Promise<void> { this.reviewMode = value; await PreferenceManager.getInstance().setReviewMode(value); }
  async saveTtsSpeed(value: number): Promise<void> { this.ttsSpeed = value; await PreferenceManager.getInstance().setTtsSpeed(value); }

  // [已删除] handleLoadBuiltIn 方法已移除

  async handleImportJson(): Promise<void> {
    const count = await WordImporter.selectAndImportFile(getContext(this) as common.UIAbilityContext, this.currentBook);
    if (count > 0) {
      this.refreshFlag++;
      try { promptAction.showToast({ message: `成功导入 ${count} 个单词` }); } catch(e){}
    }
  }

  async handleImportTxt(): Promise<void> {
    const count = await WordImporter.selectAndImportTxtFile(getContext(this) as common.UIAbilityContext, this.currentBook);
    if (count > 0) {
      this.refreshFlag++;
      try { promptAction.showToast({ message: `成功导入 ${count} 个单词` }); } catch(e){}
    }
  }

  async handleExport(): Promise<void> {
    const success = await WordExporter.exportData(getContext(this) as common.UIAbilityContext, this.currentBook);
    if (success) {
      try { promptAction.showToast({ message: '备份已保存' }); } catch(e){}
    }
  }

  async handleClean(): Promise<void> {
    promptAction.showDialog({ title: '清空数据?', message: '不可撤销。', buttons: [{ text: '取消', color: '#666' }, { text: '清空', color: '#FF4D4F' }] }).then(async (res) => { if (res.index === 1) { await DatabaseManager.getInstance().cleanAllData(); this.refreshFlag++; } });
  }

  async handleResetProgress(): Promise<void> {
    promptAction.showDialog({ title: '重置进度?', message: '保留单词，重置记忆。', buttons: [{ text: '取消', color: '#666' }, { text: '重置', color: '#FAAD14' }] }).then(async (res) => { if (res.index === 1) { await DatabaseManager.getInstance().resetLearningProgress(this.currentBook); this.refreshFlag++; } });
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Image($r('sys.media.ohos_ic_public_arrow_left')).width(24).height(24).fillColor('#1A1A1A').onClick(() => { this.pageStack.pop() })
          Blank()
          Text('设置').fontSize(18).fontWeight(FontWeight.Bold)
          Blank().width(24)
        }
        .width('100%').padding(20)

        List({ space: 16 }) {
          ListItem() {
            Column({ space: 16 }) {
              Text('学习偏好').fontSize(14).fontColor('#666').width('100%')
              Column({ space: 10 }) {
                Row() { Text('每日目标').fontSize(16).fontWeight(FontWeight.Medium); Blank(); Text(`${this.dailyLimit} 词`).fontSize(16).fontColor('#0A59F7').fontWeight(FontWeight.Bold) }.width('100%')
                Slider({ value: this.dailyLimit, min: 5, max: 100, step: 5 }).onChange((value, mode) => { this.dailyLimit = value; if (mode === SliderChangeMode.End) this.saveLimit(value); })
              }
              Divider().color('#F0F0F0')
              Row() {
                Text('发音口音').fontSize(16).fontWeight(FontWeight.Medium); Blank()
                Row({ space: 10 }) {
                  Button('美音').height(32).fontSize(12).backgroundColor(this.accentType === 2 ? '#0A59F7' : '#F0F2F5').fontColor(this.accentType === 2 ? Color.White : '#666').onClick(() => { this.saveAccent(2) })
                  Button('英音').height(32).fontSize(12).backgroundColor(this.accentType === 1 ? '#0A59F7' : '#F0F2F5').fontColor(this.accentType === 1 ? Color.White : '#666').onClick(() => { this.saveAccent(1) })
                }
              }.width('100%')
              Divider().color('#F0F0F0')
              Column({ space: 10 }) {
                Row() { Text('朗读语速').fontSize(16).fontWeight(FontWeight.Medium); Blank(); Text(`${this.ttsSpeed}x`).fontSize(16).fontColor('#0A59F7').fontWeight(FontWeight.Bold) }.width('100%')
                Slider({ value: this.ttsSpeed, min: 0.5, max: 2.0, step: 0.25 }).onChange((value, mode) => { this.ttsSpeed = value; if (mode === SliderChangeMode.End) this.saveTtsSpeed(value); })
              }
              Divider().color('#F0F0F0')
              Row() { Text('振动反馈').fontSize(16).fontWeight(FontWeight.Medium); Blank(); Toggle({ type: ToggleType.Switch, isOn: this.isHapticOn }).selectedColor('#0A59F7').onChange((isOn) => { this.saveHaptic(isOn) }) }.width('100%')
            }
            .padding(16).backgroundColor(Color.White).borderRadius(16)
          }

          ListItem() {
            Column() {
              Text('数据管理').fontSize(14).fontColor('#666').width('100%').margin({ bottom: 8 })

              // [修改] 已移除加载内置词库
              this.SettingsItem('导入 JSON 文件', $r('sys.media.ohos_ic_public_add'), () => { this.handleImportJson() })
              this.SettingsItem('导入 TXT 文件', $r('sys.media.ohos_ic_public_paste'), () => { this.handleImportTxt() })
              this.SettingsItem('导出数据备份', $r('sys.media.ohos_ic_public_share'), () => { this.handleExport() })
              this.SettingsItem('重置当前进度', $r('sys.media.ohos_ic_public_clock'), () => { this.handleResetProgress() }, '#FAAD14')
              this.SettingsItem('清空所有数据', $r('sys.media.ohos_ic_public_remove'), () => { this.handleClean() }, '#FF4D4F')
            }
          }

          ListItem() {
            Column() {
              Text('关于').fontSize(14).fontColor('#666').width('100%').margin({ bottom: 8 })
              this.SettingsItem('关于应用', $r('sys.media.ohos_ic_public_more'), () => {
                this.pageStack.pushPath({ name: 'AboutPage' })
              })
            }
          }
        }
        .layoutWeight(1).padding({ left: 20, right: 20 })
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
    .width('100%').padding(16).backgroundColor(Color.White).borderRadius(16).onClick(action).margin({ bottom: 12 })
  }
}