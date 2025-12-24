import hilog from '@ohos.hilog';
import { common, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import floatingBall from '@ohos.window.floatingBall';
import { CapsuleFlow } from './CapsuleFlow';

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

      // [修复] 参数必须包裹在对象中
      this.controller = await floatingBall.create({ context: this.ctx });

      if (!this.controller) {
        hilog.error(DOMAIN, TAG, 'Controller creation failed (null)');
        return;
      }

      // 设置点击监听
      this.controller.on('click', () => {
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
      hilog.info(DOMAIN, TAG, 'startFloatingBall OK');
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

  private onBallClick(): void {
    if (!this.ctx) return;

    // 标记：进入页面后自动拉起选择截图
    CapsuleFlow.markAutoPickPending();

    const want: Want = {
      abilityName: 'EntryAbility',
      parameters: {
        // 这个参数将在 EntryAbility 中被捕获
        openCapsuleImport: true
      }
    };

    hilog.info(DOMAIN, TAG, 'ball click -> startAbility to CapsuleImportPage');
    this.ctx.startAbility(want).catch((err: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'startAbility failed=%{public}s', JSON.stringify(err));
    });
  }
}