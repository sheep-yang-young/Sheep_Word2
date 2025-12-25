import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import hilog from '@ohos.hilog';
import { PreferenceManager } from './PreferenceManager';
import { Word } from '../model/WordModel';

const DOMAIN: number = 0xA0A03D;
const TAG: string = 'CustomBookService';
const DEFAULT_FILE_NAME = 'Lumina_Custom_Book.json';

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

  async appendWord(word: Word): Promise<AppendResult> {
    if (!this.ctx) {
      hilog.error(DOMAIN, TAG, 'appendWord aborted: context missing');
      return 'error';
    }

    try {
      const path = await this.prepareFile();
      const content = fileIo.readTextSync(path);
      const parsed: object = JSON.parse(content) as object;
      const list: Word[] = Array.isArray(parsed) ? parsed as Word[] : [];

      const exists = list.some(item => (item?.spelling || '').trim().toLowerCase() === (word.spelling || '').trim().toLowerCase());
      if (exists) {
        return 'duplicate';
      }

      const serialized = this.serializeWord(word);
      list.push(serialized);
      fileIo.writeTextSync(path, JSON.stringify(list, null, 2));
      return 'success';
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
      fileIo.writeTextSync(path, '[]');
      return path;
    }

    try {
      const text = fileIo.readTextSync(path);
      const parsed: object = JSON.parse(text) as object;
      if (!Array.isArray(parsed)) {
        fileIo.writeTextSync(path, '[]');
      }
    } catch (e) {
      fileIo.writeTextSync(path, '[]');
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
}
