import { DatabaseManager } from '../utils/DatabaseManager';
import { Word } from '../model/WordModel';
import { promptAction } from '@kit.ArkUI';

@Component
export struct CustomImportPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @State inputText: string = '';
  @State isProcessing: boolean = false;

  async handleImport() {
    if (!this.inputText.trim()) {
      promptAction.showToast({ message: '请输入内容' });
      return;
    }

    this.isProcessing = true;

    // 简单的正则提取英文单词 (过滤掉短词和数字)
    const rawWords = this.inputText.match(/[a-zA-Z]{2,}/g);

    if (!rawWords || rawWords.length === 0) {
      promptAction.showToast({ message: '未检测到有效单词' });
      this.isProcessing = false;
      return;
    }

    // 去重
    const uniqueWords = Array.from(new Set(rawWords.map(w => w.toLowerCase())));
    const db = DatabaseManager.getInstance();
    let successCount = 0;

    // 存入名为 "自定义导入" 的词书
    const bookName = "User Imports";

    for (const spelling of uniqueWords) {
      // 检查是否已存在（这里简化处理，实际应调用API查询释义，这里仅作为占位）
      // 如果需要真实释义，需要对接API，这里仅存单词
      const word: Word = {
        bookId: bookName,
        spelling: spelling,
        meaning: '点击编辑添加释义', // 默认释义
        proficiency: 0,
        repetition: 0,
        interval: 0,
        easeFactor: 0,
        lastReviewTime: 0,
        nextReviewTime: 0
      };
      // 简单插入，这里假设 DatabaseManager 有 insertWord 方法，或者复用 import 逻辑
      // 由于没有直接的 insert API，我们复用 checkBookExists 的逻辑思路
      // 注意：你需要确保 DatabaseManager 提供了插入单个单词的方法，这里假设有
      // 如果没有，可以调用 addWord(word) (需在DatabaseManager中实现)
      await db.addWord(word);
      successCount++;
    }

    this.isProcessing = false;
    promptAction.showToast({ message: `成功导入 ${successCount} 个单词到 "${bookName}"` });
    this.pageStack.pop();
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Image($r('sys.media.ohos_ic_public_arrow_left')).width(24).height(24).onClick(() => this.pageStack.pop())
          Text('自定义导入').fontSize(18).fontWeight(FontWeight.Bold).margin({ left: 12 })
        }.width('100%').padding(16).backgroundColor(Color.White)

        Column({ space: 20 }) {
          Text('粘贴英文文章或单词列表，系统将自动识别单词：').fontSize(14).fontColor('#666').width('100%')

          TextArea({ placeholder: '在此粘贴文本...', text: this.inputText })
            .height(300)
            .onChange((value) => this.inputText = value)
            .backgroundColor(Color.White)
            .borderRadius(12)
            .padding(12)

          Button(this.isProcessing ? '处理中...' : '开始导入')
            .width('100%')
            .height(50)
            .backgroundColor('#0A59F7')
            .enabled(!this.isProcessing)
            .onClick(() => this.handleImport())
        }
        .padding(20)
      }
      .width('100%').height('100%').backgroundColor('#F5F7FA')
    }.hideTitleBar(true)
  }
}