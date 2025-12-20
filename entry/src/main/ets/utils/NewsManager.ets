import { http } from '@kit.NetworkKit';
import { NewsItem } from '../model/NewsModel';

// 1. 定义服务器返回数据的“形状”（接口）
// 这样编译器就知道服务器返回的 JSON 长什么样，不再是模糊的 "any"
interface ServerNewsItem {
  id: string;
  title: string;
  description: string;
  source?: string;
  picUrl?: string;
  date: string;
  url: string;
}

interface ServerResponse {
  date: string;
  news: ServerNewsItem[];
}

export class NewsManager {
  // 你的服务器 IP
  private static readonly API_URL = 'http://8.134.10.55:3000/api/news/today';

  static async getDailyNews(): Promise<NewsItem[]> {
    const httpRequest = http.createHttp();

    try {
      console.info(`[NewsManager] Requesting: ${NewsManager.API_URL}`);

      const response = await httpRequest.request(NewsManager.API_URL, {
        method: http.RequestMethod.GET,
        readTimeout: 10000,
        connectTimeout: 10000,
        expectDataType: http.HttpDataType.STRING
      });

      if (response.responseCode === 200) {
        // ERROR 1 修复: 显式告诉编译器，JSON.parse 出来的结果是 ServerResponse 类型
        // 关键语法: (JSON.parse(...) as ServerResponse)
        const result = JSON.parse(response.result as string) as ServerResponse;

        // ERROR 2 修复: 现在 result.news 已经被识别为 ServerNewsItem[]，不再是 any[]
        const serverNews: ServerNewsItem[] = result.news;

        console.info(`[NewsManager] Fetched ${serverNews.length} items from server`);

        // ERROR 3 & 4 修复:
        // 1. item 参数显式声明类型为 ServerNewsItem
        // 2. 返回值显式声明为 NewsItem，并用 object literal 严格匹配
        const mappedNews: NewsItem[] = serverNews.map((item: ServerNewsItem): NewsItem => {
          return {
            id: item.id || Math.random().toString(),
            title: item.title ? item.title.trim() : "",
            description: item.description ? item.description.trim() : "",
            source: item.source || 'China Daily',
            picUrl: item.picUrl || "",
            date: item.date,
            url: item.url
          } as NewsItem; // 再次强调类型，防止编译器推断错误
        });

        return mappedNews;
      } else {
        console.error(`[NewsManager] HTTP Error: ${response.responseCode}`);
      }
    } catch (e) {
      // 这里的 e 在 catch 块中默认是 unknown，转成 string 打印
      console.error(`[NewsManager] Request Failed: ${JSON.stringify(e)}`);
    } finally {
      httpRequest.destroy();
    }
    return [];
  }
}