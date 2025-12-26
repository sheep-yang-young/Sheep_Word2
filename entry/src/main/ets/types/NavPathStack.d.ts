// Type declaration for HarmonyOS Navigation stack to avoid relying on unavailable kit exports.
declare class NavPathStack {
  constructor();
  pushPath(path: { name: string; param?: Object }): void;
  pop(): { name: string; param?: Object } | undefined;
  getParamByName(name: string): Object | undefined;
}
