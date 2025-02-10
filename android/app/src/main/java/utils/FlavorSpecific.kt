/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2022 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package utils

// A simple marker interface to easily spot components that are flavor-specific.
// Such components (classes) will have distinct implementations for different
// flavors of the app. It means that Android Studio will see only one
// implementation, depending on which build flavor is chosen as active.
interface FlavorSpecific {
}