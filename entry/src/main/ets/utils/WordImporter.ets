import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { DatabaseManager } from './DatabaseManager';
import { Word } from '../model/WordModel';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';

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
}

export class WordImporter {

  // 从 RawFile (内置资源) 导入
  static async importFromRawFile(context: common.UIAbilityContext, fileName: string, bookId: string): Promise<number> {
    let fileData: Uint8Array;
    const resourceMgr = context.resourceManager;

    try {
      // 尝试从 dicts/ 目录读取
      try {
        fileData = await resourceMgr.getRawFileContent(`dicts/${fileName}`);
      } catch (error) {
        // 如果失败，尝试从 rawfile 根目录读取
        fileData = await resourceMgr.getRawFileContent(fileName);
      }
    } catch (error) {
      console.error(`[Lumina] File not found: ${fileName}`);
      return -2;
    }

    try {
      const textDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      const content = textDecoder.decodeToString(fileData);

      // 尝试作为 JSON 解析
      try {
        // [关键修复] 显式断言 JSON.parse 的返回类型
        const rawData = JSON.parse(content) as RawImportItem[];
        if (Array.isArray(rawData)) {
          return await WordImporter.processJsonData(rawData, bookId);
        }
      } catch (error) {
        // 不是 JSON，忽略，继续走文本解析
      }

      // 走 TXT 解析
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
      // [关键修复] 显式断言类型
      const rawData = JSON.parse(content) as RawImportItem[];
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
}