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

extension Color {
    static let cError = Color.red
    static let cAccent = Color("Orange")

    static let cActive = Color.blue
    static let cActivePlus = Color("Orange")
    static let cActiveGradient = Color("ActiveGradient")
    static let cActivePlusGradient = Color("ActivePlusGradient")

    static let cPowerButtonGradient = Color("PowerButtonGradient")
    static let cPowerButtonOff = Color("PowerButtonOff")

    static let cBackground = Color(UIColor.systemBackground)
    static let cBackgroundSplash = Color(UIColor.systemBackground)
    static let cBackgroundNavBar = Color("Background")

    static let cPrimaryBackground = Color(UIColor.systemBackground)
    static let cSecondaryBackground = Color(UIColor.secondarySystemBackground)
}

extension Image {
    static let iBlokada = "Blokada"
    static let iBlokadaPlus = "BlokadaPlus"
    static let iHeader = "Header"
    static let iLisek = "Lisek"

    static let fHamburger = "line.horizontal.3"
    static let fHelp = "questionmark.circle"
    static let fAccount = "person.crop.circle"
    static let fLogout = "arrow.uturn.left"
    static let fDonate = "heart"
    static let fSettings = "gear"
    static let fAbout = "person.2"
    static let fPower = "power"
    static let fInfo = "info.circle"
    static let fUp = "chevron.up"
    static let fLine = "minus"
    static let fCheckmark = "checkmark"
    static let fMessage = "message"
    static let fComputer = "desktopcomputer"
    static let fHide = "eye.slash"
    static let fSpeed = "speedometer"
    static let fLocation = "mappin.and.ellipse"
    static let fShield = "lock.shield"
    static let fDelete = "delete.left"
    static let fShare = "square.and.arrow.up"
    static let fCopy = "doc.on.doc"
}
