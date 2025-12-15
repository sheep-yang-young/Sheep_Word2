import { http } from '@kit.NetworkKit';
import { NewsItem } from '../model/NewsModel';

export class NewsManager {
  // China Daily 国际版 RSS
  private static readonly RSS_URL = 'https://www.chinadaily.com.cn/rss/world_rss.xml';

  static async getDailyNews(): Promise<NewsItem[]> {
    const httpRequest = http.createHttp();

    try {
      const response = await httpRequest.request(NewsManager.RSS_URL, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        },
        expectDataType: http.HttpDataType.STRING,
        readTimeout: 15000,
        connectTimeout: 15000
      });

      console.info(`[NewsManager] Response Code: ${response.responseCode}`);

      if (response.responseCode === 200) {
        let xmlContent = response.result as string;
        const items = NewsManager.parseRSS(xmlContent);
        console.info(`[NewsManager] Parsed items count: ${items.length}`);
        return items;
      } else {
        console.error(`[NewsManager] HTTP Error: ${response.responseCode}`);
      }
    } catch (e) {
      console.error('[NewsManager] Network Request Failed:', JSON.stringify(e));
    } finally {
      httpRequest.destroy();
    }
    return [];
  }

  // 使用字符串 Split 方式解析，最稳定，不容易受正则影响
  private static parseRSS(xml: string): NewsItem[] {
    const items: NewsItem[] = [];

    // 1. 根据 <item> 标签拆分字符串
    // 使用正则 split 兼容 <item> 和 <item >
    const parts = xml.split(/<item[^>]*>/i);

    // 从索引 1 开始，因为索引 0 是 RSS 头部信息
    for (let i = 1; i < parts.length; i++) {
      let content = parts[i];

      // 截取到 </item> 结束
      const closeIndex = content.search(/<\/item>/i);
      if (closeIndex !== -1) {
        content = content.substring(0, closeIndex);
      }

      // 2. 提取各个字段
      const title = NewsManager.extractTag(content, 'title');
      let description = NewsManager.extractTag(content, 'description');
      const dateStr = NewsManager.extractTag(content, 'pubDate');
      const url = NewsManager.extractTag(content, 'link');

      // 3. 提取图片 (China Daily 特殊逻辑)
      let picUrl = NewsManager.extractTag(content, 'imgSrc'); // 部分 RSS 有此标签

      // 如果没有 imgSrc 标签，尝试从 description 中提取 <img src="...">
      if (!picUrl) {
        // 匹配 src="http..." 或 src='http...'
        const imgMatch = /src=["'](.*?)["']/i.exec(description);
        if (imgMatch) {
          picUrl = imgMatch[1];
        }
      }

      // 4. 清洗 description (去除 HTML 标签，去除图片代码)
      // 先去除 CDATA (extractTag 已做)，再去除 HTML
      description = description.replace(/<[^>]+>/g, '').trim();
      // 去除多余的空白符
      description = description.replace(/\s+/g, ' ');
      // 截断过长文本
      if (description.length > 200) {
        description = description.substring(0, 200) + '...';
      }

      // 5. 修复图片链接 https
      if (picUrl && picUrl.startsWith('http://')) {
        picUrl = picUrl.replace('http://', 'https://');
      }

      // 6. 只有标题有效才添加
      if (title && title.length > 0) {
        items.push({
          id: url || Math.random().toString(),
          title: title,
          description: description || 'No description available', // 确保不为 null
          source: 'China Daily',
          picUrl: picUrl,
          date: NewsManager.formatDate(dateStr),
          url: url
        });
      }

      if (items.length >= 20) break;
    }

    return items;
  }

  // --- 辅助方法：提取标签内容并清洗 ---
  private static extractTag(content: string, tagName: string): string {
    // 构造开始标签正则，兼容 <title> 和 <title >
    // 寻找开始标签的位置
    const startRegex = new RegExp(`<${tagName}[^>]*>`, 'i');
    const startMatch = startRegex.exec(content);

    if (!startMatch) return '';

    const startIndex = startMatch.index + startMatch[0].length;

    // 寻找结束标签的位置
    const endRegex = new RegExp(`<\/${tagName}>`, 'i');
    const endMatch = endRegex.exec(content.substring(startIndex));

    if (!endMatch) return '';

    const endIndex = startIndex + endMatch.index;

    let rawValue = content.substring(startIndex, endIndex);

    // 清洗 CDATA: <![CDATA[ ... ]]>
    if (rawValue.includes('<![CDATA[')) {
      rawValue = rawValue.replace(/<!\[CDATA\[/g, '').replace(/\]\]>/g, '');
    }

    return rawValue.trim();
  }

  private static formatDate(dateStr: string): string {
    if (!dateStr) return '';
    try {
      const date = new Date(dateStr);
      const m = (date.getMonth() + 1).toString().padStart(2, '0');
      const d = date.getDate().toString().padStart(2, '0');
      return `${m}-${d}`;
    } catch (e) {
      return dateStr;
    }
  }
}