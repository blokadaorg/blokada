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
import StoreKit

struct RateAppView: View {

    @Binding var activeSheet: ActiveSheet?

    @State var rating = 0

    var body: some View {
        NavigationView {
            VStack {
                BlokadaView(animate: true)
                    .frame(width: 100, height: 100)

                Text(L10n.mainRateUsHeader)
                    .font(.largeTitle)
                    .bold()
                    .padding()

                Text(L10n.mainRateUsDescription)
                    .padding()

                HStack {
                    ForEach(1..<6) { number in
                        Button(action: {
                            self.rating = number
                            if number < 4 {
                                self.activeSheet = nil
                            }
                        }) {
                            Image(systemName: self.rating < number ? "star" : "star.fill")
                                .imageScale(.large)
                                .foregroundColor(self.rating < number ? .secondary : Color.cActivePlus)
                                .frame(width: 32, height: 32)
                        }
                    }
                }

                VStack {
                    Text(L10n.mainRateUsOnAppStore)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding()

                    Button(action: {
                        self.activeSheet = nil
                        SKStoreReviewController.requestReview()
                    }) {
                        ZStack {
                            ButtonView(enabled: .constant(true), plus: .constant(true))
                                .frame(height: 44)
                            Text(L10n.mainRateUsActionSure)
                                .foregroundColor(.white)
                                .bold()
                        }
                    }
                }
                .padding(40)
                .opacity(self.rating >= 4 ? 1 : 0)
                .animation(.easeInOut)
            }
            .frame(maxWidth: 500)

            .navigationBarItems(trailing:
                Button(action: {
                    self.activeSheet = nil
                }) {
                    Text(L10n.universalActionDone)
                }
                .contentShape(Rectangle())
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .accentColor(Color.cAccent)
        .onAppear {
            Config.shared.markRateAppShown()
        }
    }
}

struct RateAppView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RateAppView(activeSheet: .constant(nil))
            RateAppView(activeSheet: .constant(nil), rating: 3)
                .previewDevice(PreviewDevice(rawValue: "iPhone X"))
            RateAppView(activeSheet: .constant(nil), rating: 5)
                .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (3rd generation)"))
        }
    }
}

/**
 In order to open app store:

 guard let writeReviewURL = URL(string: "https://itunes.apple.com/app/idXXXXXXXXXX?action=write-review")
     else { fatalError("Expected a valid URL") }
 UIApplication.shared.open(writeReviewURL, options: [:], completionHandler: nil)
 */
