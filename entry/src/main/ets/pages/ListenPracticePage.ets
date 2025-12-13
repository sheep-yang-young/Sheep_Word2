import { DatabaseManager } from '../utils/DatabaseManager';
import { Word } from '../model/WordModel';
import { Sm2Algorithm, ReviewGrade } from '../utils/Sm2Algorithm';
import { PreferenceManager } from '../utils/PreferenceManager';
import { media } from '@kit.MediaKit';
import { promptAction } from '@kit.ArkUI';

@Component
export struct ListenPracticePage {
  @Consume('pageStack') pageStack: NavPathStack;
  @Consume refreshFlag: number;

  @State words: Word[] = [];
  @State currentIndex: number = 0;
  @State userInput: string = '';
  @State isCorrect: boolean | null = null;
  @State loading: boolean = true;

  private avPlayer: media.AVPlayer | null = null;
  private accentType: number = 2;
  private ttsSpeed: number = 1.0;
  private currentBookId: string = 'Default Library';

  async aboutToAppear(): Promise<void> {
    await this.initPlayer();
    const prefs = PreferenceManager.getInstance();
    const limit = await prefs.getDailyLimit();
    this.accentType = await prefs.getAccentType();
    this.ttsSpeed = await prefs.getTtsSpeed();
    this.currentBookId = await prefs.getCurrentBook();

    this.words = await DatabaseManager.getInstance().getTodayReviewWords(this.currentBookId, limit);
    if (this.words.length === 0) {
      this.words = await DatabaseManager.getInstance().getRandomWords(this.currentBookId, limit);
    }
    this.loading = false;
  }

  aboutToDisappear(): void { if (this.avPlayer) this.avPlayer.release(); this.refreshFlag++; }

  async initPlayer(): Promise<void> { try { this.avPlayer = await media.createAVPlayer(); } catch (e) {} }

  async playAudio(): Promise<void> {
    if (!this.avPlayer || this.words.length === 0) return;
    const word = this.words[this.currentIndex].spelling;
    try {
      await this.avPlayer.reset();
      this.avPlayer.url = `https://dict.youdao.com/dictvoice?audio=${word}&type=${this.accentType}`;
      this.avPlayer.on('stateChange', async (state: string) => {
        if (state === 'initialized') await this.avPlayer?.prepare();
        else if (state === 'prepared') { await this.avPlayer?.setSpeed(this.ttsSpeed); await this.avPlayer?.play(); }
      });
    } catch (e) {}
  }

  checkAnswer(): void {
    if (this.words.length === 0) return;
    const target = this.words[this.currentIndex].spelling.trim().toLowerCase();
    const input = this.userInput.trim().toLowerCase();
    this.isCorrect = target === input;
    if (this.isCorrect) {
      this.submitResult(ReviewGrade.GOOD);
    }
  }

  async submitResult(grade: ReviewGrade): Promise<void> {
    const currentWord = this.words[this.currentIndex];
    const result = Sm2Algorithm.calculate(currentWord, grade);
    if (currentWord.id !== undefined) {
      await DatabaseManager.getInstance().updateWordStats(currentWord.id, result.interval, result.repetition, result.easeFactor);
      await DatabaseManager.getInstance().logActivity();
    }

    if (this.currentIndex < this.words.length - 1) {
      this.currentIndex++;
      this.userInput = '';
      this.isCorrect = null;
      this.playAudio();
    } else {
      promptAction.showToast({ message: '已完成一轮听写练习' });
      this.pageStack.pop();
      this.refreshFlag++;
    }
  }

  build() {
    NavDestination() {
      Column({ space: 20 }) {
        Row() {
          Image($r('sys.media.ohos_ic_public_arrow_left')).width(24).height(24).fillColor('#1A1A1A').onClick(() => { this.pageStack.pop(); });
          Blank();
          Text('听写练习').fontSize(18).fontWeight(FontWeight.Bold);
          Blank().width(24);
        }.width('100%').padding({ left: 20, right: 20, top: 20 })

        if (this.loading) {
          LoadingProgress().width(50).height(50).color('#0A59F7');
        } else if (this.words.length === 0) {
          Text('当前词书暂无数据').fontSize(16).fontColor('#999').padding(20);
        } else {
          Column({ space: 16 }) {
            Text(`${this.currentIndex + 1} / ${this.words.length}`).fontSize(14).fontColor('#666');
            Button({ type: ButtonType.Circle }) { Image($r('sys.media.ohos_ic_public_sound')).width(26).height(26).fillColor('#0A59F7') }
              .width(64).height(64).backgroundColor('rgba(10, 89, 247, 0.15)').onClick(() => { this.playAudio(); })

            Text('点击喇叭，听写出完整拼写').fontColor('#999').fontSize(14)

            TextInput({ placeholder: '输入你听到的单词', text: this.userInput })
              .height(52).backgroundColor('#F7F9FC').fontSize(18).fontWeight(FontWeight.Bold)
              .onChange((val) => { this.userInput = val; this.isCorrect = null; })
              .onSubmit(() => { this.checkAnswer(); })

            if (this.isCorrect === false) {
              Text(`正确答案：${this.words[this.currentIndex].spelling}`).fontColor('#FF4D4F').fontSize(16)
            }

            Row({ space: 12 }) {
              Button('检查').layoutWeight(1).height(44).backgroundColor('#0A59F7').fontColor(Color.White).onClick(() => { this.checkAnswer(); })
              Button('不会').layoutWeight(1).height(44).backgroundColor('#F0F2F5').fontColor('#666').onClick(() => { this.submitResult(ReviewGrade.AGAIN); })
            }.width('100%')
          }.padding(20).backgroundColor(Color.White).borderRadius(16).margin({ left: 20, right: 20 })
        }
      }
      .width('100%').height('100%').backgroundColor('#F5F7FA')
    }.hideTitleBar(true)
  }
}
