import { common } from '@kit.AbilityKit';
import floatingBall from '@ohos.window.floatingBall';
import { LuminaLog } from './LuminaLog';

type FloatingBallModule = typeof floatingBall & { isSupported?: () => boolean };

export interface CapsuleWordCandidate {
  spelling: string;
  meaning?: string;
  hasMeaning?: boolean;
}

export interface CapsuleRecognitionResult {
  words: CapsuleWordCandidate[];
  untranslated: string[];
  suggestedBook?: string;
}

export class FloatingCapsuleManager {
  private static inst: FloatingCapsuleManager;

  private ctx: common.UIAbilityContext | null = null;
  private ctrl: floatingBall.FloatingBallController | null = null;
  private started: boolean = false;
  private recognitionListener: ((payload: CapsuleRecognitionResult) => void) | null = null;

  private constructor() {}

  static getInstance(): FloatingCapsuleManager {
    if (!FloatingCapsuleManager.inst) {
      FloatingCapsuleManager.inst = new FloatingCapsuleManager();
    }
    return FloatingCapsuleManager.inst;
  }

  init(context: common.UIAbilityContext): void {
    this.ctx = context;
  }

  setRecognitionListener(listener: (payload: CapsuleRecognitionResult) => void): void {
    this.recognitionListener = listener;
  }

  async showCapsule(context: common.UIAbilityContext): Promise<void> {
    this.init(context);
    await this.start();
  }

  async start(): Promise<void> {
    if (this.started) return;
    if (!this.ctx) {
      LuminaLog.w('Floating capsule start skipped: context not initialized');
      return;
    }

    const moduleWithSupport = floatingBall as FloatingBallModule;
    const supported = moduleWithSupport.isSupported ? moduleWithSupport.isSupported() : true;
    LuminaLog.i(`floatingBall.isSupported=${supported}`);
    if (!supported) return;

    const controller = await floatingBall.create(this.ctx);
    this.ctrl = controller;

    if (!this.ctrl) {
      LuminaLog.w('Floating capsule controller is null after creation');
      return;
    }

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
    const params = {} as floatingBall.FloatingBallParams;

    try {
      await this.ctrl.startFloatingBall(params);
      this.started = true;
      LuminaLog.i('startFloatingBall OK');
    } catch (err) {
      LuminaLog.e(`startFloatingBall FAILED: ${LuminaLog.err(err)}`);
    }
  }

  async stop(): Promise<void> {
    if (!this.ctrl) return;
    try {
      await this.ctrl.stopFloatingBall();
      LuminaLog.i('stopFloatingBall OK');
    } catch (err) {
      LuminaLog.e(`stopFloatingBall FAILED: ${LuminaLog.err(err)}`);
    } finally {
      this.ctrl = null;
      this.started = false;
    }
  }

  async triggerImageImport(): Promise<number> {
    LuminaLog.i('triggerImageImport invoked');
    if (this.recognitionListener) {
      const mockPayload: CapsuleRecognitionResult = {
        words: [],
        untranslated: [],
        suggestedBook: undefined
      };
      this.recognitionListener(mockPayload);
      return mockPayload.words.length;
    }
    return 0;
  }

  async confirmImport(targetBook: string, candidates: CapsuleWordCandidate[]): Promise<{ added: number; untranslated: string[] }> {
    LuminaLog.i(`confirmImport: targetBook=${targetBook}, count=${candidates.length}`);
    const untranslated = candidates.filter(item => !item.meaning).map(item => item.spelling);
    const added = candidates.length;
    return { added, untranslated };
  }

  // 你要的“点球后执行的逻辑”——后面把截屏/OCR/跳转放这里
  private onClick(): void {
    // TODO: 1) 自动截屏 2) 本地OCR 3) startAbility 跳转导入页
  }
}

export { FloatingCapsuleManager as FloatingBallManager };
