export interface NewsItem {
  id: string;          // 唯一标识 (使用链接)
  title: string;       // 新闻标题
  description: string; // 新闻摘要/正文
  source: string;      // 来源 (China Daily)
  picUrl: string;      // 配图链接
  date: string;        // 发布时间
  url: string;         // 原文链接
}