import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import hilog from '@ohos.hilog';
import { window } from '@kit.ArkUI';
import { DatabaseManager } from '../utils/DatabaseManager';
import { PreferenceManager } from '../utils/PreferenceManager';
import { LuminaFloatingBallManager } from '../utils/LuminaFloatingBallManager';
import { CapsuleFlow } from '../utils/CapsuleFlow';
import { LuminaLog } from '../utils/LuminaLog';
import { ScreenshotFlow } from '../utils/ScreenshotFlow';
import { ScreenshotManager } from '../utils/ScreenshotManager';

export default class EntryAbility extends UIAbility {
  private stageRef: window.WindowStage | null = null;
  private readonly domain: number = 0xA0A03D;
  private readonly tag: string = 'EntryAbility';

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    LuminaLog.i(`EntryAbility.onCreate want=${JSON.stringify(want)} parameters=${JSON.stringify(want?.parameters)}`);
    await PreferenceManager.getInstance().init(this.context);
    await DatabaseManager.getInstance().init(this.context);
    ScreenshotManager.getInstance().init(this.context);

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    } catch (err) {}

    LuminaFloatingBallManager.getInstance().init(this.context);

    hilog.info(this.domain, this.tag, 'onCreate want=%{public}s', JSON.stringify(want));

    const p = want && want.parameters ? want.parameters : undefined;
    if (p && (p['openCapsuleImport'] === true)) {
      LuminaLog.i('EntryAbility.onCreate detected openCapsuleImport');
      CapsuleFlow.markAutoPickPending();
    }

    if (p && (p['openScreenshotGallery'] === true)) {
      const path = typeof p['screenshotPath'] === 'string' ? p['screenshotPath'] as string : '';
      ScreenshotFlow.markPendingOpen(path, true);
      AppStorage.setOrCreate('NavigateToScreenshotBox', true);
      if (path) AppStorage.setOrCreate('LatestScreenshotPath', path);
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
      LuminaLog.i('EntryAbility.onWindowStageCreate triggering NavigateToCapsuleImport');
      AppStorage.setOrCreate('NavigateToCapsuleImport', true);
    }
    if (ScreenshotFlow.consumePendingOpen()) {
      AppStorage.setOrCreate('NavigateToScreenshotBox', true);
    }
    windowStage.loadContent('pages/Index');

    // 恢复悬浮球状态
    PreferenceManager.getInstance().isFloatingBallEnabled().then(enabled => {
      if(enabled) LuminaFloatingBallManager.getInstance().start();
    });
  }

  onNewWant(want: Want): void {
    LuminaLog.i(`EntryAbility.onNewWant want=${JSON.stringify(want)} parameters=${JSON.stringify(want?.parameters)}`);
    const p = want && want.parameters ? want.parameters : undefined;
    if (p && (p['openCapsuleImport'] === true)) {
      LuminaLog.i('EntryAbility.onNewWant detected openCapsuleImport');
      CapsuleFlow.markAutoPickPending();
      // 触发 UI 跳转
      LuminaLog.i('EntryAbility.onNewWant triggering NavigateToCapsuleImport');
      AppStorage.setOrCreate('NavigateToCapsuleImport', true);
    }

    if (p && (p['openScreenshotGallery'] === true)) {
      const path = typeof p['screenshotPath'] === 'string' ? p['screenshotPath'] as string : '';
      ScreenshotFlow.markPendingOpen(path, true);
      LuminaLog.i('EntryAbility.onNewWant triggering NavigateToScreenshotBox');
      AppStorage.setOrCreate('NavigateToScreenshotBox', true);
      if (path) AppStorage.setOrCreate('LatestScreenshotPath', path);
    }
  }
}