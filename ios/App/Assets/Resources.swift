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

extension Color {
    static let cError = Color.red
    static let cOk = Color.green
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
    static let cHomeBackground = Color("HomeBackground")

    static let cPrimaryBackground = Color(UIColor.systemBackground)
    static let cSecondaryBackground = Color(UIColor.secondarySystemBackground)
    static let cTertiaryBackground = Color(UIColor.tertiarySystemBackground)
    static let cPrimary = Color("Primary")

    static let cSemiTransparent = Color("SemiTransparent")

    static let cTextFieldBgLight = Color("TextFieldBackgroundLight")
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
    static let fPause = "pause"
    static let fInfo = "info.circle"
    static let fUp = "arrow.up.circle"
    static let fLine = "minus"
    static let fCheckmark = "checkmark"
    static let fXmark = "xmark"
    static let fMessage = "message"
    static let fComputer = "desktopcomputer"
    static let fHide = "eye.slash"
    static let fShow = "eye"
    static let fSpeed = "speedometer"
    static let fLocation = "mappin.and.ellipse"
    static let fShield = "lock.shield"
    static let fShieldSlash = "shield.slash"
    static let fDelete = "delete.left"
    static let fShare = "square.and.arrow.up"
    static let fCopy = "doc.on.doc"
    static let fPlus = "plus.diamond"
    static let fCloud = "cloud"
    static let fChart = "chart.bar"
    static let fPack = "cube.box.fill"
    static let fFilter = "line.horizontal.3.decrease"
    static let fDevices = "ipad.and.iphone"
}
