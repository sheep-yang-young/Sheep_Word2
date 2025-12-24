import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { textRecognition } from '@kit.CoreVisionKit'; // 鸿蒙端侧 OCR
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit'; // 相册选择器
import { fileIo } from '@kit.CoreFileKit';
import { DatabaseManager } from './DatabaseManager';
import { Word } from '../model/WordModel';

export class FloatingCapsuleManager {
  private static instance: FloatingCapsuleManager;
  private floatWin: window.Window | null = null;
  private context: common.UIAbilityContext | null = null;
  private isProcessing: boolean = false;

  private constructor() {}

  public static getInstance(): FloatingCapsuleManager {
    if (!FloatingCapsuleManager.instance) {
      FloatingCapsuleManager.instance = new FloatingCapsuleManager();
    }
    return FloatingCapsuleManager.instance;
  }

  /**
   * 显示悬浮胶囊
   * 注意：需要 ohos.permission.SYSTEM_FLOAT_WINDOW 权限
   */
  async showCapsule(context: common.UIAbilityContext) {
    this.context = context;
    if (this.floatWin) return;

    try {
      const windowConfig: window.Configuration = {
        name: "LuminaCapsule",
        windowType: window.WindowType.TYPE_FLOAT, // 系统悬浮窗
        ctx: context
      };

      this.floatWin = await window.createWindow(windowConfig);

      // 设置悬浮窗大小和初始位置
      await this.floatWin.resize(140, 50);
      await this.floatWin.moveWindowTo(600, 300);

      // 背景透明，配合 UI 圆角
      await this.floatWin.setWindowBackgroundColor('#00000000');

      // 加载 UI 页面
      await this.floatWin.setUIContent('pages/CapsulePage');
      await this.floatWin.showWindow();

    } catch (e) {
      console.error('[Capsule] Show failed:', JSON.stringify(e));
    }
  }

  /**
   * 关闭悬浮胶囊
   */
  async closeCapsule() {
    if (this.floatWin) {
      await this.floatWin.destroyWindow();
      this.floatWin = null;
    }
  }

  /**
   * 核心功能：调用相册选图 -> OCR 识别 -> 导入数据库
   */
  async triggerImageImport(): Promise<number> {
    if (this.isProcessing || !this.context) return 0;
    this.isProcessing = true;
    let addedCount = 0;

    try {
      // 1. 拉起系统相册选择器
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const result = await photoPicker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });

      if (!result.photoUris || result.photoUris.length === 0) {
        this.isProcessing = false;
        return 0; // 用户取消
      }

      const uri = result.photoUris[0];
      console.info(`[Capsule] Selected image: ${uri}`);

      // 2. 读取图片并转换为 PixelMap
      const file = await fileIo.open(uri, fileIo.OpenMode.READ_ONLY);
      const imageSource = image.createImageSource(file.fd);
      const pixelMap = await imageSource.createPixelMap();

      // 3. 端侧 OCR 识别
      const visionInfo: textRecognition.VisionInfo = { pixelMap: pixelMap };
      const textResult = await textRecognition.recognizeText(visionInfo);
      const fullText = textResult.value;

      // 释放资源
      await imageSource.release();
      await pixelMap.release();
      fileIo.closeSync(file);

      // 4. 简单的文本清洗 (提取长度大于2的纯字母单词)
      const rawWords = fullText.split(/[^a-zA-Z]/).filter(w => w.length > 2);
      const uniqueWords = Array.from(new Set(rawWords));

      // 5. 查库与组装数据
      const wordsToAdd: Word[] = [];
      const targetBookId = "Captured_Words"; // 导入到专门的“截图导入”词书

      for (const spelling of uniqueWords) {
        // 在本地全库查找释义 (利用之前加的全局查词功能)
        const existWord = await DatabaseManager.getInstance().findWordGlobal(spelling);

        let meaning = "";
        let phonetic = "";

        if (existWord) {
          meaning = existWord.meaning;
          phonetic = existWord.phonetic || "";
        } else {
          meaning = ""; // 本地查不到就留空
        }

        wordsToAdd.push({
          bookId: targetBookId,
          spelling: spelling,
          phonetic: phonetic,
          meaning: meaning,
          proficiency: 0, repetition: 0, interval: 0, easeFactor: 2.5, lastReviewTime: 0, nextReviewTime: 0
        });
      }

      // 6. 批量存入数据库
      if (wordsToAdd.length > 0) {
        addedCount = await DatabaseManager.getInstance().batchInsertWords(targetBookId, wordsToAdd);
        console.info(`[Capsule] Imported ${addedCount} words into ${targetBookId}`);
      }

    } catch (e) {
      console.error('[Capsule] Import failed:', JSON.stringify(e));
    } finally {
      this.isProcessing = false;
    }
    return addedCount;
  }
}