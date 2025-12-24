import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { DatabaseManager } from '../utils/DatabaseManager';
import { PreferenceManager } from '../utils/PreferenceManager';
import { LuminaFloatingBallManager } from '../utils/LuminaFloatingBallManager';
import { CapsuleFlow } from '../utils/CapsuleFlow';

export default class EntryAbility extends UIAbility {
  private stageRef: window.WindowStage | null = null;

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    await PreferenceManager.getInstance().init(this.context);
    await DatabaseManager.getInstance().init(this.context);

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    } catch (err) {}

    LuminaFloatingBallManager.getInstance().init(this.context);

    const p = want && want.parameters ? want.parameters : undefined;
    if (p && (p['openCapsuleImport'] === true)) {
      CapsuleFlow.markAutoPickPending();
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.stageRef = windowStage;

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

    // 处理闪控球自动跳转
    const auto = CapsuleFlow.consumeAutoPickPending();
    if (auto) {
      // 触发全局跳转
      AppStorage.setOrCreate('NavigateToCapsuleImport', true);
    }
    windowStage.loadContent('pages/Index');

    // 恢复悬浮球状态
    PreferenceManager.getInstance().isFloatingBallEnabled().then(enabled => {
      if(enabled) LuminaFloatingBallManager.getInstance().start();
    });
  }

  onNewWant(want: Want): void {
    const p = want && want.parameters ? want.parameters : undefined;
    if (p && (p['openCapsuleImport'] === true)) {
      CapsuleFlow.markAutoPickPending();
      // 触发 UI 跳转
      AppStorage.setOrCreate('NavigateToCapsuleImport', true);
    }
  }
}