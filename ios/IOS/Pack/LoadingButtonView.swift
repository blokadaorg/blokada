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

struct LoadingButtonView: View {

    var action = {}

    var isOn: Bool = false
    var alignTrailing: Bool = false

    let loading: Bool

    var body: some View {
        Button(action: {
            self.action()
        }) {
            ZStack(alignment: alignTrailing ? .trailing : .leading) {
                Toggle("", isOn: .constant(self.isOn))
                    .labelsHidden()
                    .opacity(loading ? 0 : 1)
                    .animation(.easeInOut)

                SpinnerView()
                    .opacity(loading ? 1 : 0)
                    .animation(.easeInOut)
            }

        }.buttonStyle(BorderlessButtonStyle())
    }
}

struct LoadingButtonView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LoadingButtonView(isOn: false, loading: false)
                .previewLayout(.sizeThatFits)
            LoadingButtonView(isOn: false, loading: false)
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)
            LoadingButtonView(isOn: true, loading: false)
                .previewLayout(.sizeThatFits)
            LoadingButtonView(isOn: true, loading: true)
                .previewLayout(.sizeThatFits)
            LoadingButtonView(isOn: false, alignTrailing: true, loading: true)
                .previewLayout(.sizeThatFits)
        }
    }
}
