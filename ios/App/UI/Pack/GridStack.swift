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

struct GridStack<Content: View>: View {
    let count: Int
    let columns: Int
    let content: (Int) -> Content

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(0 ..< (count / columns), id: \.self) { row in
                HStack {
                    ForEach(0 ..< self.columns, id: \.self) { column in
                        self.content(row * self.columns + column)
                            // Fill in the rest of the row with hidden last item (a cheat)
                            .opacity(row * self.columns + column >= self.count ? 0 : 1)
                            .disabled(row * self.columns + column >= self.count)
                    }
                }
            }
            if (count / columns) * columns < count {
                HStack {
                    ForEach(0 ..< self.columns, id: \.self) { column in
                        self.content((self.count / self.columns) * self.columns + column)
                            // Fill in the rest of the row with hidden last item (a cheat)
                            .opacity((self.count / self.columns) * self.columns + column >= self.count ? 0 : 1)
                            .disabled((self.count / self.columns) * self.columns + column >= self.count)
                    }
                }
            }
        }
    }

    init(count: Int, columns: Int, @ViewBuilder content: @escaping (Int) -> Content) {
        self.count = count
        self.columns = columns
        self.content = { index in
            if index < count {
                return content(index)
            } else {
                // Fill in the rest of the row with hidden last item (a cheat)
                return content(count - 1)
            }
        }
    }
}

struct GridStack_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            GridStack(count: 1, columns: 3) { index in
                Text("Hello \(index)")
            }
            GridStack(count: 4, columns: 3) { index in
                Text("Hello \(index)")
                    .padding(.bottom, 8)
            }
            GridStack(count: 7, columns: 3) { index in
                TagView(text: "Hello \(index)", active: false)
            }
            GridStack(count: 8, columns: 4) { index in
                TagView(text: "Hello \(index)", active: false)
            }
            GridStack(count: 0, columns: 3) { index in
                Text("Hello \(index)")
            }
            GridStack(count: 10, columns: 4) { index in
                TagView(text: "Hello \(index)", active: false)
            }
        }
        .background(Color.secondary)
    }
}
