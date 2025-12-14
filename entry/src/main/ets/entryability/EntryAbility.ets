import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { DatabaseManager } from '../utils/DatabaseManager';
import { PreferenceManager } from '../utils/PreferenceManager';

export default class EntryAbility extends UIAbility {
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    // 保持原有的初始化逻辑
    await PreferenceManager.getInstance().init(this.context);
    await DatabaseManager.getInstance().init(this.context);

    // [核心修改] 将 COLOR_MODE_NOT_SET 改为 COLOR_MODE_LIGHT，强制锁定亮色模式
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    } catch (err) {}
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 保持原有的沉浸式状态栏设置
    windowStage.getMainWindow().then((win) => {
      try {
        win.setWindowLayoutFullScreen(true);
        win.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          navigationBarColor: '#00000000',
          statusBarContentColor: '#000000',
          navigationBarContentColor: '#000000'
        });
      } catch (err) {}
    });
    windowStage.loadContent('pages/Index');
  }
}