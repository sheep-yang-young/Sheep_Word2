import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { DatabaseManager } from './DatabaseManager';
import { Word } from '../model/WordModel';
import { util } from '@kit.ArkTS';

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
}

export class WordImporter {
  static async selectAndImportFile(context: common.UIAbilityContext): Promise<number> {
    try {
      const documentViewPicker = new picker.DocumentViewPicker(context);
      const selectOptions = new picker.DocumentSelectOptions();
      selectOptions.maxSelectNumber = 1;
      selectOptions.fileSuffixFilters = ['.json'];

      const uris = await documentViewPicker.select(selectOptions);
      if (uris.length === 0) return 0;

      const uri = uris[0];
      return await WordImporter.parseAndSave(uri);

    } catch (err) {
      console.error(`[Lumina] Picker failed: ${JSON.stringify(err)}`);
      return -1;
    }
  }

  private static async parseAndSave(uri: string): Promise<number> {
    try {
      let file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      let stat = fs.statSync(file.fd);
      let buf = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buf);
      fs.closeSync(file);

      const textDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      const content = textDecoder.decodeToString(new Uint8Array(buf));

      const rawData = JSON.parse(content) as RawImportItem[];
      const wordList: Word[] = [];

      rawData.forEach(item => {
        const spelling = item.word || item.spelling || item.headWord;

        if (spelling && spelling.trim() !== '') {
          // [修复] 补全所有字段以匹配 Word 接口
          wordList.push({
            spelling: spelling,
            phonetic: item.phonetic || item.symbol || '',
            meaning: item.meaning || item.trans || item.definition || '暂无释义',
            example: item.example || '',
            proficiency: 0,
            repetition: 0,  // 新增
            interval: 0,    // 新增
            easeFactor: 2.5,// 新增
            lastReviewTime: 0,
            nextReviewTime: 0
          });
        }
      });

      if (wordList.length > 0) {
        return await DatabaseManager.getInstance().batchInsertWords(wordList);
      }
      return 0;

    } catch (e) {
      return -1;
    }
  }
}