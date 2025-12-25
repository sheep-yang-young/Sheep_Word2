import hilog from '@ohos.hilog';
import { common } from '@kit.AbilityKit';
import { textRecognition } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { DatabaseManager } from './DatabaseManager';
import { Word } from '../model/WordModel';

const DOMAIN: number = 0xA0A03D;
const TAG: string = 'LuminaOCR';

export class CapsuleWordCandidate {
  spelling: string = '';
  meaning: string = '';
  phonetic: string = '';
  hasMeaning: boolean = false;
}

export class CapsuleRecognitionResult {
  words: CapsuleWordCandidate[] = [];
  untranslated: string[] = [];
  suggestedBook: string = '';
}

interface CapsuleImportResult {
  added: number;
  untranslated: string[];
}

interface TranslateOptions {
  text: string;
  sourceLang: string;
  targetLang: string;
}
interface TranslateResult {
  text?: string;
}
interface LocalTranslator {
  translate(options: TranslateOptions): Promise<TranslateResult>;
}

// [修复 Error 5] 提取接口，避免嵌套字面量类型
interface TranslateSystemPlugin {
  translation?: LocalTranslator;
}

interface GlobalTranslatorHost {
  systemPlugin?: TranslateSystemPlugin;
  translator?: LocalTranslator;
}

// [修复 Error 6] 提取接口
interface DecodeResult {
  pixelMap: image.PixelMap;
  fd: number;
}

export class FloatingCapsuleManager {
  private static instance: FloatingCapsuleManager;

  private context: common.UIAbilityContext | null = null;
  private isProcessing: boolean = false;

  private onRecognized: ((payload: CapsuleRecognitionResult) => void) | null = null;
  private lastResult: CapsuleRecognitionResult | null = null;

  private constructor() {}

  static getInstance(): FloatingCapsuleManager {
    if (!FloatingCapsuleManager.instance) {
      FloatingCapsuleManager.instance = new FloatingCapsuleManager();
    }
    return FloatingCapsuleManager.instance;
  }

  init(context: common.UIAbilityContext): void {
    this.context = context;
  }

  setRecognitionListener(callback: (payload: CapsuleRecognitionResult) => void): void {
    this.onRecognized = callback;
    if (this.lastResult) callback(this.lastResult);
  }

  getLastResult(): CapsuleRecognitionResult | null {
    return this.lastResult;
  }

