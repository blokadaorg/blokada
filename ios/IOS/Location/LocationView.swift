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

struct LocationView: View {

    let vm: LocationViewModel

    var body: some View {
        VStack {
            HStack {
                Image(systemName: Image.fLocation)
                    .imageScale(.large)
                    .foregroundColor(self.vm.isActive ? Color.cAccent : Color.cSecondaryBackground)
                    .frame(width: 48, height: 48)

                Text(self.vm.name)
                    .fontWeight(self.vm.isActive ? .bold : .regular)
                    .foregroundColor(Color.primary)

                Spacer()

                if self.vm.isActive {
                    Image(systemName: Image.fCheckmark)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundColor(Color.cActivePlus)
                }
            }
        }
        .padding([.leading, .trailing])
        .padding([.top, .bottom], 4)
    }
}

struct LocationView_Previews: PreviewProvider {
    static var previews: some View {
        let selected = LocationViewModel(mocked: "New York")
        return Group {
            LocationView(vm: LocationViewModel(mocked: "Schweden"))
                .previewLayout(.sizeThatFits)
            LocationView(vm: selected)
                .previewLayout(.sizeThatFits)
        }
    }
}
