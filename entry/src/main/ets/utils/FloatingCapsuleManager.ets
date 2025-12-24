import { common } from '@kit.AbilityKit';
import floatingBall from '@ohos.window.floatingBall';
import { LuminaLog } from './LuminaLog';

export class FloatingBallManager {
  private static inst: FloatingBallManager;

  private ctx: common.UIAbilityContext | null = null;
  private ctrl: floatingBall.FloatingBallController | null = null;
  private started: boolean = false;

  private constructor() {}

  static getInstance(): FloatingBallManager {
    if (!FloatingBallManager.inst) {
      FloatingBallManager.inst = new FloatingBallManager();
    }
    return FloatingBallManager.inst;
  }

  init(context: common.UIAbilityContext): void {
    this.ctx = context;
  }

  async start(): Promise<void> {
    if (this.started) return;

    const supported = floatingBall.isSupported();
    LuminaLog.i(`floatingBall.isSupported=${supported}`);
    if (!supported) return;

    this.ctrl = floatingBall.create();

    // 点击事件：这里是你要的“点球触发动作”
    this.ctrl.on('click', () => {
      LuminaLog.i('FloatingBall click');
      this.onClick();
    });

    // 可选：状态变化日志
    this.ctrl.on('stateChange', (state: floatingBall.FloatingBallState) => {
      LuminaLog.i(`FloatingBall stateChange=${state}`);
    });

    // params 以你本机 SDK 的 d.ts 为准（API20）
    // 这里用 ESObject 装进去，避免你 ArkTS 因字段差异直接编译不过
    const params = {} as ESObject;

    try {
      await this.ctrl.startFloatingBall(params as floatingBall.FloatingBallParams);
      this.started = true;
      LuminaLog.i('startFloatingBall OK');
    } catch (err) {
      LuminaLog.e(`startFloatingBall FAILED: ${LuminaLog.err(err as Object)}`);
    }
  }

  async stop(): Promise<void> {
    if (!this.ctrl) return;
    try {
      await this.ctrl.stopFloatingBall();
      LuminaLog.i('stopFloatingBall OK');
    } catch (err) {
      LuminaLog.e(`stopFloatingBall FAILED: ${LuminaLog.err(err as Object)}`);
    } finally {
      this.ctrl = null;
      this.started = false;
    }
  }

  // 你要的“点球后执行的逻辑”——后面把截屏/OCR/跳转放这里
  private onClick(): void {
    // TODO: 1) 自动截屏 2) 本地OCR 3) startAbility 跳转导入页
  }
}
