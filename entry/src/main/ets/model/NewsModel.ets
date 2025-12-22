export interface NewsItem {
  id: string;          // 唯一标识
  title: string;       // 标题
  description: string; // 列表用的摘要
  content: string;     // [新增] 阅读器用的完整正文 (HTML格式)
  source: string;      // 来源
  picUrl: string;      // 封面图
  date: string;        // 发布时间
  url: string;         // 原文链接
}