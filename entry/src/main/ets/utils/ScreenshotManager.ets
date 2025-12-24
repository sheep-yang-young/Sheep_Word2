import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import hilog from '@ohos.hilog';
import screenshot from '@ohos.screenshot';
import { BusinessError } from '@kit.BasicServicesKit';
import { PreferenceManager } from './PreferenceManager';

const DOMAIN: number = 0xA0A03D;
const TAG: string = 'ScreenshotMgr';

export interface SavedScreenshotInfo {
  path: string;
  createdAt: number;
}

export class ScreenshotManager {
  private static instance: ScreenshotManager = new ScreenshotManager();
  private ctx: common.UIAbilityContext | null = null;

  static getInstance(): ScreenshotManager {
    return ScreenshotManager.instance;
  }

  init(context: common.UIAbilityContext): void {
    this.ctx = context;
  }

  async captureAndStore(): Promise<SavedScreenshotInfo | null> {
    if (!this.ctx) {
      hilog.error(DOMAIN, TAG, 'captureAndStore aborted: context missing');
      return null;
    }

    try {
      await PreferenceManager.getInstance().init(this.ctx);
      const dir = `${this.ctx.filesDir}/screenshots`;
      await this.ensureDir(dir);
      const targetPath = `${dir}/shot_${Date.now()}.png`;

      // 调用系统截图能力
      const shot: any = screenshot as any;
      const options: any = {
        imageType: shot?.ImageType?.PNG ?? 0,
        quality: 100,
        filePath: targetPath
      };

      let savedPath: string | null = null;
      if (shot?.save) {
        const res: any = await shot.save(options);
        savedPath = res?.uri ?? res?.filePath ?? res?.path ?? targetPath;
      } else if (shot?.capture) {
        const res: any = await shot.capture(options);
        savedPath = res?.uri ?? res?.filePath ?? res?.path ?? targetPath;
      }

      if (!savedPath) savedPath = targetPath;

      const record = { path: savedPath, createdAt: Date.now() } as SavedScreenshotInfo;
      await PreferenceManager.getInstance().addCapturedScreenshot(record);
      hilog.info(DOMAIN, TAG, 'screenshot saved at %{public}s', savedPath);
      return record;
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'captureAndStore failed %{public}s', JSON.stringify(error));
      return null;
    }
  }

  async getAll(): Promise<SavedScreenshotInfo[]> {
    if (this.ctx) await PreferenceManager.getInstance().init(this.ctx);
    return await PreferenceManager.getInstance().getCapturedScreenshots();
  }

  async remove(path: string): Promise<void> {
    if (!this.ctx) return;
    await PreferenceManager.getInstance().init(this.ctx);
    try {
      await PreferenceManager.getInstance().removeCapturedScreenshot(path);
      try { fileIo.unlinkSync(path); } catch (e) {}
    } catch (err) {
      const error = err as BusinessError;
      hilog.warn(DOMAIN, TAG, 'remove screenshot warn %{public}s', JSON.stringify(error));
    }
  }

  private async ensureDir(dir: string): Promise<void> {
    try {
      const stat = fileIo.statSync(dir);
      if (!stat?.isDirectory()) {
        fileIo.mkdirSync(dir);
      }
    } catch (e) {
      try { fileIo.mkdirSync(dir); } catch (e2) {}
    }
  }
}