  async triggerImportByUserPicker(): Promise<number> {
    if (this.isProcessing || !this.context) return 0;
    this.isProcessing = true;

    let pixelMap: image.PixelMap | null = null;
    let fd: number | null = null;

    try {
      const uri: string | null = await this.pickOneImageUri();
      if (!uri) return 0;

      const decode: DecodeResult = await this.decodePixelMapFromUri(uri);
      pixelMap = decode.pixelMap;
      fd = decode.fd;

      const visionInfo: textRecognition.VisionInfo = { pixelMap: pixelMap };
      const textResult = await textRecognition.recognizeText(visionInfo);
      const fullText: string = (textResult && textResult.value) ? String(textResult.value) : '';

      hilog.info(DOMAIN, TAG, 'OCR text length=%{public}d', fullText.length);

      const parsed: CapsuleRecognitionResult = await this.parseWords(fullText);
      this.lastResult = parsed;

      if (this.onRecognized) this.onRecognized(parsed);

      return parsed.words.length;
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'Import failed=%{public}s', JSON.stringify(error));
      return 0;
    } finally {
      if (pixelMap) {
        try { await pixelMap.release(); } catch (e) {}
      }
      if (fd !== null) {
        try { fileIo.closeSync(fd); } catch (e) {}
      }
      this.isProcessing = false;
    }
  }

  async triggerImportFromFile(path: string): Promise<number> {
    if (this.isProcessing || !this.context || !path) return 0;
    this.isProcessing = true;

    let pixelMap: image.PixelMap | null = null;
    let fd: number | null = null;

    try {
      const decode: DecodeResult = await this.decodePixelMapFromUri(path);
      pixelMap = decode.pixelMap;
      fd = decode.fd;

      const visionInfo: textRecognition.VisionInfo = { pixelMap: pixelMap };
      const textResult = await textRecognition.recognizeText(visionInfo);
      const fullText: string = (textResult && textResult.value) ? String(textResult.value) : '';

      hilog.info(DOMAIN, TAG, 'OCR (file) text length=%{public}d', fullText.length);

      const parsed: CapsuleRecognitionResult = await this.parseWords(fullText);
      this.lastResult = parsed;

      if (this.onRecognized) this.onRecognized(parsed);

      return parsed.words.length;
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'Import from file failed=%{public}s', JSON.stringify(error));
      return 0;
    } finally {
      if (pixelMap) {
        try { await pixelMap.release(); } catch (e) {}
      }
      if (fd !== null) {
        try { fileIo.closeSync(fd); } catch (e) {}
      }
      this.isProcessing = false;
    }
  }

  async confirmImport(targetBookId: string, selected: CapsuleWordCandidate[]): Promise<CapsuleImportResult> {
    const bookId: string = targetBookId?.trim() ?? '';

    const untranslated: string[] = selected
      .filter(item => !item.hasMeaning)
      .map(item => item.spelling);

    if (!bookId) {
      hilog.warn(DOMAIN, TAG, 'No target book specified, skip import');
      return { added: 0, untranslated };
    }

    const wordsToAdd: Word[] = [];

    for (const item of selected) {
      const w: Word = {
        bookId: bookId,
        spelling: item.spelling,
        phonetic: item.phonetic || '',
        meaning: item.meaning || '',
        proficiency: 0,
        repetition: 0,
        interval: 0,
        easeFactor: 2.5,
        lastReviewTime: 0,
        nextReviewTime: 0
      };
      wordsToAdd.push(w);
    }

    let added: number = 0;
    if (wordsToAdd.length > 0) {
      added = await DatabaseManager.getInstance().batchInsertWords(bookId, wordsToAdd);
    }
    return { added, untranslated };
  }

  private async pickOneImageUri(): Promise<string | null> {
    if (!this.context) return null;

    const opt = new photoAccessHelper.PhotoSelectOptions();
    opt.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    opt.maxSelectNumber = 1;

    const picker = new photoAccessHelper.PhotoViewPicker();
    const res = await picker.select(opt);

    if (!res || !res.photoUris || res.photoUris.length <= 0) {
      hilog.warn(DOMAIN, TAG, 'No image selected');
      return null;
    }
    const uri: string = String(res.photoUris[0]);
    hilog.info(DOMAIN, TAG, 'picked uri=%{public}s', uri);
    return uri;
  }

  // [修复 Error 6] 使用接口作为返回类型
  private async decodePixelMapFromUri(uri: string): Promise<DecodeResult> {
    const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    const fd: number = file.fd;

    const imageSource = image.createImageSource(fd);
    const pixelMap = await imageSource.createPixelMap();
    await imageSource.release();

    // [修复 Error 7] 返回符合接口的对象
    return { pixelMap, fd };
  }

  private async parseWords(fullText: string): Promise<CapsuleRecognitionResult> {
    const raw = fullText.split(/[^a-zA-Z]/).filter((w: string) => w.length > 2);
    const unique: string[] = Array.from(new Set(raw.map((w: string) => w.trim().toLowerCase())));

    const words: CapsuleWordCandidate[] = [];
    const untranslated: string[] = [];
    const suggestedBook: string = await DatabaseManager.getInstance().findAnyValidBook();

    for (const spelling of unique) {
      const normalized: string = spelling.trim();
      if (!normalized) continue;

      const existing = await DatabaseManager.getInstance().findWordGlobal(normalized);

      let meaning: string = '';
      let phonetic: string = '';
      let hasMeaning: boolean = false;

      if (existing && existing.meaning) {
        meaning = existing.meaning;
        phonetic = existing.phonetic || '';
        hasMeaning = true;
      } else {
        meaning = await this.tryLocalTranslate(normalized);
        hasMeaning = meaning.trim().length > 0;
      }

      if (!hasMeaning) untranslated.push(normalized);

      const c = new CapsuleWordCandidate();
      c.spelling = normalized;
      c.meaning = meaning;
      c.phonetic = phonetic;
      c.hasMeaning = hasMeaning;
      words.push(c);
    }

    const res = new CapsuleRecognitionResult();
    res.words = words;
    res.untranslated = untranslated;
    res.suggestedBook = suggestedBook;
    return res;
  }

  private async tryLocalTranslate(spelling: string): Promise<string> {
    try {
      const translator = this.getLocalTranslator();
      if (translator) {
        const result = await translator.translate({ text: spelling, sourceLang: 'en', targetLang: 'zh' });
        if (result && result.text) return String(result.text);
      }
    } catch (err) {
      hilog.info(DOMAIN, TAG, 'Local translation unavailable');
    }
    return '';
  }

  private getLocalTranslator(): LocalTranslator | null {
    const g = globalThis as GlobalTranslatorHost;
    if (g.systemPlugin && g.systemPlugin.translation) return g.systemPlugin.translation;
    if (g.translator) return g.translator;
    return null;
  }
}