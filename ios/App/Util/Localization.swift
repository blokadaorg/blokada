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

extension String {
    func tr() -> String {
        let format = NSLocalizedString(self, tableName: "Packs", bundle: Bundle(for: BundleToken.self), comment: "")
        return String(format: format, locale: Locale.current)
    }

    func trTag() -> String {
        let format = NSLocalizedString(self, tableName: "PackTags", bundle: Bundle(for: BundleToken.self), comment: "")
        return String(format: format, locale: Locale.current)
    }

    private final class BundleToken {}

}
