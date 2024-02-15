import '../../common/defaults/filter_defaults.dart';
import '../../common/model.dart';
import '../../common/model/filter/filter_json.dart';
import '../../device/device.dart';
import '../../util/di.dart';
import '../../util/trace.dart';
import '../api/api.dart';
import '../api/prod.dart';
import 'filter.dart';
import '../../filter/channel.pg.dart' as fops;

final _device = dep<DeviceStore>();
final _trace = dep<TraceFactory>();

class ProdFilterActor extends FilterActor with TraceOrigin {
  ProdFilterActor(Act act)
      : super(
          actionLists: (_) async {
            final actor = ProdApiActor(act, HttpRequest(ApiEndpoint.getLists));
            final json = (await actor.waitForState(ApiStates.success)).result!;
            return DeckJson().lists(json);
          },
          actionKnownFilters: (_) async => getKnownFilters(act),
          actionDefaultEnabled: (_) async => getDefaultEnabled(act),
          actionPutUserLists: (it) async {
            await _device.setLists(
                _trace.newTrace("ProdFilterActor", "setLists"), it.toList());
          },
          actionPutConfig: (it) async {},
        ) {
    _device.addOn(deviceChanged, (trace) async {
      // todo: will fail on every time except first
      Future(() async {
        await waitForState(FilterStates.ready);
        await config(_device.lists?.toSet(), {});
      });
    });

    addOnState(FilterStates.ready, "ops", (state, c) {
      final ops = fops.FilterOps();

      final filters = c.filters
          .map((it) => fops.Filter(
                filterName: it.filterName,
                options: it.options.map((it) => it.optionName).toList(),
              ))
          .toList();
      ops.doFiltersChanged(filters);

      final selections = c.selectedFilters
          .map((it) => fops.Filter(
                filterName: it.filterName,
                options: it.options,
              ))
          .toList();
      ops.doFilterSelectionChanged(selections);

      ops.doListToTagChanged(c.listsToTags);
    });
  }
}
