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

class ContentHostingController<Content> : UIHostingController<Content> where Content : View {

    var onTransitioning = { (transitioning: Bool) in }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { context in
            // This is called during the animation
            self.onTransitioning(true)
        }, completion: { context in
            // This is called after the rotation is finished. Equal to deprecated `didRotate`
            self.onTransitioning(false)
        })
    }

}
