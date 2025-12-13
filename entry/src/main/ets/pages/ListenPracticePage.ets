import { fetchReviewWords, commitReviewResult } from '../utils/ReviewSessionHelper';
import { Word } from '../model/WordModel';
import { ReviewGrade } from '../utils/Sm2Algorithm';
import { PreferenceManager } from '../utils/PreferenceManager';
import { CleanCard } from '../components/CustomComponents';
import { media } from '@kit.MediaKit';
import { vibrator } from '@kit.SensorServiceKit';

@Component
export struct ListenPracticePage {
  @Consume('pageStack') pageStack: NavPathStack;
  @Consume refreshFlag: number;

  @State words: Word[] = [];
  @State currentIndex: number = 0;
  @State isLoading: boolean = true;
  @State isFinished: boolean = false;

  @State userInput: string = '';
  @State isChecked: boolean = false;
  @State isCorrect: boolean | null = null;
  @State hintText: string = '';

  private avPlayer: media.AVPlayer | null = null;
  private accentType: number = 2;
  private ttsSpeed: number = 1.0;
  private isHapticOn: boolean = true;
  private currentBookId: string = 'Default Library';

  async aboutToAppear(): Promise<void> {
    await this.initAudioPlayer();
    const prefs = PreferenceManager.getInstance();
    const limit = await prefs.getDailyLimit();
    this.accentType = await prefs.getAccentType();
    this.ttsSpeed = await prefs.getTtsSpeed();
    this.isHapticOn = await prefs.isHapticEnabled();
    this.currentBookId = await prefs.getCurrentBook();

    this.words = await fetchReviewWords(this.currentBookId, limit);
    this.isLoading = false;

    if (this.words.length === 0) {
      this.isFinished = true;
    } else {
      this.loadCurrentWord();
    }
  }

  aboutToDisappear(): void {
    if (this.avPlayer) this.avPlayer.release();
    this.refreshFlag++;
  }

  async initAudioPlayer(): Promise<void> { try { this.avPlayer = await media.createAVPlayer(); } catch (e) {} }

  async playWord(text: string): Promise<void> {
    if (!this.avPlayer) return;
    try {
      await this.avPlayer.reset();
      this.avPlayer.url = `https://dict.youdao.com/dictvoice?audio=${text}&type=${this.accentType}`;
      this.avPlayer.on('stateChange', async (state: string) => {
        if (state === 'initialized') await this.avPlayer?.prepare();
        else if (state === 'prepared') { await this.avPlayer?.setSpeed(this.ttsSpeed); await this.avPlayer?.play(); }
      });
    } catch (e) {}
  }

  generateHint(word: string): void {
    if (!word) { this.hintText = ''; return; }
    const cleanWord = word.trim();
    const len = cleanWord.length;
    if (len <= 2) { this.hintText = '_ '.repeat(len); return; }
    const revealCount = Math.ceil(len / 3);
    const indices = new Set<number>();
    while (indices.size < revealCount) indices.add(Math.floor(Math.random() * len));
    let hint = '';
    for (let i = 0; i < len; i++) { if (indices.has(i)) hint += cleanWord[i] + ' '; else hint += '_ '; }
    this.hintText = hint.trim();
  }

  loadCurrentWord(): void {
    if (this.currentIndex < this.words.length) {
      this.userInput = '';
      this.isChecked = false;
      this.isCorrect = null;
      this.generateHint(this.words[this.currentIndex].spelling);
      this.playWord(this.words[this.currentIndex].spelling);
    }
  }

  triggerHaptic(grade: ReviewGrade): void { if (!this.isHapticOn) return; try { let duration = 30; if (grade === ReviewGrade.AGAIN) duration = 80; vibrator.startVibration({ type: 'time', duration: duration }, { id: 0, usage: 'touch' }); } catch (e) {} }

  checkSpelling(): void {
    const correct = this.words[this.currentIndex].spelling.trim().toLowerCase();
    const input = this.userInput.trim().toLowerCase();
    this.isCorrect = input === correct;
    this.isChecked = true;
    if (this.isCorrect) {
      this.triggerHaptic(ReviewGrade.EASY);
      this.playWord(this.words[this.currentIndex].spelling);
    } else {
      this.triggerHaptic(ReviewGrade.AGAIN);
    }
  }

