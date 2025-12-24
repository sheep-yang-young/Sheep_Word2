import { FormExtensionAbility, formBindingData, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { DatabaseManager } from '../utils/DatabaseManager';
import { PreferenceManager } from '../utils/PreferenceManager';
import { Word } from '../model/WordModel';

export default class EntryFormAbility extends FormExtensionAbility {

  // 1. 必须同步返回，不能加 async
  onAddForm(want: Want) {
    // 准备一个临时的默认数据，确保卡片立即显示出来
    const initialData: Record<string, string> = {
      'spelling': 'Lumina',
      'phonetic': '',
      'meaning': 'Loading...'
    };
    const formData = formBindingData.createFormBindingData(initialData);

    // 2. 获取 formId
    // 注意：不同版本 key 可能不同，这里尝试获取标准的 IDENTITY_KEY
    const formId = want.parameters?.[formInfo.FormParam.IDENTITY_KEY] as string;

    // 3. 启动异步任务去查库并更新
    if (formId) {
      this.updateCardInBackground(formId);
    }

    // 4. 立即返回
    return formData;
  }

  onUpdateForm(formId: string) {
    // 定时更新
    this.updateCardInBackground(formId);
  }

  // 异步查词并更新 UI
  async updateCardInBackground(formId: string) {
    try {
      // 确保初始化
      await PreferenceManager.getInstance().init(this.context);
      await DatabaseManager.getInstance().init(this.context);

      const currentBook = await PreferenceManager.getInstance().getCurrentBook();
      const words: Word[] = await DatabaseManager.getInstance().getRandomWords(currentBook, 1);

      let updateData: Record<string, string>;
      if (words.length > 0) {
        const w = words[0];
        updateData = {
          'spelling': w.spelling,
          'phonetic': w.phonetic || '',
          'meaning': w.meaning
        };
      } else {
        updateData = {
          'spelling': 'Relax',
          'phonetic': '',
          'meaning': 'No words found'
        };
      }

      // 使用 formProvider 更新，比 this.context.updateForm 更稳健
      const bindingData = formBindingData.createFormBindingData(updateData);
      await formProvider.updateForm(formId, bindingData);

    } catch (e) {
      console.error('[EntryFormAbility] Background update failed:', JSON.stringify(e));
    }
  }
};