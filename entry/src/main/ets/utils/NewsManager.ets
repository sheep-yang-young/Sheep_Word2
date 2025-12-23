import { http } from '@kit.NetworkKit';
import { NewsItem } from '../model/NewsModel';

// 服务器原始数据接口
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
  // 你的后端地址
  private static readonly API_URL = 'http://8.134.10.55:3000/api/news/today';

  static async getDailyNews(): Promise<NewsItem[]> {
    const httpRequest = http.createHttp();

    try {
      // 添加时间戳防止缓存，确保每次下拉刷新都能拿到最新内容
      const timestamp = new Date().getTime();
      const finalUrl = `${NewsManager.API_URL}?t=${timestamp}`;

      const response = await httpRequest.request(finalUrl, {
        method: http.RequestMethod.GET,
        readTimeout: 15000, // 适当延长超时时间
        connectTimeout: 15000,
        expectDataType: http.HttpDataType.STRING
      });

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as ServerResponse;

        if (!result || !result.news) {
          return [];
        }

        const serverNews: ServerNewsItem[] = result.news;

        return serverNews.map((item: ServerNewsItem): NewsItem => {
          // 健壮性处理：如果字段缺失，提供默认值
          const cleanTitle = item.title ? item.title.trim() : "无标题";
          const cleanDesc = item.description ? item.description.trim() : "";
          // 优先使用 content，如果没有则使用 description，最后使用占位符
          const cleanContent = (item.content && item.content.length > 50)
            ? item.content
            : (cleanDesc || "<p>暂无详细正文内容，请阅读标题摘要。</p>");

          return {
            id: item.id || Math.random().toString(36).substring(7),
            title: cleanTitle,
            description: cleanDesc || "暂无描述",
            content: cleanContent,
            source: item.source || 'Daily News',
            picUrl: item.picUrl || "",
            date: item.date || new Date().toISOString().split('T')[0],
            url: item.url
          } as NewsItem;
        });
      } else {
        console.error(`[NewsManager] HTTP Error: ${response.responseCode}`);
      }
    } catch (e) {
      console.error(`[NewsManager] Request Failed: ${JSON.stringify(e)}`);
    } finally {
      // 务必销毁请求实例，防止内存泄漏
      httpRequest.destroy();
    }
    return [];
  }
}