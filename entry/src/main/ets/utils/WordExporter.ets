import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { DatabaseManager } from './DatabaseManager';
import { Word } from '../model/WordModel';

export class WordExporter {

  static async exportData(context: common.UIAbilityContext): Promise<boolean> {
    try {
      // 1. 从数据库获取所有单词（不分页，查全量）
      // 我们复用 searchWords 查所有
      const allWords = await DatabaseManager.getInstance().searchWords('');

      if (allWords.length === 0) return false;

      // 2. 转换为 JSON 字符串
      const jsonStr = JSON.stringify(allWords, null, 2);

      // 3. 创建文件保存选项
      const documentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.newFileNames = [`Lumina_Backup_${new Date().getTime()}.json`];
      documentSaveOptions.fileSuffixChoices = ['.json'];

      // 4. 拉起系统保存页面
      const documentViewPicker = new picker.DocumentViewPicker(context);
      const uris = await documentViewPicker.save(documentSaveOptions);

      if (uris.length > 0) {
        // 5. 写入数据
        const uri = uris[0];
        const file = fs.openSync(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        fs.writeSync(file.fd, jsonStr);
        fs.closeSync(file);
        return true;
      }
      return false;

    } catch (e) {
      console.error('[Lumina] Export failed:', e);
      return false;
    }
  }
}