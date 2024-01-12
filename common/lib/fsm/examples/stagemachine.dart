// @Machine(initial: Stage.waiting)
// class Stage extends State {
//   static const waiting = State("waiting");
//   static const operating = StageOperating();
//
//   const Stage() : super("root");
//
//   @Transition(from: waiting)
//   setForeground(StageContext c, bool foreground) async {
//     c.foreground = foreground;
//     if (c.foreground && c.ready) {
//       return operating;
//     } else {
//       return waiting;
//     }
//   }
//
//   @Transition(from: waiting)
//   setReady(StageContext c, bool ready) async {
//     c.ready = ready;
//     if (c.ready && c.foreground) {
//       return operating;
//     } else {
//       return waiting;
//     }
//   }
// }
//
// @Machine(initial: StageOperating.ready)
// class StageOperating extends State {
//   static const ready = State("ready");
//   static const waiting = State("waiting");
//
//   const StageOperating() : super("operating");
//
//   @Transition(from: ready)
//   showModal(StageContext c, String modal) {
//     if (c.waitingForModal == null) {
//       c.waitingForModal = modal;
//       return waiting;
//     }
//   }
//
//   @Transition(from: waiting)
//   modalShown(StageContext c, String modal) {
//     if (c.waitingForModal != null) {
//       c.waitingForModal = null;
//       return ready;
//     }
//   }
// }
//
// class StageContext with Context {
//   bool foreground = false;
//   bool ready = false;
//   String route = "";
//   String? queuedRoute;
//   String? waitingForModal;
// }
//
// void main() async {
//   final actor = StageActor(StageStateMachine(), StageContext());
//
//   await actor.setForeground(true);
//   assert(actor.context.foreground == true);
//   assert(actor.machine.state == Stage.waiting);
//
//   await actor.setReady(true);
//   assert(actor.context.ready == true);
//   assert(actor.machine.state == Stage.operating);
//
//   await actor.setForeground(false);
//   assert(actor.context.foreground == false);
//   assert(actor.machine.state == Stage.waiting);
//
//   await actor.setForeground(true);
//   assert(actor.machine.state == Stage.operating);
//   assert(actor.machine.nested[Stage.operating]!.state == StageOperating.ready);
//
//   await actor.showModal("hello");
//   assert(actor.context.waitingForModal == "hello");
//   assert(
//       actor.machine.nested[Stage.operating]!.state == StageOperating.waiting);
//
//   await actor.modalShown("hello");
//   assert(actor.context.waitingForModal == null);
//   assert(actor.machine.nested[Stage.operating]!.state == StageOperating.ready);
// }
