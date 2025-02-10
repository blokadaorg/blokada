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

import Foundation
import SwiftUI

extension String {

    func toBlokadaPlusText(color: Color = Color.primary, plusColor: Color = Color.cAccent) -> Text {
        if self.hasPrefix("BLOKADA+") {
            return getBlokadaPlusText(color, plusColor) + Text(self.replacingOccurrences(of: "BLOKADA+", with: ""))
        } else if self.hasSuffix("BLOKADA+") {
            return Text(self.replacingOccurrences(of: "BLOKADA+", with: "")) + getBlokadaPlusText(color, plusColor)
        } else if self.contains("BLOKADA+") {
            let parts = self.components(separatedBy: "BLOKADA+")
            return Text(parts[0]) + getBlokadaPlusText(color, plusColor) + Text(parts[1])
        } else {
            return Text(self)
        }
    }

    func toBlokadaText() -> Text {
        if self.hasPrefix("BLOKADA") {
            return getBlokadaText() + Text(self.replacingOccurrences(of: "BLOKADA", with: ""))
        } else if self.hasSuffix("BLOKADA") {
            return Text(self.replacingOccurrences(of: "BLOKADA", with: "")) + getBlokadaText()
        } else if self.contains("BLOKADA") {
            let parts = self.components(separatedBy: "BLOKADA")
            return Text(parts[0]) + getBlokadaText() + Text(parts[1])
        } else {
            return Text(self)
        }
    }

    func withBoldSections(color: Color = Color.primary, font: Font? = nil) -> Text {
        let parts = self.components(separatedBy: "*")
        var output = Text(parts[0])
        var shouldBold = true
        for part in parts.dropFirst() {
            output = output + Text(part)
                .fontWeight(shouldBold ? .bold : .regular)
                .foregroundColor(shouldBold ? color : Color.primary)
                .font(font ?? .body)
            shouldBold = !shouldBold
        }
        return output
    }

}

private func getBlokadaPlusText(_ color: Color, _ plusColor: Color) -> Text {
    return Text("BLOKADA")
        .fontWeight(.heavy)
        .kerning(2)
        .foregroundColor(color)
        + Text("+")
            .fontWeight(.heavy)
            .kerning(2)
            .foregroundColor(plusColor)
}

private func getBlokadaText() -> Text {
    return Text("BLOKADA")
        .fontWeight(.heavy)
        .kerning(2)
}
