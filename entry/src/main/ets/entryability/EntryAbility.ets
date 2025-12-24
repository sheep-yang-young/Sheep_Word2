import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { DatabaseManager } from '../utils/DatabaseManager';
import { PreferenceManager } from '../utils/PreferenceManager';

// ✅ 新增
import { FloatingBallManager } from '../utils/FloatingBallManager';
import { LuminaLog } from '../utils/LuminaLog';

export default class EntryAbility extends UIAbility {
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    // 保持原有的初始化逻辑
    await PreferenceManager.getInstance().init(this.context);
    await DatabaseManager.getInstance().init(this.context);

    // [核心修改] 将 COLOR_MODE_NOT_SET 改为 COLOR_MODE_LIGHT，强制锁定亮色模式
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    } catch (err) {}

    // ✅ 新增：把 context 交给闪控球管理器 + 打日志
    try {
      FloatingBallManager.getInstance().init(this.context);
      LuminaLog.i('EntryAbility onCreate: init FloatingBallManager OK');
    } catch (err) {
      LuminaLog.e(`EntryAbility onCreate: init FloatingBallManager FAILED: ${LuminaLog.err(err as Object)}`);
    }
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

    // 保持原有首页加载
    windowStage.loadContent('pages/Index');

    // ✅ 新增：启动闪控球（不影响你现有页面/沉浸式逻辑）
    FloatingBallManager.getInstance().start().catch((err) => {
      LuminaLog.e(`FloatingBall start() FAILED: ${LuminaLog.err(err as Object)}`);
    });
  }

  onDestroy(): void {
    // ✅ 新增：退出时停止闪控球
    FloatingBallManager.getInstance().stop().catch((err) => {
      LuminaLog.e(`FloatingBall stop() FAILED: ${LuminaLog.err(err as Object)}`);
    });
  }
}
