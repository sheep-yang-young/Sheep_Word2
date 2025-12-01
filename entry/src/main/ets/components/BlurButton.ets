@Component
export struct BlurButton {
  @Prop icon: Resource; // 按钮图标
  @Prop label: string;  // 按钮文字（可选）
  @Prop isDestructive: boolean = false; // 是否是消极操作(如"忘记")

  action: () => void = () => {};

  build() {
    Column() {
      Button() {
        Image(this.icon)
          .width(28)
          .height(28)
          .fillColor(this.isDestructive ? 'rgba(255, 100, 100, 0.9)' : Color.White)
      }
      .width(72)
      .height(72)
      .type(ButtonType.Circle)
      .backgroundColor('rgba(255, 255, 255, 0.15)') // 玻璃底色
      .backdropBlur(30)
      .border({ width: 1, color: 'rgba(255, 255, 255, 0.3)' })
      .shadow({ radius: 10, color: 'rgba(0,0,0,0.1)', offsetY: 5 })
      .onClick(() => {
        this.action();
      })
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 }) // 按压缩放效果

      if (this.label) {
        Text(this.label)
          .fontSize(12)
          .fontColor('rgba(255,255,255,0.6)')
          .margin({ top: 8 })
      }
    }
  }
}