import { DatabaseManager } from '../utils/DatabaseManager';
import { PreferenceManager } from '../utils/PreferenceManager';
import { Word } from '../model/WordModel';
import { CleanCard } from '../components/CustomComponents';

interface PairCard {
  key: string;
  text: string;
  type: 'word' | 'meaning';
  matched: boolean;
}

@Component
export struct MatchPairsPage {
  @Consume('pageStack') pageStack: NavPathStack;

  @State words: Word[] = [];
  @State cards: PairCard[] = [];
  @State selectedIndex: number = -1;
  @State feedback: string = '';
  @State cleared: number = 0;

  async aboutToAppear(): Promise<void> {
    await this.loadWords();
    this.prepareCards();
  }

  async loadWords(): Promise<void> {
    const book = await PreferenceManager.getInstance().getCurrentBook();
    this.words = await DatabaseManager.getInstance().getRandomWords(book, 8);
  }

  prepareCards(): void {
    const temp: PairCard[] = [];
    this.words.forEach((w) => {
      temp.push({ key: w.spelling, text: w.spelling, type: 'word', matched: false });
      temp.push({ key: w.spelling, text: w.meaning, type: 'meaning', matched: false });
    });
    this.cards = temp.sort(() => Math.random() - 0.5);
    this.selectedIndex = -1;
    this.feedback = '';
    this.cleared = 0;
  }

  async updateWordProgress(word: Word, correct: boolean): Promise<void> {
    if (!word.id) return;
    const newInterval = correct ? Math.min(word.interval + 1, 18) : 1;
    const newRepetition = correct ? word.repetition + 1 : Math.max(0, word.repetition - 1);
    const newEase = Math.max(1.3, correct ? word.easeFactor + 0.05 : word.easeFactor - 0.1);
    await DatabaseManager.getInstance().updateWordStats(word.id, newInterval, newRepetition, newEase);
    await DatabaseManager.getInstance().logActivity();
  }

  handleSelect(index: number): void {
    if (this.cards[index].matched) return;
    if (this.selectedIndex === -1) {
      this.selectedIndex = index;
      this.feedback = '';
      return;
    }

    const first = this.cards[this.selectedIndex];
    const second = this.cards[index];

    if (first.key === second.key && first.type !== second.type) {
      this.cards[this.selectedIndex].matched = true;
      this.cards[index].matched = true;
      this.cleared += 2;
      this.feedback = '配对成功！';
      const word = this.words.find((w) => w.spelling === first.key);
      if (word) this.updateWordProgress(word, true);
    } else {
      this.feedback = '未匹配，再试一次';
      const word = this.words.find((w) => w.spelling === first.key || w.spelling === second.key);
      if (word) this.updateWordProgress(word, false);
    }
    this.selectedIndex = -1;
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(20).fontColor(['#1A1A1A']) }
          .backgroundColor('#F5F5F5').onClick(() => { this.pageStack.pop(); })
        Text('配对消消乐').fontSize(22).fontWeight(FontWeight.Bold).fontColor('#1A1A1A').margin({ left: 12 })
        Blank().layoutWeight(1)
        Text(`${this.cleared}/${this.cards.length} 已配对`).fontSize(14).fontColor('#0A59F7')
      }
      .padding({ top: 20, left: 16, right: 16 })

      if (this.cards.length === 0) {
        Text('暂无题目').fontSize(14).fontColor('#666').padding(16)
      } else {
        Column({ space: 14 }) {
          CleanCard() {
            Column({ space: 10 }) {
              Text('点击匹配单词与释义').fontSize(14).fontColor('#666')
              Text(this.feedback).fontSize(14).fontColor(this.feedback.includes('成功') ? '#52C41A' : '#FA8C16')

              Flex({ wrap: FlexWrap.Wrap, spacing: 10 }) {
                ForEach(this.cards, (card: PairCard, index: number) => {
                  const isActive = this.selectedIndex === index;
                  Text(card.text)
                    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                    .backgroundColor(card.matched ? '#F6FFED' : isActive ? '#E6F7FF' : '#F0F2F5')
                    .fontColor(card.type === 'word' ? '#0A59F7' : '#722ED1')
                    .borderRadius(12)
                    .onClick(() => this.handleSelect(index))
                })
              }

              if (this.cleared === this.cards.length && this.cards.length > 0) {
                Text('全部配对完成！').fontSize(14).fontColor('#52C41A')
              }
            }
          }
        }
        .padding(16)
      }
    }
    .backgroundColor('#F5F7FA')
    .height('100%')
    .width('100%')
  }
}
