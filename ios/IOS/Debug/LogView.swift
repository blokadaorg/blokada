//
//  This file is part of Blokada.
//
//  Blokada is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Blokada is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
//
//  Copyright © 2020 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import SwiftUI

struct LogView: View {

    @ObservedObject var vm: LogViewModel

    @Binding var activeSheet: ActiveSheet?

    var body: some View {
        return VStack(alignment: .leading) {
            HStack(alignment: .center) {
                Text("Recent logs").font(.headline)
                Spacer()
                Image(systemName: "bookmark")
                .imageScale(.large)
                .foregroundColor(Color.cActivePlus)
                .frame(width: 32, height: 32)
                .onTapGesture {
                    Logger.w("Debug", "===== Marked from the log viewer =====")
                }
                Image(systemName: "eye")
                    .imageScale(.large)
                    .foregroundColor(Color.cActivePlus)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color(UIColor.systemGray5))
                            .opacity(self.vm.monitoring ? 1 : 0)
                    )
                    .onTapGesture {
                        self.vm.toggleMonitorLog()
                    }
                Image(systemName: Image.fShare)
                    .imageScale(.large)
                    .foregroundColor(Color.cActivePlus)
                    .frame(width: 32, height: 32)
                    .onTapGesture {
                        self.activeSheet = .sharelog
                    }
                if !Env.isProduction {
                    Image(systemName: "ant.circle")
                        .imageScale(.large)
                        .foregroundColor(Color.cActivePlus)
                        .frame(width: 32, height: 32)
                        .onTapGesture {
                            self.activeSheet = .debug
                        }
                }
            }
            .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading) {
                    ForEach((0 ..< self.vm.logs.count).reversed(), id: \.self) {
                        Text(self.vm.logs[$0]).font(.system(size: 9, design: .monospaced))
                            .foregroundColor(self.vm.colorForLine(self.vm.logs[$0]))
                    }
                }
            }
        }
        .padding(.top, 8)
        .padding(.leading, 8)
        .padding(.trailing, 8)
        .onAppear {
            self.vm.loadLog()
        }
    }
}

struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        LogView(vm: LogViewModel(), activeSheet: .constant(nil))
    }
}
