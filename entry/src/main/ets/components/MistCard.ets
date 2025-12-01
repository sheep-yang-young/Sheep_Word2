@Component
export struct MistCard {
  @BuilderParam content: () => void;
  @Prop blurRadius: number = 20;

  // 修复：去掉 private，否则无法在 Index 中初始化
  widthVal: Length = '90%';
  heightVal: Length | undefined = undefined;

  build() {
    Stack() {
      // 1. 材质层
      Rect()
        .width('100%')
        .height('100%')
        .fill('rgba(255, 255, 255, 0.1)')
        .radius(24)

      // 2. 边框层
      Rect()
        .width('100%')
        .height('100%')
        .fill(Color.Transparent)
        .radius(24)
        .border({ width: 1.5, color: 'rgba(255, 255, 255, 0.3)' })

      // 3. 内容层
      Column() {
        this.content()
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width(this.widthVal)
    .height(this.heightVal)
    .backdropBlur(this.blurRadius)
    .shadow({ radius: 30, color: 'rgba(0,0,0,0.2)', offsetY: 15 })
    .borderRadius(24)
  }
}