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

extension String: Error {} // Enables you to throw a string

extension String: LocalizedError { // Adds error.localizedDescription to Error instances
    public var errorDescription: String? { return self }
}

extension String {
    func cause(_ cause: Error?) -> String {
        return self + ": " + (cause?.localizedDescription ?? "nil")
    }
}
