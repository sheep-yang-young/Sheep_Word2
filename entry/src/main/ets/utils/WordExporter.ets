import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { DatabaseManager } from './DatabaseManager';

export class WordExporter {
  static async exportData(context: common.UIAbilityContext, bookId: string): Promise<boolean> {
    try {
      const allWords = await DatabaseManager.getInstance().searchWords(bookId, '');
      if (allWords.length === 0) return false;
      const jsonStr = JSON.stringify(allWords, null, 2);
      const opt = new picker.DocumentSaveOptions();
      opt.newFileNames = [`Lumina_${bookId}_Backup.json`];
      opt.fileSuffixChoices = ['.json'];
      const view = new picker.DocumentViewPicker(context);
      const uris = await view.save(opt);
      if (uris.length > 0) {
        const f = fs.openSync(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        fs.writeSync(f.fd, jsonStr);
        fs.closeSync(f);
        return true;
      }
      return false;
    } catch (e) { return false; }
  }
}