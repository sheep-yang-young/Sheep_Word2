import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { textRecognition } from '@kit.CoreVisionKit'; // 鸿蒙端侧 OCR
import { image } from '@kit.ImageKit';
import { DatabaseManager } from './DatabaseManager';
import { Word } from '../model/WordModel';

interface ScreenCaptureNamespace {
  createScreenCapture?: () => ScreenCaptureCreator;
}

interface ScreenCaptureCreator {
  start?: (options: ScreenCaptureOptions) => Promise<ScreenCaptureSession | undefined>;
}

interface ScreenCaptureOptions {
  captureMode: string;
}

interface ScreenCaptureSession {
  capture?: () => Promise<ScreenCaptureFrame | undefined>;
}

interface ScreenCaptureFrame {
  image?: ArrayBufferLike;
  pixelMap?: image.PixelMap;
}

export interface CapsuleWordCandidate {
  spelling: string;
  meaning: string;
  phonetic: string;
  hasMeaning: boolean;
}

export interface CapsuleRecognitionResult {
  words: CapsuleWordCandidate[];
  untranslated: string[];
  suggestedBook: string;
}

export class FloatingCapsuleManager {
  private static instance: FloatingCapsuleManager;
  private floatWin: window.Window | null = null;
  private context: common.UIAbilityContext | null = null;
  private isProcessing: boolean = false;
  private onRecognized: ((payload: CapsuleRecognitionResult) => void) | null = null;
  private lastResult: CapsuleRecognitionResult | null = null;

  private constructor() {}

  public static getInstance(): FloatingCapsuleManager {
    if (!FloatingCapsuleManager.instance) {
      FloatingCapsuleManager.instance = new FloatingCapsuleManager();
    }
    return FloatingCapsuleManager.instance;
  }

  public setRecognitionListener(callback: (payload: CapsuleRecognitionResult) => void) {
    this.onRecognized = callback;
    if (this.lastResult && callback) {
      callback(this.lastResult);
    }
  }

  /**
   * 显示悬浮胶囊
   * 注意：需要 ohos.permission.SYSTEM_FLOAT_WINDOW 权限
   */
  async showCapsule(context: common.UIAbilityContext) {
    this.context = context;
    if (this.floatWin) return;

    try {
      const windowConfig: window.Configuration = {
        name: "LuminaCapsule",
        windowType: window.WindowType.TYPE_FLOAT, // 系统悬浮窗
        ctx: context
      };

      this.floatWin = await window.createWindow(windowConfig);

      // 设置悬浮窗大小和初始位置
      await this.floatWin.resize(140, 50);
      await this.floatWin.moveWindowTo(600, 300);

      // 背景透明，配合 UI 圆角
      await this.floatWin.setWindowBackgroundColor('#00000000');

      // 加载 UI 页面
      await this.floatWin.setUIContent('pages/CapsulePage');
      await this.floatWin.showWindow();

    } catch (e) {
      console.error('[Capsule] Show failed:', JSON.stringify(e));
    }
  }

  /**
   * 关闭悬浮胶囊
   */
  async closeCapsule() {
    if (this.floatWin) {
      await this.floatWin.destroyWindow();
      this.floatWin = null;
    }
  }

  /**
   * 核心功能：调用闪控球/屏幕捕获 -> OCR 识别 -> 将候选词交给 UI 选择
   */
  async triggerImageImport(): Promise<number> {
    if (this.isProcessing || !this.context) return 0;
    this.isProcessing = true;
    let pixelMap: image.PixelMap | null = null;
    try {
      pixelMap = await this.captureCurrentScreen();
      if (!pixelMap) {
        console.warn('[Capsule] Screen capture unavailable');
        return 0;
      }

      const visionInfo: textRecognition.VisionInfo = { pixelMap: pixelMap };
      const textResult = await textRecognition.recognizeText(visionInfo);
      const fullText = textResult.value || '';

      const parsed = await this.parseWords(fullText);
      this.lastResult = parsed;
      if (this.onRecognized) {
        this.onRecognized(parsed);
      }

      return parsed.words.length;
    } catch (e) {
      console.error('[Capsule] Import failed:', JSON.stringify(e));
      return 0;
    } finally {
      if (pixelMap) {
        try { await pixelMap.release(); } catch (er) {}
      }
      this.isProcessing = false;
    }
  }

