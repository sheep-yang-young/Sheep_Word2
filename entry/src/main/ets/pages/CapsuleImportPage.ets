import { FloatingBallOcrManager, CapsuleWordCandidate } from '../utils/FloatingBallOcrManager';

@Entry
@Component
struct CapsuleImportPage {
  @State bookId: string = '';
  @State items: CapsuleWordCandidate[] = [];
  @State checked: boolean[] = [];
  @State status: string = '';

  aboutToAppear() {
    const res = FloatingBallOcrManager.getInstance().getLastResult();
    if (res) {
      this.bookId = res.suggestedBook || 'Captured_Words';
      this.items = res.words;
      this.checked = res.words.map(() => true);
      this.status = `识别到 ${res.words.length} 个候选`;
    } else {
      this.status = '没有可导入的识别结果（请点击闪控球重试）';
    }
  }

  private selectedItems(): CapsuleWordCandidate[] {
    const out: CapsuleWordCandidate[] = [];
    for (let i = 0; i < this.items.length; i++) {
      if (this.checked[i]) out.push(this.items[i]);
    }
    return out;
  }

  build() {
    Column() {
      Text('闪控球识别导入').fontSize(20).margin({ bottom: 8 })
      Text(this.status).fontSize(14).opacity(0.7).margin({ bottom: 12 })

      Row() {
        Text('词库ID：').fontSize(14)
        TextInput({ text: this.bookId, placeholder: '例如 CET4 / Default Library' })
          .onChange(v => this.bookId = v)
          .layoutWeight(1)
      }.margin({ bottom: 12 })

      List({ space: 8 }) {
        ForEach(this.items, (it: CapsuleWordCandidate, idx: number) => {
          ListItem() {
            Row() {
              Checkbox({ name: `${idx}`, group: 'capsule' })
                .select(this.checked[idx])
                .onChange(v => this.checked[idx] = v)

              Column() {
                Text(it.spelling).fontSize(16)
                Text(it.meaning && it.meaning.length > 0 ? it.meaning : '（无释义）')
                  .fontSize(12).opacity(0.7)
              }.margin({ left: 10 })
            }.padding(10)
          }
        })
      }.layoutWeight(1)

      Button('保存到词库')
        .onClick(async () => {
          const picked = this.selectedItems();
          const r = await FloatingBallOcrManager.getInstance().confirmImport(this.bookId, picked);
          this.status = `已添加 ${r.added} 个；未翻译 ${r.untranslated.length} 个`;
        })
        .margin({ top: 12 })
        .width('100%')
    }
    .padding(16)
  }
}
