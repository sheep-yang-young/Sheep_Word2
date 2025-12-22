import { http } from '@kit.NetworkKit';
import { NewsItem } from '../model/NewsModel';

// 定义服务器返回的 JSON 结构
interface ServerNewsItem {
  id: string;
  title: string;
  description: string;
  content?: string;
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
  // 你的真实服务器 IP
  private static readonly API_URL = 'http://8.134.10.55:3000/api/news/today';

  static async getDailyNews(): Promise<NewsItem[]> {
    const httpRequest = http.createHttp();

    try {
      // [核心修复] 添加时间戳 ?t=...
      // 就像给快递单号加了唯一的秒数，让系统认为这是一个全新的请求，绝对不读缓存
      const timestamp = new Date().getTime();
      const finalUrl = `${NewsManager.API_URL}?t=${timestamp}`;

      console.info(`[NewsManager] Requesting fresh data: ${finalUrl}`);

      const response = await httpRequest.request(finalUrl, {
        method: http.RequestMethod.GET,
        readTimeout: 10000,
        connectTimeout: 10000,
        expectDataType: http.HttpDataType.STRING
      });

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as ServerResponse;
        const serverNews: ServerNewsItem[] = result.news;

        console.info(`[NewsManager] Fetched ${serverNews.length} items from server`);

        const mappedNews: NewsItem[] = serverNews.map((item: ServerNewsItem): NewsItem => {
          return {
            id: item.id || Math.random().toString(),
            title: item.title ? item.title.trim() : "无标题",
            description: item.description ? item.description.trim() : "暂无描述",

            // 👇👇👇【核心修复】👇👇👇
            // 如果服务器没返回 content，就用 description 兜底，防止白屏
            content: item.content || item.description || "<p>暂无正文内容</p>",

            source: item.source || 'CGTN',
            picUrl: item.picUrl || "",
            date: item.date,
            url: item.url
          } as NewsItem;
        });

        return mappedNews;
      } else {
        console.error(`[NewsManager] HTTP Error: ${response.responseCode}`);
      }
    } catch (e) {
      console.error(`[NewsManager] Request Failed: ${JSON.stringify(e)}`);
    } finally {
      httpRequest.destroy();
    }
    return [];
  }
}