  /**
   * 将用户勾选的单词导入指定词书
   */
  async confirmImport(targetBookId: string, selected: CapsuleWordCandidate[]): Promise<CapsuleImportResult> {
    const bookId = (targetBookId && targetBookId.trim().length > 0) ? targetBookId.trim() : 'Captured_Words';
    const wordsToAdd: Word[] = [];
    const untranslated: string[] = [];

    selected.forEach(item => {
      wordsToAdd.push({
        bookId: bookId,
        spelling: item.spelling,
        phonetic: item.phonetic || '',
        meaning: item.meaning || '',
        proficiency: 0, repetition: 0, interval: 0, easeFactor: 2.5, lastReviewTime: 0, nextReviewTime: 0
      });
      if (!item.hasMeaning) untranslated.push(item.spelling);
    });

    let added = 0;
    if (wordsToAdd.length > 0) {
      added = await DatabaseManager.getInstance().batchInsertWords(bookId, wordsToAdd);
    }

    return { added, untranslated };
  }

  private async captureCurrentScreen(): Promise<image.PixelMap | null> {
    // 尝试新的 ScreenCaptureKit
    try {
      const creator = this.createScreenCapture();
      if (creator) {
        const session = await creator.start?.({ captureMode: 'IMAGE' });
        const frame = await session?.capture?.();
        if (frame?.image) {
          const source = image.createImageSource(frame.image);
          const map = await source.createPixelMap();
          try { await source.release(); } catch (err) {}
          return map;
        }
        if (frame?.pixelMap) {
          return frame.pixelMap;
        }
      }
    } catch (e) {
      console.warn('[Capsule] ScreenCaptureKit failed, fallback...', JSON.stringify(e));
    }

    // 退化方案：调用 window 快照（部分设备支持）
    try {
      const mainWindowGetter = (window as unknown as { getLastWindow?: (ctx: common.UIAbilityContext | null) => Promise<window.Window | null> }).getLastWindow;
      const mainWindow = mainWindowGetter ? await mainWindowGetter(this.context) : null;
      const snapshotFn = mainWindow as unknown as { snapshot?: () => Promise<image.PixelMap> };
      if (snapshotFn?.snapshot) {
        return await snapshotFn.snapshot();
      }
    } catch (e) {
      console.warn('[Capsule] window.snapshot unavailable');
    }

    return null;
  }

  private async parseWords(fullText: string): Promise<CapsuleRecognitionResult> {
    const rawWords = fullText.split(/[^a-zA-Z]/).filter(w => w.length > 2);
    const uniqueWords = Array.from(new Set(rawWords.map(w => w.trim().toLowerCase())));

    const words: CapsuleWordCandidate[] = [];
    const untranslated: string[] = [];
    const suggestedBook = await DatabaseManager.getInstance().findAnyValidBook();

    for (const spelling of uniqueWords) {
      const normalized = spelling.trim();
      if (!normalized) continue;

      const existing = await DatabaseManager.getInstance().findWordGlobal(normalized);
      let meaning = '';
      let phonetic = '';
      let hasMeaning = false;

      if (existing && existing.meaning) {
        meaning = existing.meaning;
        phonetic = existing.phonetic || '';
        hasMeaning = true;
      } else {
        meaning = await this.tryLocalTranslate(normalized);
        hasMeaning = meaning.trim().length > 0;
      }

      if (!hasMeaning) {
        untranslated.push(normalized);
      }

      words.push({ spelling: normalized, meaning, phonetic, hasMeaning });
    }

    return { words, untranslated, suggestedBook };
  }

  private async tryLocalTranslate(spelling: string): Promise<string> {
    // 保持离线：只尝试本地翻译能力，缺失则返回空
    try {
      const translator = this.getLocalTranslator();
      if (translator && typeof translator.translate === 'function') {
        const result = await translator.translate({ text: spelling, sourceLang: 'en', targetLang: 'zh' });
        if (result?.text) return String(result.text);
      }
    } catch (e) {
      console.info('[Capsule] Local translation unavailable, staying offline');
    }
    return '';
  }

  private createScreenCapture(): ScreenCaptureCreator | null {
    const namespace = (globalThis as unknown as { screenCapture?: ScreenCaptureNamespace }).screenCapture;
    if (namespace?.createScreenCapture) {
      return namespace.createScreenCapture();
    }
    return null;
  }

  private getLocalTranslator(): LocalTranslator | null {
    const plugin = (globalThis as unknown as { systemPlugin?: { translation?: LocalTranslator } }).systemPlugin;
    if (plugin?.translation) {
      return plugin.translation;
    }
    const fallback = (globalThis as unknown as { translator?: LocalTranslator }).translator;
    return fallback ?? null;
  }
}

interface LocalTranslator {
  translate?: (options: { text: string; sourceLang: string; targetLang: string }) => Promise<{ text?: string }>;
}

interface CapsuleImportResult {
  added: number;
  untranslated: string[];
}
