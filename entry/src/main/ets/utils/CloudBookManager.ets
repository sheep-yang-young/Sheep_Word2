import { http } from '@kit.NetworkKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

// 定义书单数据的接口 (对应服务器返回的 JSON)
export interface CloudBook {
  id: string;
  name: string;
  category: 'English' | 'Code';
  size: string;
  desc: string;
  version: number;
}

export class CloudBookManager {
  // ⚠️ 记得换成你的服务器 IP
  private static readonly BASE_URL = 'http://8.134.10.55:3000';

  /**
   * 1. 获取服务器书单列表
   */
  static async getManifest(): Promise<CloudBook[]> {
    const url = `${CloudBookManager.BASE_URL}/api/store/manifest`;
    const req = http.createHttp();

    try {
      console.info(`[CloudStore] Fetching manifest: ${url}`);
      const resp = await req.request(url, {
        method: http.RequestMethod.GET,
        readTimeout: 5000,
        expectDataType: http.HttpDataType.STRING
      });

      if (resp.responseCode === 200) {
        return JSON.parse(resp.result as string) as CloudBook[];
      }
    } catch (e) {
      console.error(`[CloudStore] Manifest error: ${JSON.stringify(e)}`);
    } finally {
      req.destroy();
    }
    return [];
  }

  /**
   * 2. 下载书籍 JSON 文件到本地沙箱
   * @param category 分类 (english/code) 对应服务器目录
   * @param fileName 文件名 (如 linux_cmd.json)
   * @param context 上下文
   */
  static async downloadBook(category: string, fileName: string, context: common.UIAbilityContext): Promise<string | null> {
    // 构造下载地址：http://IP:3000/static/books/code/linux_cmd.json
    // 注意：category 需要转小写 (Code -> code)
    const downloadUrl = `${CloudBookManager.BASE_URL}/static/books/${category.toLowerCase()}/${fileName}.json`;
    const req = http.createHttp();

    try {
      console.info(`[CloudStore] Downloading: ${downloadUrl}`);
      // 关键：Stream 模式下载，防止大文件爆内存
      // 但对于 JSON，我们直接拿 String 也行，为了稳妥我们直接由 HTTP 库处理
      const resp = await req.request(downloadUrl, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING // 拿到 JSON 文本
      });

      if (resp.responseCode === 200) {
        const jsonContent = resp.result as string;

        // 写入临时文件
        const tempDir = context.tempDir;
        const filePath = `${tempDir}/${fileName}.json`;

        // 如果文件已存在先删除
        if (fs.accessSync(filePath)) {
          fs.unlinkSync(filePath);
        }

        const file = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        fs.writeSync(file.fd, jsonContent);
        fs.closeSync(file);

        console.info(`[CloudStore] Saved to: ${filePath}`);
        return filePath;
      } else {
        console.error(`[CloudStore] Download failed code: ${resp.responseCode}`);
      }
    } catch (e) {
      console.error(`[CloudStore] Download error: ${JSON.stringify(e)}`);
    } finally {
      req.destroy();
    }
    return null;
  }
}