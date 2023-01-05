import 'dart:typed_data';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class Toplist extends StatefulWidget {
  final bool? red;

  const Toplist({Key? key, this.red}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ToplistState();
}

class ToplistState extends State<Toplist> {
  late EntryDataSource _entryDataSource;
  List<Entry> _entries = <Entry>[];

  @override
  void initState() {
    _entries = (widget.red == true) ? getEntryDataCategories() : getEntryDataCompanies();
    _entryDataSource = EntryDataSource(entries: _entries);
    super.initState();
  }

  List<Entry> getEntryDataCompanies() {
    return [
      Entry(10001, 'Google', 'allowed', 48, 10),
      Entry(10002, 'Facebook', 'blocked', 47, 32),
      Entry(10003, 'Apple', 'allowed', 27, 0),
      Entry(10004, 'Amazon', 'blocked', 16, 16),
      Entry(10005, 'Microsoft', 'allowed', 8, 0),
    ];
  }

  List<Entry> getEntryDataCategories() {
    return [
      Entry(10001, 'Advertising', 'allowed', 30, 30),
      Entry(10002, 'Tracking', 'blocked', 10, 10),
      Entry(10003, 'Social media', 'allowed', 27, 4),
      Entry(10004, 'CDN', 'blocked', 15, 0),
      Entry(10005, 'Other', 'allowed', 40, 23),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 32.0),
      child: Card(
        elevation: 5,
        child: SfDataGrid(
          allowSorting: true,
          gridLinesVisibility: GridLinesVisibility.none,
          source: _entryDataSource,
          columns: [
            // GridColumn(
            //     columnName: 'icon',
            //     label: Container(
            //         padding: EdgeInsets.symmetric(horizontal: 16.0),
            //         alignment: Alignment.centerLeft,
            //         child: Text(
            //           '',
            //           overflow: TextOverflow.ellipsis,
            //         ))),
            GridColumn(
                columnName: 'name',
                columnWidthMode: ColumnWidthMode.fill,
                label: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    alignment: Alignment.centerLeft,
                    child: Text(
                        (widget.red == false ? 'Companies' : 'Categories'),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),

                    ))),
            GridColumn(
                columnName: 'count',
                label: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '',
                      overflow: TextOverflow.ellipsis,
                    ))),
            GridColumn(
                columnName: 'ratio',
                label: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '',
                      overflow: TextOverflow.ellipsis,
                    ))),
          ],
        ),
      ),
    );
  }
}

class Entry {
  Entry(this.id, this.name, this.type, this.totalCount, this.blockedCount);

  final int id;
  final String name;
  final String type;
  final int totalCount;
  final int blockedCount;
}

class EntryDataSource extends DataGridSource {
  EntryDataSource({required List<Entry> entries}) {
    dataGridRows = entries
        .map<DataGridRow>((dataGridRow) => DataGridRow(cells: [
          //DataGridCell<String>(columnName: 'icon', value: dataGridRow.name),
          DataGridCell<String>(columnName: 'name', value: dataGridRow.name),
          DataGridCell<int>(
            columnName: 'count', value: dataGridRow.totalCount),
          DataGridCell<int>(
            columnName: 'ratio', value: ((dataGridRow.blockedCount / dataGridRow.totalCount) * 100).floor()),
    ]))
    .toList();
  }

  List<DataGridRow> dataGridRows = [];

  @override
  List<DataGridRow> get rows => dataGridRows;

  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    return DataGridRowAdapter(
        cells: row.getCells().map<Widget>((dataGridCell) {
      return Container(
          alignment: (dataGridCell.columnName == 'name')
              ? Alignment.centerLeft
              : Alignment.centerLeft,
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: (dataGridCell.columnName == 'icon')
              ? Icon(
                Icons.smartphone,
                color: Colors.white12,
                size: 24.0,
              )
              : (
              (dataGridCell.columnName == 'ratio') ?
                  SizedBox(
                      height: 10.0,
                      width: 60.0,
                      child: Container(
                        decoration: const BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.all(Radius.circular(4.0))
                        ),
                        child: Row(
                          children: [
                            Container(),
                            SizedBox(
                              width: min((dataGridCell.value.toInt() / 100) * 60, 58),
                              child: Container(
                                  decoration: const BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.all(Radius.circular(4.0))
                                  )
                              )
                            )
                          ]
                        ),
                      )
                  )
              :
              Text(
                dataGridCell.value.toString(),
                overflow: TextOverflow.ellipsis,
              ))
          );

    }).toList());
  }
}
