import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { DatabaseManager } from './DatabaseManager';
import { Word } from '../model/WordModel';
import { util } from '@kit.ArkTS';

// 定义导入数据的接口
interface RawImportItem {
  word?: string;
  spelling?: string;
  headWord?: string;
  phonetic?: string;
  symbol?: string;
  meaning?: string;
  trans?: string;
  definition?: string;
  example?: string;
  note?: string;
  roots?: string[] | string;
  affixes?: string[] | string;
  collocations?: string[] | string;
  synonyms?: string[] | string;
  antonyms?: string[] | string;
  derivatives?: string[] | string;
  senses?: string[] | string;
  // 移除 tags，保持极简
}

export class WordImporter {

  /**
   * [修复版] 从沙箱路径直接导入 JSON 文件 (供 StorePage 下载使用)
   * 已移除不兼容的 tags 字段
   */
  static async importJsonFileFromPath(context: common.UIAbilityContext, filePath: string, bookName: string): Promise<number> {
    try {
      // 1. 读取文件内容
      const content = fs.readTextSync(filePath);

      // 2. 解析 JSON
      const parsed = JSON.parse(content) as object;
      if (!Array.isArray(parsed)) return 0;

      // 3. 转换数据
      const rawData = parsed as RawImportItem[];
      const wordList: Word[] = [];

      for (const item of rawData) {
        // 兼容处理 spelling 字段
        const spelling = item.spelling || item.word || item.headWord;
        if (spelling && spelling.trim() !== '') {
          // ⚠️ 关键修改：严格匹配 Word 接口，不允许多余字段
          wordList.push({
            bookId: bookName,
            spelling: spelling,
            meaning: item.meaning || item.trans || item.definition || '暂无释义',
            phonetic: item.phonetic || item.symbol || '',
            example: item.example || '',
            note: item.note || '', // 编程模式的注释用这个字段就够了

            roots: WordImporter.toArray(item.roots),
            affixes: WordImporter.toArray(item.affixes),
            collocations: WordImporter.toArray(item.collocations),
            synonyms: WordImporter.toArray(item.synonyms),
            antonyms: WordImporter.toArray(item.antonyms),
            derivatives: WordImporter.toArray(item.derivatives),
            senses: WordImporter.toArray(item.senses),

            // 初始化记忆状态
            knowledgeScore: 0,
            proficiency: 0,
            repetition: 0,
            interval: 0,
            easeFactor: 2.5,
            lastReviewTime: 0,
            nextReviewTime: 0
          });
        }
      }

      // 4. 批量写入数据库
      if (wordList.length > 0) {
        return await DatabaseManager.getInstance().batchInsertWords(bookName, wordList);
      }
      return 0;
    } catch (e) {
      console.error(`[WordImporter] Path Import Failed: ${JSON.stringify(e)}`);
      return 0;
    }
  }

  // 从 RawFile (内置资源) 导入
  static async importFromRawFile(context: common.UIAbilityContext, fileName: string, bookId: string): Promise<number> {
    let fileData: Uint8Array;
    const resourceMgr = context.resourceManager;

    try {
      try {
        fileData = await resourceMgr.getRawFileContent(`dicts/${fileName}`);
      } catch (error) {
        fileData = await resourceMgr.getRawFileContent(fileName);
      }
    } catch (error) {
      console.error(`[Lumina] File not found: ${fileName}`);
      return -2;
    }

    try {
      const textDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      const content = textDecoder.decodeToString(fileData);

      try {
        const parsed: object = JSON.parse(content) as object;
        if (Array.isArray(parsed)) {
          const array = parsed as object[];
          const rawData: RawImportItem[] = array.filter((item: object): boolean => typeof item === 'object' && item !== null) as RawImportItem[];
          return await WordImporter.processJsonData(rawData, bookId);
        }
      } catch (error) {}

      return await WordImporter.parseContentString(content, bookId);

    } catch (error) {
      console.error('[Lumina] Import Error:', JSON.stringify(error));
      return -1;
    }
  }

  // 文件选择器导入 (JSON)
  static async selectAndImportFile(context: common.UIAbilityContext, bookId: string): Promise<number> {
    try {
      const documentViewPicker = new picker.DocumentViewPicker(context);
      const selectOptions = new picker.DocumentSelectOptions();
      selectOptions.maxSelectNumber = 1;
      selectOptions.fileSuffixFilters = ['.json'];

      const uris = await documentViewPicker.select(selectOptions);
      if (uris.length === 0) return 0;

      return await WordImporter.parseAndSaveJson(uris[0], bookId);
    } catch (error) {
      return -1;
    }
  }

