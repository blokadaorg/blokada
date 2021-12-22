//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import Combine

class ContentViewModel: ObservableObject {

    private let sheetRepo = Repos.sheetRepo
    private var cancellables = Set<AnyCancellable>()

    @Published var activeSheet: ActiveSheet? = nil

    init() {
        onSheetChanged()
    }

    func showSheet(_ sheet: ActiveSheet) {
        sheetRepo.showSheet(sheet, params: nil)
    }

    func dismissSheet() {
        sheetRepo.dismiss()
    }

    private func onSheetChanged() {
        sheetRepo.currentSheet
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.activeSheet = it
        })
        .store(in: &cancellables)
    }

}
