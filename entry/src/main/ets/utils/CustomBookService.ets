import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS'; // 新增引用，用于 TextEncoder
import hilog from '@ohos.hilog';
import { PreferenceManager } from './PreferenceManager';
import { Word } from '../model/WordModel';
import { DatabaseManager } from './DatabaseManager';

const DOMAIN: number = 0xA0A03D;
const TAG: string = 'CustomBookService';
const DEFAULT_FILE_NAME = 'Lumina_Custom_Book.json';
export const CUSTOM_BOOK_ID = 'Custom_Book';

type AppendResult = 'success' | 'duplicate' | 'error';

export class CustomBookService {
  private static instance: CustomBookService = new CustomBookService();
  private ctx: common.UIAbilityContext | null = null;

  static getInstance(): CustomBookService {
    return CustomBookService.instance;
  }

  init(context: common.UIAbilityContext): void {
    this.ctx = context;
  }

  async setCustomBookFileName(fileName: string): Promise<void> {
    if (!this.ctx) return;
    await PreferenceManager.getInstance().init(this.ctx);
    const safeName = this.sanitizeFileName(fileName);
    await PreferenceManager.getInstance().setCustomBookFileName(safeName);
  }

  async getCustomBookFilePath(): Promise<string | null> {
    if (!this.ctx) return null;
    await PreferenceManager.getInstance().init(this.ctx);
    const storedName = await PreferenceManager.getInstance().getCustomBookFileName();
    const fileName = this.sanitizeFileName(storedName) || DEFAULT_FILE_NAME;
    return `${this.ctx.filesDir}/${fileName}`;
  }

  async appendWord(word: Word, opts?: { setAsCurrent?: boolean }): Promise<AppendResult> {
    if (!this.ctx) {
      hilog.error(DOMAIN, TAG, 'appendWord aborted: context missing');
      return 'error';
    }

    try {
      await PreferenceManager.getInstance().init(this.ctx);
      await DatabaseManager.getInstance().init(this.ctx);

      const normalizedWord = this.serializeWord({ ...word, bookId: CUSTOM_BOOK_ID });
      const spellingKey = (normalizedWord.spelling || '').trim().toLowerCase();
      if (!spellingKey) {
        hilog.warn(DOMAIN, TAG, 'appendWord aborted: spelling missing');
        return 'error';
      }

      const existsInDb = await DatabaseManager.getInstance().checkWordExists(CUSTOM_BOOK_ID, normalizedWord.spelling || '');

      const path = await this.prepareFile();
      const content = fileIo.readTextSync(path);
      const parsed: object = JSON.parse(content) as object;
      const list: Word[] = Array.isArray(parsed) ? parsed as Word[] : [];

      const existsInFile = list.some(item => (item?.spelling || '').trim().toLowerCase() === spellingKey);
      if (existsInDb || existsInFile) {
        return 'duplicate';
      }

      const updatedList = [...list, normalizedWord];
      this.writeUtf8Text(path, JSON.stringify(updatedList, null, 2));

      const inserted = await DatabaseManager.getInstance().addWord(normalizedWord);
      if (inserted > 0) {
        await PreferenceManager.getInstance().registerBookCategory(CUSTOM_BOOK_ID, 'User');
        if (opts?.setAsCurrent) {
          await PreferenceManager.getInstance().setCurrentBook(CUSTOM_BOOK_ID);
        }
        return 'success';
      }

      // 回滚文件写入，确保 JSON 备份与数据库一致
      this.writeUtf8Text(path, JSON.stringify(list, null, 2));
      return 'error';
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'appendWord failed %{public}s', JSON.stringify(e));
      return 'error';
    }
  }

  private async prepareFile(): Promise<string> {
    const path = await this.getCustomBookFilePath();
    if (!path) {
      throw new Error('Custom book path unavailable');
    }

    try {
      const stat = fileIo.statSync(path);
      if (!stat?.isFile()) {
        throw new Error('Target path is not a file');
      }
    } catch (e) {
      this.writeUtf8Text(path, '[]');
      return path;
    }

    try {
      const text = fileIo.readTextSync(path);
      const parsed: object = JSON.parse(text) as object;
      if (!Array.isArray(parsed)) {
        this.writeUtf8Text(path, '[]');
      }
    } catch (e) {
      this.writeUtf8Text(path, '[]');
    }
    return path;
  }

  private sanitizeFileName(name: string | null | undefined): string {
    if (!name || name.trim().length === 0) return DEFAULT_FILE_NAME;
    // Remove directory separators and fall back to default when invalid characters are present
    const cleaned = name.replace(/[\\\/]/g, '').trim();
    return cleaned.length > 0 ? cleaned : DEFAULT_FILE_NAME;
  }

  private serializeWord(word: Word): Word {
    const serialized: Word = {
      id: word.id,
      bookId: word.bookId,
      spelling: word.spelling,
      phonetic: word.phonetic,
      meaning: word.meaning,
      example: word.example,
      note: word.note,
      roots: word.roots,
      affixes: word.affixes,
      collocations: word.collocations,
      synonyms: word.synonyms,
      antonyms: word.antonyms,
      derivatives: word.derivatives,
      senses: word.senses,
      knowledgeScore: word.knowledgeScore,
      proficiency: word.proficiency,
      repetition: word.repetition,
      interval: word.interval,
      easeFactor: word.easeFactor,
      lastReviewTime: word.lastReviewTime,
      nextReviewTime: word.nextReviewTime,
      proficiencySpelling: word.proficiencySpelling,
      repetitionSpelling: word.repetitionSpelling,
      intervalSpelling: word.intervalSpelling,
      easeFactorSpelling: word.easeFactorSpelling,
      lastReviewTimeSpelling: word.lastReviewTimeSpelling,
      nextReviewTimeSpelling: word.nextReviewTimeSpelling
    };
    return serialized;
  }

  private writeUtf8Text(path: string, content: string): void {
    const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      // 使用 util 模块的 TextEncoder
      const textEncoder = new util.TextEncoder();
      // encodeInto 返回 Uint8Array
      const encoded = textEncoder.encodeInto(content);
      // fileIo.writeSync 需要 ArrayBuffer，显式转换
      fileIo.writeSync(file.fd, encoded.buffer as ArrayBuffer);
    } finally {
      fileIo.closeSync(file.fd);
    }
  }
}