export class CapsuleFlow {
  private static autoPickPending: boolean = false;

  static markAutoPickPending(): void {
    CapsuleFlow.autoPickPending = true;
  }

  static consumeAutoPickPending(): boolean {
    const v = CapsuleFlow.autoPickPending;
    CapsuleFlow.autoPickPending = false;
    return v;
  }
}
