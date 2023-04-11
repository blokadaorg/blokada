//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2020 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import SwiftUI
import Factory

struct LogView: View {

    @ObservedObject var vm = ViewModels.log
    @ObservedObject var contentVM = ViewModels.content

    @Injected(\.env) private var env

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
                    BlockaLogger.w("Debug", "===== Marked from the log viewer =====")
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
                       // self.contentVM.stage.showModal(.ShareLog)
                    }
                if !self.env.isProduction() {
                    Image(systemName: "ant.circle")
                        .imageScale(.large)
                        .foregroundColor(Color.cActivePlus)
                        .frame(width: 32, height: 32)
                        .onTapGesture {
                            self.contentVM.stage.showModal(.debug)
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
        LogView()
    }
}
