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

    // 初始化闪控球管理器
    LuminaFloatingBallManager.getInstance().init(this.context);

    // 如果本次启动来源于闪控球，标记自动拉起选择器
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

    // 如果是闪控球点击进入：直接加载 CapsuleImportPage；否则仍然 Index（不改变你原有默认行为）
    const auto = CapsuleFlow.consumeAutoPickPending();
    if (auto) {
      windowStage.loadContent('pages/CapsuleImportPage');
    } else {
      windowStage.loadContent('pages/Index');
    }

    // 启动闪控球（放这里：保证 context/window 都就绪）
    LuminaFloatingBallManager.getInstance().start();
  }

  onNewWant(want: Want): void {
    const p = want && want.parameters ? want.parameters : undefined;
    if (p && (p['openCapsuleImport'] === true) && this.stageRef) {
      CapsuleFlow.markAutoPickPending();
      this.stageRef.loadContent('pages/CapsuleImportPage');
    }
  }
}
