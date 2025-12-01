@Component
export struct SimpleLineChart {
  @Prop data: number[];
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  build() {
    Column() {
      Canvas(this.context)
        .width('100%')
        .height('100%')
        .onReady(() => {
          this.drawChart();
        })
    }
    .width('100%')
    .height(200)
    .backgroundColor(Color.White)
    .borderRadius(16)
    .shadow({ radius: 10, color: 'rgba(0,0,0,0.05)' })
  }

  drawChart() {
    const ctx = this.context;
    const width = ctx.width;
    const height = ctx.height;
    const padding = 20;

    ctx.clearRect(0, 0, width, height);

    if (!this.data || this.data.length === 0) return;

    const maxVal = Math.max(...this.data, 10);
    const stepX = (width - padding * 2) / (this.data.length > 1 ? this.data.length - 1 : 1);
    const scaleY = (height - padding * 2) / maxVal;

    ctx.beginPath();
    ctx.lineWidth = 3;
    ctx.strokeStyle = '#0A59F7';
    ctx.lineCap = 'round';

    this.data.forEach((val, index) => {
      const x = padding + index * stepX;
      const y = height - padding - (val * scaleY);
      if (index === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    });
    ctx.stroke();

    ctx.fillStyle = '#0A59F7';
    this.data.forEach((val, index) => {
      const x = padding + index * stepX;
      const y = height - padding - (val * scaleY);
      ctx.beginPath();
      ctx.arc(x, y, 4, 0, 6.28);
      ctx.fill();
    });
  }
}

@Component
export struct CleanCard {
  @BuilderParam content: () => void;

  build() {
    Column() {
      this.content()
    }
    .width('90%')
    .padding(24)
    .backgroundColor(Color.White)
    .borderRadius(20)
    .shadow({ radius: 20, color: 'rgba(0,0,0,0.08)', offsetY: 5 })
  }
}