  goBack(): void { this.refreshFlag++; this.pageStack.pop(); }

  async submitReview(grade: ReviewGrade): Promise<void> {
    this.triggerHaptic(grade);
    const currentWord = this.words[this.currentIndex];
    await commitReviewResult(currentWord, grade);

    if (this.currentIndex < this.words.length - 1) {
      this.currentIndex++;
      this.loadCurrentWord();
    } else {
      this.isFinished = true;
    }
  }

  build() {
    NavDestination() {
      Column() {
        if (this.isLoading) { LoadingProgress().width(50).height(50).color('#0A59F7') }
        else if (this.isFinished) {
          Column({ space: 16 }) { Image($r('sys.media.ohos_ic_public_ok')).width(80).height(80).fillColor('#10B981'); Text('听写完成').fontSize(24).fontWeight(FontWeight.Bold); Button('返回主页').backgroundColor('#F0F2F5').fontColor('#333').onClick(() => { this.goBack() }) }.width('100%').height('100%').justifyContent(FlexAlign.Center)
        } else if (this.words.length > 0) {
          Row() { Image($r('sys.media.ohos_ic_public_arrow_left')).width(24).height(24).fillColor('#333').onClick(() => { this.goBack() }); Blank(); Text('听写模式').fontSize(18).fontWeight(FontWeight.Bold); Blank(); Text(`${this.currentIndex + 1} / ${this.words.length}`).fontColor('#999').fontSize(14) }.width('100%').padding({ left: 20, right: 20, bottom: 10 })

          Progress({ value: this.currentIndex + 1, total: this.words.length, type: ProgressType.Linear }).color('#0A59F7').width('100%').height(4)

          Column({ space: 16 }) {
            CleanCard() {
              Column({ space: 14 }) {
                Text('点击播放发音，输入你听到的单词').fontSize(14).fontColor('#666').width('100%')
                Button({ type: ButtonType.Circle }) { Image($r('sys.media.ohos_ic_public_sound')).width(24).height(24).fillColor('#0A59F7') }
                  .width(64).height(64).backgroundColor('rgba(10, 89, 247, 0.1)').onClick(() => { this.playWord(this.words[this.currentIndex].spelling) })
                Text(this.hintText).fontSize(26).fontWeight(FontWeight.Bold).fontColor('#0A59F7').letterSpacing(2)
                TextInput({ placeholder: '请输入单词', text: this.userInput })
                  .height(56).fontSize(20).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
                  .fontColor(this.isCorrect === false ? '#FF4D4F' : '#1A1A1A')
                  .onChange((val) => { this.userInput = val; this.isChecked = false; this.isCorrect = null; })
                  .onSubmit(() => { this.checkSpelling() })
                Button('检查拼写').backgroundColor('#0A59F7').fontColor(Color.White).height(46).onClick(() => { this.checkSpelling() })

                if (this.isChecked) {
                  Text(this.isCorrect ? '拼写正确！' : `正确答案：${this.words[this.currentIndex].spelling}`)
                    .fontSize(16).fontColor(this.isCorrect ? '#10B981' : '#FF4D4F')
                }
              }.width('100%')
            }

            if (this.isChecked) {
              Row({ space: 12 }) {
                this.ReviewButton('Again', '#FF4D4F', () => { this.submitReview(ReviewGrade.AGAIN) })
                this.ReviewButton('Hard', '#FAAD14', () => { this.submitReview(ReviewGrade.HARD) })
                this.ReviewButton('Good', '#0A59F7', () => { this.submitReview(ReviewGrade.GOOD) })
                this.ReviewButton('Easy', '#10B981', () => { this.submitReview(ReviewGrade.EASY) })
              }.padding({ left: 16, right: 16 })
            }
          }.padding({ left: 20, right: 20, top: 20 }).layoutWeight(1)
        }
      }.width('100%').height('100%').backgroundColor('#F5F7FA').padding({ top: 48 })
    }.hideTitleBar(true)
  }

  @Builder ReviewButton(label: string, color: string, action: () => void) {
    Button(label).layoutWeight(1).height(50).backgroundColor(Color.White).fontColor(color).border({ width: 1, color: color }).fontSize(14).fontWeight(FontWeight.Medium).onClick(action)
  }
}
