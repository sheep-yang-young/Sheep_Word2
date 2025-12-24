@Entry
@Component
struct WordCard {
  @LocalStorageProp('spelling') spelling: string = 'Lumina';
  @LocalStorageProp('phonetic') phonetic: string = '';
  @LocalStorageProp('meaning') meaning: string = '点击开始背单词';

  build() {
    Stack() {
      // 1. 背景层：卡片不支持 new LinearGradient，改用清新的淡蓝灰色
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#F0F4F8') // 柔和的背景色，代替渐变

      // 2. 内容卡片层
      Column() {
        // 顶部装饰条
        Row()
          .width(24)
          .height(4)
          .backgroundColor('#4A90E2') // 蓝色装饰条
          .borderRadius(2)
          .margin({ bottom: 12 })

        // 单词
        Text(this.spelling)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2C3E50')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)

        // 音标
        if (this.phonetic) {
          Text(this.phonetic)
            .fontSize(13)
            .fontColor('#7F8C8D')
            .margin({ top: 4 })
            .fontStyle(FontStyle.Italic)
        }

        // 分隔线
        Divider()
          .color('#E0E0E0')
          .width('100%')
          .strokeWidth(0.5)
          .margin({ top: 12, bottom: 12 })

        // 释义
        Text(this.meaning)
          .fontSize(15)
          .fontColor('#57606F')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .lineHeight(20)

      }
      .width('90%') // 稍微留边
      .backgroundColor('#FFFFFF') // 纯白卡片
      .borderRadius(16)
      .padding({ top: 16, bottom: 16, left: 12, right: 12 })
      // 阴影是支持的，这是营造立体感的关键
      .shadow({ radius: 12, color: 'rgba(0,0,0,0.08)', offsetY: 4 })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: { targetPage: 'Index' }
      });
    })
  }
}