  // 文件选择器导入 (TXT)
  static async selectAndImportTxtFile(context: common.UIAbilityContext, bookId: string): Promise<number> {
    try {
      const documentViewPicker = new picker.DocumentViewPicker(context);
      const selectOptions = new picker.DocumentSelectOptions();
      selectOptions.maxSelectNumber = 1;
      selectOptions.fileSuffixFilters = ['.txt'];

      const uris = await documentViewPicker.select(selectOptions);
      if (uris.length === 0) return 0;

      const content = await WordImporter.readFileContent(uris[0]);
      if (!content) return -1;

      return await WordImporter.parseContentString(content, bookId);
    } catch (error) {
      return -1;
    }
  }

  // --- 辅助逻辑 ---

  private static async readFileContent(uri: string): Promise<string> {
    try {
      let file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      let stat = fs.statSync(file.fd);
      let buf = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buf);
      fs.closeSync(file);

      const textDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      return textDecoder.decodeToString(new Uint8Array(buf));
    } catch (error) {
      return '';
    }
  }

  private static async parseAndSaveJson(uri: string, bookId: string): Promise<number> {
    try {
      const content = await WordImporter.readFileContent(uri);
      const parsed: object = JSON.parse(content) as object;
      if (!Array.isArray(parsed)) {
        return -1;
      }

      const array = parsed as object[];
      const rawData: RawImportItem[] = array.filter((item: object): boolean => typeof item === 'object' && item !== null) as RawImportItem[];
      return await WordImporter.processJsonData(rawData, bookId);
    } catch (error) {
      return -1;
    }
  }

  private static async processJsonData(rawData: RawImportItem[], bookId: string): Promise<number> {
    const wordList: Word[] = [];
    rawData.forEach((item: RawImportItem) => {
      const spelling = item.word || item.spelling || item.headWord;

      if (spelling && spelling.trim() !== '') {
        wordList.push({
          bookId: bookId,
          spelling: spelling,
          phonetic: item.phonetic || item.symbol || '',
          meaning: item.meaning || item.trans || item.definition || '暂无释义',
          example: item.example || '',
          note: item.note || '',
          roots: WordImporter.toArray(item.roots),
          affixes: WordImporter.toArray(item.affixes),
          collocations: WordImporter.toArray(item.collocations),
          synonyms: WordImporter.toArray(item.synonyms),
          antonyms: WordImporter.toArray(item.antonyms),
          derivatives: WordImporter.toArray(item.derivatives),
          senses: WordImporter.toArray(item.senses),
          knowledgeScore: 0,
          proficiency: 0,
          repetition: 0,
          interval: 0,
          easeFactor: 2.5,
          lastReviewTime: 0,
          nextReviewTime: 0
        });
      }
    });

    if (wordList.length > 0) {
      return await DatabaseManager.getInstance().batchInsertWords(bookId, wordList);
    }
    return 0;
  }

  private static async parseContentString(content: string, bookId: string): Promise<number> {
    try {
      const lines = content.split(/\r?\n/);
      const wordList: Word[] = [];

      for (const line of lines) {
        const text = line.trim();
        if (!text) continue;

        let spelling = '';
        let phonetic = '';
        let meaning = '';

        // 提取音标
        const phoneticMatch = text.match(/(\/[^/]+\/|\[[^\]]+\])/);
        if (phoneticMatch) {
          phonetic = phoneticMatch[0];
        }

        let tempText = text;
        if (phonetic) {
          tempText = text.replace(phonetic, '');
        }

        // 分割单词和释义
        const wordMatch = tempText.trim().match(/^([^,，|\t\s]+)(?:[,，|\t\s]*)(.*)$/);

        if (wordMatch) {
          spelling = wordMatch[1];
          meaning = wordMatch[2].trim();
        } else {
          spelling = tempText.trim();
        }

        if (spelling && spelling.length > 0) {
          if (!meaning) meaning = '暂无释义';
          wordList.push({
            bookId: bookId,
            spelling: spelling,
            phonetic: phonetic,
            meaning: meaning,
            example: '',
            note: '',
            roots: [],
            affixes: [],
            collocations: [],
            synonyms: [],
            antonyms: [],
            derivatives: [],
            senses: [],
            knowledgeScore: 0,
            proficiency: 0,
            repetition: 0,
            interval: 0,
            easeFactor: 2.5,
            lastReviewTime: 0,
            nextReviewTime: 0
          });
        }
      }

      if (wordList.length > 0) {
        return await DatabaseManager.getInstance().batchInsertWords(bookId, wordList);
      }
      return 0;
    } catch (error) {
      return -1;
    }
  }

  private static toArray(value?: string[] | string): string[] {
    if (!value) return [];
    if (Array.isArray(value)) return value.map((item) => String(item).trim()).filter((v) => v.length > 0);
    return value.split(/[;,，；\n]/).map((v) => v.trim()).filter((v) => v.length > 0);
  }
}