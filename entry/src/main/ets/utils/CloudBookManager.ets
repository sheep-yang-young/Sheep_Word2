import { http } from '@kit.NetworkKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

export interface CloudBook {
  id: string;
  name: string;
  category: 'English' | 'Code';
  size: string;
  desc: string;
  version: number;
}

export class CloudBookManager {
  private static readonly BASE_URL = 'http://8.134.10.55:3000';

  /**
   * 1. 获取服务器书单列表 (带防缓存)
   */
  static async getManifest(): Promise<CloudBook[]> {
    // [关键修复] 同样加上时间戳
    const url = `${CloudBookManager.BASE_URL}/api/store/manifest?t=${new Date().getTime()}`;
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
   * 2. 下载书籍 JSON 文件
   */
  static async downloadBook(category: string, fileName: string, context: common.UIAbilityContext): Promise<string | null> {
    // 下载文件通常很大，且文件名固定，一般不需要加时间戳，利用缓存反而更好
    const downloadUrl = `${CloudBookManager.BASE_URL}/static/books/${category.toLowerCase()}/${fileName}.json`;
    const req = http.createHttp();

    try {
      console.info(`[CloudStore] Downloading: ${downloadUrl}`);
      const resp = await req.request(downloadUrl, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING
      });

      if (resp.responseCode === 200) {
        const jsonContent = resp.result as string;
        const tempDir = context.tempDir;
        const filePath = `${tempDir}/${fileName}.json`;

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