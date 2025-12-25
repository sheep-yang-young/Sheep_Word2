import hilog from '@ohos.hilog';
import { common, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import floatingBall from '@ohos.window.floatingBall';
import { CapsuleFlow } from './CapsuleFlow';
import { ScreenshotManager } from './ScreenshotManager';
import { ScreenshotFlow } from './ScreenshotFlow';

const DOMAIN: number = 0xA0A03D;
const TAG: string = 'LuminaBall';

export class LuminaFloatingBallManager {
  private static inst: LuminaFloatingBallManager = new LuminaFloatingBallManager();

  private ctx: common.UIAbilityContext | null = null;
  private controller: floatingBall.FloatingBallController | null = null;
  private started: boolean = false;

  static getInstance(): LuminaFloatingBallManager {
    return LuminaFloatingBallManager.inst;
  }

  init(context: common.UIAbilityContext): void {
    this.ctx = context;
  }

  /**
   * 启动悬浮球
   */
  async start(): Promise<void> {
    if (!this.ctx) {
      hilog.warn(DOMAIN, TAG, 'Floating ball start skipped: context not initialized');
      return;
    }
    if (this.started) {
      hilog.info(DOMAIN, TAG, 'Already started');
      return;
    }

    try {
      hilog.info(DOMAIN, TAG, 'Attempting to create floating ball...');

      this.controller = await floatingBall.create({ context: this.ctx });

      if (!this.controller) {
        hilog.error(DOMAIN, TAG, 'Controller creation failed (null)');
        return;
      }

      hilog.info(DOMAIN, TAG, 'FloatingBallController created');

      // 设置点击监听
      this.controller.on('click', () => {
        hilog.info(DOMAIN, TAG, 'onClick event received from floating ball');
        this.onBallClick();
      });

      // 设置状态监听
      this.controller.on('stateChange', (st: floatingBall.FloatingBallState) => {
        hilog.info(DOMAIN, TAG, 'stateChange=%{public}s', JSON.stringify(st));
      });

      // 设置属性
      const params: floatingBall.FloatingBallParams = {
        template: floatingBall.FloatingBallTemplate.NORMAL,
        title: 'Lumina',
        content: '选截图识别'
      };

      await this.controller.startFloatingBall(params);
      this.started = true;
      hilog.info(DOMAIN, TAG, 'startFloatingBall OK with params=%{public}s', JSON.stringify(params));
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'startFloatingBall FAILED: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 停止悬浮球
   */
  async stop(): Promise<void> {
    try {
      if (this.controller) {
        await this.controller.stopFloatingBall();
        this.controller.off('click');
        this.controller.off('stateChange');
        // 销毁引用
        this.controller = null;
      }
      this.started = false;
      hilog.info(DOMAIN, TAG, 'stopFloatingBall OK');
    } catch (err) {
      const error = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'stopFloatingBall err=%{public}s', JSON.stringify(error));
    } finally {
      this.started = false;
    }
  }

  private async onBallClick(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onBallClick invoked');

    if (!this.ctx) {
      hilog.error(DOMAIN, TAG, 'onBallClick aborted: context missing');
      return;
    }

    // 自动截图并标记导入流程
    let latestPath: string | null = null;
    let captured = false;
    try {
      const shot = await ScreenshotManager.getInstance().captureAndStore();
      if (shot) {
        latestPath = shot.path;
        ScreenshotFlow.markPendingOpen(latestPath, true);
        captured = true;
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'capture screenshot failed %{public}s', JSON.stringify(e));
    }

    // 标记：进入页面后自动拉起选择截图（兼容旧流程）
    if (!captured) {
      CapsuleFlow.markAutoPickPending();
    }

    const abilityInfo = this.ctx.abilityInfo;
    if (!abilityInfo || !abilityInfo.bundleName || !abilityInfo.name) {
      hilog.error(DOMAIN, TAG, 'onBallClick aborted: invalid abilityInfo=%{public}s', JSON.stringify(abilityInfo));
      return;
    }

    const fallbackBundleName = 'com.Sheep.Lumina';
    const fallbackModuleName = 'entry';
    const fallbackAbilityName = 'EntryAbility';

    const bundleName = abilityInfo.bundleName.trim() || fallbackBundleName;
    const moduleName = abilityInfo.moduleName?.trim() || fallbackModuleName;
    const abilityName = abilityInfo.name.trim() || fallbackAbilityName;

    const want: Want = {
      deviceId: '',
      bundleName: bundleName,
      moduleName: moduleName,
      abilityName: abilityName,
      parameters: {
        // 这个参数将在 EntryAbility 中被捕获
        openCapsuleImport: true,
        openScreenshotGallery: true,
        screenshotPath: latestPath || ''
      }
    };

    hilog.info(DOMAIN, TAG, 'ball click -> startAbility with want=%{public}s', JSON.stringify(want));

    // [修复] 移除 missionManager 逻辑，直接使用 startAbility。
    // 如果 Ability 配置为 singleton（默认推荐），系统会自动将其切换到前台。
    this.ctx.startAbility(want).then(() => {
      hilog.info(DOMAIN, TAG, 'startAbility success');
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'startAbility failed code=%{public}d detail=%{public}s', err.code, JSON.stringify(err));
    });
  }
}