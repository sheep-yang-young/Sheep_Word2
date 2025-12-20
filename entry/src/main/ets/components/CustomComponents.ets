@Component
export struct SimpleLineChart {
  @Prop data: number[];

  // 记录组件的实际宽高
  @State chartWidth: number = 0;
  @State chartHeight: number = 0;

  build() {
    Column() {
      // 使用 Stack 堆叠：背景填充层 -> 线条层 -> 数据点
      Stack({ alignContent: Alignment.TopStart }) {
        // [核心修复] 移除了外层的 if (width > 0) 判断
        // 确保组件始终挂载在树上，这样才能正确响应 onAreaChange 和数据更新

        // 1. 底部填充区域 (Polygon 自动闭合)
        Polygon()
          .points(this.getPointsArray(true))
          .fill('rgba(10, 89, 247, 0.1)')
          .width(this.chartWidth)
          .height(this.chartHeight)

        // 2. 折线 (Polyline 不闭合)
        Polyline()
          .points(this.getPointsArray(false))
          .stroke('#0A59F7')
          .strokeWidth(3)
          .fill('none') // 不填充，只画线
          .strokeLineCap(LineCapStyle.Round)
          .strokeLineJoin(LineJoinStyle.Round)
          .width(this.chartWidth)
          .height(this.chartHeight)

        // 3. 数据点 (圆圈)
        ForEach(this.data, (val: number, index: number) => {
          Circle({ width: 6, height: 6 })
            .fill('#0A59F7')
            .position({
              x: this.getX(index) - 3,
              y: this.getY(val) - 3
            })
        })
      }
      .width('100%')
      .height('100%')
      // 监听组件尺寸变化，动态更新绘图坐标
      .onAreaChange((oldArea: Area, newArea: Area) => {
        // 加一个简单的防抖或直接更新
        this.chartWidth = newArea.width as number;
        this.chartHeight = newArea.height as number;
      })
    }
    .width('100%')
    .height(150)
    .backgroundColor(Color.White)
    .borderRadius(16)
  }

  // --- 坐标计算辅助函数 ---

  getX(index: number): number {
    if (this.chartWidth <= 0) return 0; // 安全检查
    const padding = 10;
    const availableWidth = this.chartWidth - padding * 2;
    const step = this.data.length > 1 ? availableWidth / (this.data.length - 1) : 0;

    if (this.data.length <= 1) return this.chartWidth / 2;
    return padding + index * step;
  }

  getY(value: number): number {
    if (this.chartHeight <= 0) return 0; // 安全检查
    const padding = 10;
    const availableHeight = this.chartHeight - padding * 2;
    const maxVal = Math.max(...this.data, 5);
    const scale = availableHeight / maxVal;

    return this.chartHeight - padding - (value * scale);
  }

  getPointsArray(closeShape: boolean): Array<[number, number]> {
    // [核心修复] 如果宽高无效，返回空数组，避免报错
    if (this.chartWidth <= 0 || this.chartHeight <= 0) {
      return [];
    }

    let points: Array<[number, number]> = [];

    this.data.forEach((val, index) => {
      points.push([this.getX(index), this.getY(val)]);
    });

    if (closeShape && points.length > 0) {
      const padding = 10;
      points.push([this.chartWidth - padding, this.chartHeight - padding]);
      points.push([padding, this.chartHeight - padding]);
    }

    return points;
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