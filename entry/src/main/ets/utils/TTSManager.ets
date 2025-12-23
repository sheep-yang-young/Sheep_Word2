import { textToSpeech } from '@kit.CoreSpeechKit';
import { promptAction } from '@kit.ArkUI';

type Lang = 'en-US' | 'zh-CN';

/** createEngine extraParams：先定义明确类型 */
interface TTSEngineExtraParams {
  style: string;
  locate: string;
  name: string;
}

/** 让对象字面量“有类型可对齐”，同时满足 Record<string, object> */
interface EngineExtraParamsRecord extends Record<string, object> {
  params: TTSEngineExtraParams;
}

/** SpeakParams.extraParams 的类型在你 SDK 里是 Record<string, Object> */
interface SpeakExtraParamsRecord extends Record<string, Object> {
  volume: Number;
  rate: Number;
  pitch: Number;
}

interface ToastOptions {
  message: string;
  duration: number;
}

interface Listener {
  onStart: (requestId: string) => void;
  onComplete: (requestId: string) => void;
  onStop: (requestId: string) => void;
  onError: (requestId: string, errorCode: number, errorMessage: string) => void;
}

/** 用于 catch 里安全拿 message（不写 any/unknown） */
interface ErrorLike {
  name?: string;
  message?: string;
}

export class TTSManager {
  private static instance: TTSManager;

  private enEngine: textToSpeech.TextToSpeechEngine | null = null;
  private zhEngine: textToSpeech.TextToSpeechEngine | null = null;

  private initTask: Promise<void> | null = null;
  private inited: boolean = false;

  private offlineToastShown: boolean = false;
  private failedToastShown: boolean = false;

  private constructor() {}

  public static getInstance(): TTSManager {
    if (!TTSManager.instance) {
      TTSManager.instance = new TTSManager();
    }
    return TTSManager.instance;
  }

  public init(): Promise<void> {
    if (this.inited) return Promise.resolve();
    if (this.initTask) return this.initTask;

    this.initTask = (async () => {
      await Promise.all([
        this.createEngineWithFallback('en-US'),
        this.createEngineWithFallback('zh-CN')
      ]);
      this.inited = true;
    })().finally(() => {
      this.initTask = null;
    });

    return this.initTask;
  }

  public async speak(text: string, isChinese: boolean): Promise<void> {
    await this.init();

    const lang: Lang = isChinese ? 'zh-CN' : 'en-US';
    const engine: textToSpeech.TextToSpeechEngine | null = isChinese ? this.zhEngine : this.enEngine;

    if (!engine) {
      if (!this.failedToastShown) {
        this.showToastMsg('TTS 未就绪：请检查系统语音能力/语音包或设备是否支持');
        this.failedToastShown = true;
      }
      console.warn(`[TTSManager] Engine is null for ${lang}`);
      return;
    }

    const listener: Listener = {
      onStart: (_requestId: string) => {},
      onComplete: (_requestId: string) => {},
      onStop: (_requestId: string) => {},
      onError: (requestId: string, errorCode: number, errorMessage: string) => {
        console.error(`[TTSManager] speak onError lang=${lang} req=${requestId} code=${errorCode} msg=${errorMessage}`);
      }
    };

    try {
      engine.setListener(listener);
    } catch (e) {
      console.error(`[TTSManager] setListener exception: ${this.errToString(e)}`);
    }

    // ✅ 关键：满足 Record<string, Object>，value 用 Number 对象
    const speakExtra: SpeakExtraParamsRecord = {
      volume: new Number(1.0),
      rate: new Number(1.0),
      pitch: new Number(1.0)
    };

    const speakParams: textToSpeech.SpeakParams = {
      requestId: Date.now().toString(),
      extraParams: speakExtra
    };

    try {
      engine.speak(text, speakParams);
    } catch (e) {
      console.error(`[TTSManager] speak exception: ${this.errToString(e)}`);
    }
  }

  public stop(): void {
    try { this.enEngine?.stop(); } catch {}
    try { this.zhEngine?.stop(); } catch {}
  }

  public shutdown(): void {
    this.stop();
    this.enEngine = null;
    this.zhEngine = null;

    this.inited = false;
    this.initTask = null;

    this.offlineToastShown = false;
    this.failedToastShown = false;
  }

  // -------------------- 内部 --------------------

  private async createEngineWithFallback(language: Lang): Promise<void> {
    const okOffline: boolean = await this.createEngine(language, 0);
    if (okOffline) return;

    if (!this.offlineToastShown) {
      this.showToastMsg('离线语音不可用：请在系统设置中下载离线语音包（或设备不支持离线TTS）');
      this.offlineToastShown = true;
    }

    const okOnline: boolean = await this.createEngine(language, 1);
    if (okOnline) {
      console.info(`[TTSManager] Fallback online engine ok for ${language}`);
      return;
    }

    console.error(`[TTSManager] Both offline and online createEngine failed for ${language}`);
  }

  private createEngine(language: Lang, online: 0 | 1): Promise<boolean> {
    const uniqueName: string =
      `TTS_${language}_${Date.now()}_${Math.floor(Math.random() * 1000000)}`;

    const engineExtra: TTSEngineExtraParams = {
      style: 'interaction-broadcast',
      locate: 'CN',
      name: uniqueName
    };

    // ✅ 明确 interface，避免 untyped obj literal
    const extraParams: EngineExtraParamsRecord = {
      params: engineExtra
    };

    const initParams: textToSpeech.CreateEngineParams = {
      language,
      person: 0,
      online,
      extraParams
    };

    return new Promise((resolve) => {
      try {
        textToSpeech.createEngine(initParams, (err, engine) => {
          if (!err && engine) {
            console.info(`[TTSManager] createEngine ok lang=${language} online=${online}`);
            if (language === 'en-US') this.enEngine = engine;
            else this.zhEngine = engine;
            resolve(true);
            return;
          }
          console.error(`[TTSManager] createEngine failed lang=${language} online=${online} code=${err?.code} msg=${err?.message}`);
          resolve(false);
        });
      } catch (e) {
        console.error(`[TTSManager] createEngine exception: ${this.errToString(e)}`);
        resolve(false);
      }
    });
  }

  private showToastMsg(msg: string): void {
    const toast: ToastOptions = { message: msg, duration: 3000 };
    try {
      promptAction.showToast(toast);
    } catch {}
  }

  private errToString(e: object): string {
    // catch 里拿到的是 object（不标注类型），这里用 ErrorLike 安全读取
    const maybe: ErrorLike = e as ErrorLike;
    const name: string = maybe.name ? maybe.name : 'Error';
    const message: string = maybe.message ? maybe.message : '';
    return `${name}${message.length > 0 ? (': ' + message) : ''}`;
  }
}
