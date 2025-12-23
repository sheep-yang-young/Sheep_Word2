import { NewsItem } from '../model/NewsModel';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';

interface LocalArticleData {
  articles: NewsItem[];
}

export class ArticleManager {
  /**
   * 从 RawFile 读取本地经典文章
   * [修复] 增加 context 参数，避免使用 this
   */
  static async getClassicArticles(context: common.UIAbilityContext): Promise<NewsItem[]> {
    try {
      // 读取 rawfile/classic_articles.json
      const fileData = await context.resourceManager.getRawFileContent('classic_articles.json');

      // [修复] TextDecoderOptions 需要显式类型或直接传参（ArkTS严格模式）
      // 这里直接使用默认创建，忽略 BOM 选项通常默认即可，或者显式定义
      const textDecoder = util.TextDecoder.create('utf-8');
      const jsonString = textDecoder.decodeWithStream(fileData);

      const result = JSON.parse(jsonString) as LocalArticleData;

      if (result && result.articles) {
        return result.articles.map((item: NewsItem): NewsItem => {
          // [修复] ArkTS 不支持 ...item 对象展开，必须手动赋值
          return {
            id: item.id,
            title: item.title,
            description: item.description,
            content: item.content,
            source: item.source || 'Classic',
            picUrl: '',
            date: item.date,
            url: ''
          } as NewsItem;
        });
      }
    } catch (e) {
      console.error(`[ArticleManager] Read local file failed: ${JSON.stringify(e)}`);
    }
    return [];
  }
}