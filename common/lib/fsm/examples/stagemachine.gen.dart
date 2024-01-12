// class StageStateMachine extends StateMachine<StageContext> {
//   final proto = const Stage();
//
//   final nested = {
//     Stage.operating: StageOperatingStateMachine(),
//   };
//
//   StageStateMachine() : super(Stage.waiting);
//
//   setForeground(StageContext c, bool foreground) async {
//     if (state == Stage.waiting || state == Stage.operating) {
//       final newState = await proto.setForeground(c, foreground);
//       if (newState != null) {
//         state = newState;
//       }
//     }
//   }
//
//   setReady(StageContext c, bool ready) async {
//     if (state == Stage.waiting || state == Stage.operating) {
//       final newState = await proto.setReady(c, ready);
//       if (newState != null) {
//         state = newState;
//       }
//     }
//   }
// }
//
// class StageOperatingStateMachine extends StateMachine<StageContext> {
//   final machine = const StageOperating();
//
//   StageOperatingStateMachine() : super(StageOperating.ready);
//
//   showModal(StageContext c, String modal) async {
//     if (state == StageOperating.ready) {
//       final newState = await machine.showModal(c, modal);
//       if (newState != null) {
//         state = newState;
//       }
//     }
//   }
//
//   modalShown(StageContext c, String modal) async {
//     if (state == StageOperating.waiting) {
//       final newState = await machine.modalShown(c, modal);
//       if (newState != null) {
//         state = newState;
//       }
//     }
//   }
// }
//
// class StageActor extends Actor<StageStateMachine, StageContext> {
//   StageActor(super.state, super.context);
//
//   final eventQueue = <Function()>[];
//
//   setForeground(bool foreground) async {
//     eventQueue
//         .add(() async => await machine.setForeground(context, foreground));
//     await _processQueue();
//     // update context
//   }
//
//   setReady(bool ready) async {
//     eventQueue.add(() async => await machine.setReady(context, ready));
//     await _processQueue();
//     // update context
//   }
//
//   showModal(String modal) async {
//     eventQueue.add(() async =>
//         await machine.nested[machine.state]?.showModal(context, modal));
//     await _processQueue();
//     // update context
//   }
//
//   modalShown(String modal) async {
//     eventQueue.add(() async =>
//         await machine.nested[machine.state]?.modalShown(context, modal));
//     await _processQueue();
//     // update context
//   }
//
//   _processQueue() async {
//     while (eventQueue.isNotEmpty) {
//       await eventQueue.removeAt(0)();
//     }
//   }
// }
