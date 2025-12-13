import { fetchReviewWords, commitReviewResult } from '../utils/ReviewSessionHelper';
import { Word } from '../model/WordModel';
import { ReviewGrade } from '../utils/Sm2Algorithm';
import { PreferenceManager } from '../utils/PreferenceManager';
import { CleanCard } from '../components/CustomComponents';
import { vibrator } from '@kit.SensorServiceKit';

@Component
export struct SentencePracticePage {
  @Consume('pageStack') pageStack: NavPathStack;
  @Consume refreshFlag: number;

  @State words: Word[] = [];
  @State currentIndex: number = 0;
  @State isLoading: boolean = true;
  @State isFinished: boolean = false;

  @State promptText: string = '';
  @State meaningText: string = '';
  @State userInput: string = '';
  @State isChecked: boolean = false;
  @State isCorrect: boolean | null = null;

  private isHapticOn: boolean = true;
  private currentBookId: string = 'Default Library';

  async aboutToAppear(): Promise<void> {
    const prefs = PreferenceManager.getInstance();
    const limit = await prefs.getDailyLimit();
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

  aboutToDisappear(): void { this.refreshFlag++; }

  loadCurrentWord(): void {
    if (this.currentIndex < this.words.length) {
      const word = this.words[this.currentIndex];
      this.promptText = this.generatePrompt(word);
      this.meaningText = word.meaning;
      this.userInput = '';
      this.isChecked = false;
      this.isCorrect = null;
    }
  }

  generatePrompt(word: Word): string {
    if (word.example && word.example.length > 0) {
      const masked = word.example.replace(new RegExp(word.spelling, 'gi'), '____');
      return `例句填空：${masked}`;
    }
    return `根据释义填空：${word.meaning}`;
  }

  triggerHaptic(grade: ReviewGrade): void { if (!this.isHapticOn) return; try { let duration = 30; if (grade === ReviewGrade.AGAIN) duration = 80; vibrator.startVibration({ type: 'time', duration: duration }, { id: 0, usage: 'touch' }); } catch (e) {} }

  checkAnswer(): void {
    const correct = this.words[this.currentIndex].spelling.trim().toLowerCase();
    const input = this.userInput.trim().toLowerCase();
    this.isCorrect = input === correct;
    this.isChecked = true;
    this.triggerHaptic(this.isCorrect ? ReviewGrade.GOOD : ReviewGrade.AGAIN);
  }

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

  goBack(): void { this.refreshFlag++; this.pageStack.pop(); }

  build() {
    NavDestination() {
      Column() {
        if (this.isLoading) { LoadingProgress().width(50).height(50).color('#0A59F7') }
        else if (this.isFinished) {
          Column({ space: 16 }) { Image($r('sys.media.ohos_ic_public_ok')).width(80).height(80).fillColor('#10B981'); Text('例句练习完成').fontSize(24).fontWeight(FontWeight.Bold); Button('返回主页').backgroundColor('#F0F2F5').fontColor('#333').onClick(() => { this.goBack() }) }.width('100%').height('100%').justifyContent(FlexAlign.Center)
        } else if (this.words.length > 0) {
          Row() { Image($r('sys.media.ohos_ic_public_arrow_left')).width(24).height(24).fillColor('#333').onClick(() => { this.goBack() }); Blank(); Text('例句练习').fontSize(18).fontWeight(FontWeight.Bold); Blank(); Text(`${this.currentIndex + 1} / ${this.words.length}`).fontColor('#999').fontSize(14) }.width('100%').padding({ left: 20, right: 20, bottom: 10 })

          Progress({ value: this.currentIndex + 1, total: this.words.length, type: ProgressType.Linear }).color('#0A59F7').width('100%').height(4)

          Column({ space: 16 }) {
            CleanCard() {
              Column({ space: 12 }) {
                Text(this.promptText).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
                Text(`释义：${this.meaningText}`).fontSize(14).fontColor('#666').backgroundColor('#F5F7FA').padding(8).borderRadius(8)
                TextInput({ placeholder: '填入缺失的单词', text: this.userInput })
                  .height(56).fontSize(20).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
                  .fontColor(this.isCorrect === false ? '#FF4D4F' : '#1A1A1A')
                  .onChange((val) => { this.userInput = val; this.isChecked = false; this.isCorrect = null; })
                  .onSubmit(() => { this.checkAnswer() })
                Button('检查答案').backgroundColor('#0A59F7').fontColor(Color.White).height(46).onClick(() => { this.checkAnswer() })

                if (this.isChecked) {
                  Column({ space: 8 }) {
                    Text(this.isCorrect ? '回答正确！' : '再接再厉～').fontSize(16).fontColor(this.isCorrect ? '#10B981' : '#FF4D4F')
                    Text(`正确答案：${this.words[this.currentIndex].spelling}`).fontSize(14).fontColor('#333')
                    if (this.words[this.currentIndex].example) Text(this.words[this.currentIndex].example as string).fontSize(14).fontColor('#666')
                  }
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
