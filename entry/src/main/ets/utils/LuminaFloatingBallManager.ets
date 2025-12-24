import hilog from '@ohos.hilog';
import { common, Want } from '@kit.AbilityKit';
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

  async start(): Promise<void> {
    if (!this.ctx) {
      hilog.warn(DOMAIN, TAG, 'Floating ball start skipped: context not initialized');
      return;
    }
    if (this.started) return;

    try {
      const supported: boolean = await floatingBall.isFloatingBallSupported();
      hilog.info(DOMAIN, TAG, 'isFloatingBallSupported=%{public}s', String(supported));
      if (!supported) return;

      // 先创建控制器（文档写法：floatingBall.create() 获取 controller）:contentReference[oaicite:2]{index=2}
      this.controller = floatingBall.create();

      // 监听点击（社区/示例常见 click + stateChange；官方 d.ts 至少有 stateChange）:contentReference[oaicite:3]{index=3}
      this.controller.on('click', () => {
        this.onBallClick();
      });
      this.controller.on('stateChange', (st: floatingBall.FloatingBallState) => {
        hilog.info(DOMAIN, TAG, 'stateChange=%{public}s', JSON.stringify(st));
      });

      // 关键：NORMAL 模板需要 title，否则 Template is invalid. :contentReference[oaicite:4]{index=4}
      const params: floatingBall.FloatingBallParams = {
        template: floatingBall.FloatingBallTemplate.NORMAL,
        title: 'Lumina',
        content: '选截图识别'
      };

      await this.controller.startFloatingBall(params);
      this.started = true;
      hilog.info(DOMAIN, TAG, 'startFloatingBall OK');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'startFloatingBall FAILED: %{public}s', JSON.stringify(err));
    }
  }

  async stop(): Promise<void> {
    try {
      if (this.controller) {
        await this.controller.stopFloatingBall();
        this.controller.off('click');
        this.controller.off('stateChange');
        this.controller = null;
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'stopFloatingBall err=%{public}s', JSON.stringify(err));
    } finally {
      this.started = false;
    }
  }

  private onBallClick(): void {
    if (!this.ctx) return;

    // 标记：进入 CapsuleImportPage 后自动拉起选择截图
    CapsuleFlow.markAutoPickPending();

    const want: Want = {
      abilityName: 'EntryAbility',
      parameters: {
        openCapsuleImport: true
      }
    };

    hilog.info(DOMAIN, TAG, 'ball click -> startAbility to CapsuleImportPage');
    this.ctx.startAbility(want).catch((err) => {
      hilog.error(DOMAIN, TAG, 'startAbility failed=%{public}s', JSON.stringify(err));
    });
  }
}
