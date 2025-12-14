import { DatabaseManager } from '../utils/DatabaseManager';
import { PreferenceManager } from '../utils/PreferenceManager';
import { Word } from '../model/WordModel';

interface CardItem { id: number; text: string; type: 'word' | 'def'; matched: boolean; }

@Component
export struct MatchPairsPage {
  @Consume('pageStack') pageStack: NavPathStack;
  @State cards: CardItem[] = [];
  @State selectedIdx: number = -1;

  async aboutToAppear() {
    const book = await PreferenceManager.getInstance().getCurrentBook();
    const words = await DatabaseManager.getInstance().getRandomWords(book, 6);
    let temp: CardItem[] = [];
    words.forEach((w, i) => {
      temp.push({ id: i, text: w.spelling, type: 'word', matched: false });
      temp.push({ id: i, text: w.meaning, type: 'def', matched: false });
    });
    this.cards = temp.sort(() => Math.random() - 0.5);
  }

  handleTap(index: number) {
    if (this.cards[index].matched) return;
    if (this.selectedIdx === -1) { this.selectedIdx = index; } else {
      const first = this.cards[this.selectedIdx];
      const second = this.cards[index];
      if (first.id === second.id && first.type !== second.type) {
        this.cards[this.selectedIdx].matched = true;
        this.cards[index].matched = true;
      }
      this.selectedIdx = -1;
    }
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Button({ type: ButtonType.Circle }) { SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(24).fontColor([Color.Black]) }
          .backgroundColor(Color.Transparent).width(48).height(48).onClick(() => this.pageStack.pop())
          Text('配对消消乐').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 4 })
        }.width('100%').padding({ top: 56, left: 16, right: 16, bottom: 10 }).alignItems(VerticalAlign.Center)

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(this.cards, (item: CardItem, index: number) => {
            Button(item.text)
              .width('48%').height(80).margin({ bottom: 10 })
              .backgroundColor(item.matched ? '#F0F0F0' : (this.selectedIdx === index ? '#E6F7FF' : Color.White))
              .fontColor(item.matched ? '#CCC' : '#333')
              .border({ width: 1, color: this.selectedIdx === index ? '#0A59F7' : 'transparent' })
              .onClick(() => this.handleTap(index))
          })
        }.padding(16)
      }.height('100%').backgroundColor('#F5F7FA')
    }.hideTitleBar(true)
  }
}