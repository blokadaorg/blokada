//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2023 Blocka AB. All rights reserved.
//
//  @author Kar
//

import SwiftUI
import CryptoKit

struct ShieldCardView: View {
    @ObservedObject var packsVM: PacksViewModel
    @ObservedObject var vm: PackDetailViewModel

    var action: (String) -> Void = { it in }
    
    @State var safeSearchTag: [String] = []

    var body: some View {
        ZStack {
            if vm.pack.id == "meta_safe_search" {
                // A special case where we mix a pack and a device setting
                // TODO: a better model for this
                ShieldCardSafeSearchView(
                    id: vm.pack.id,
                    headerText: vm.pack.tags.joined(separator: ", "),
                    mainTitle: vm.pack.meta.title.tr(),
                    descriptionText: vm.pack.meta.description.tr(),
                    items: ["safe search"] + vm.pack.configs,
                    selected: self.safeSearchTag + self.vm.pack.status.config,
                    action: { item in
                        if item == "safe search" {
                            if self.vm.isSafeSearch() {
                                self.safeSearchTag = []
                            } else {
                                self.safeSearchTag = ["meta_safe_search/safe search"]
                            }
                            self.vm.toggleSafeSearch()
                            
                        } else {
                            self.vm.changeConfig(config: item, fail: { error in
                                self.packsVM.showError = true
                            })
                        }
                    }
                )
                .onAppear {
                    if self.vm.isSafeSearch() {
                        self.safeSearchTag = ["meta_safe_search/safe search"]
                    } else {
                        self.safeSearchTag = []
                    }
                }
            } else if vm.pack.configs.count == 1 {
                ShieldCardOneView(
                    id: vm.pack.id,
                    headerText: vm.pack.tags.joined(separator: ", "),
                    mainTitle: vm.pack.meta.title.tr(),
                    descriptionText: vm.pack.meta.description.tr(),
                    selected: self.vm.pack.status.config.contains(vm.pack.configs.first!),
                    action: {
                        self.vm.changeConfig(config: vm.pack.configs.first!, fail: { error in
                            self.packsVM.showError = true
                        })
                    }
                )
            } else {
                ShieldCardManyView(
                    id: vm.pack.id,
                    headerText: vm.pack.tags.joined(separator: ", "),
                    mainTitle: vm.pack.meta.title.tr(),
                    descriptionText: vm.pack.meta.description.tr(),
                    items: vm.pack.configs,
                    selected: self.vm.pack.status.config,
                    action: { item in
                        self.vm.changeConfig(config: item, fail: { error in
                            self.packsVM.showError = true
                        })
                    }
                )
            }
        }
    }
}

struct ShieldCardOneView: View {
    var id = ""
    var headerText: String = "editor's choice"
    var mainTitle: String = "Gambling"
    var descriptionText: String = "The Gambling shield blocks access to online gambling sites and content related to gambling."
    var selected: Bool = false
    var action = {}

    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            ZStack {
                Rectangle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color(UIColor.systemGray5), Color(UIColor.systemGray3)]),
                        startPoint: .bottomTrailing, endPoint: .leading
                    ))
                    .overlay(Color(generateColor(from: id)).blendMode(.color))
            }
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 10, y: 10)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: -5, y: -5)

            VStack(alignment: .leading) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(headerText.uppercased())
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Color.secondary)
                    }
                    .padding(.top, 8)
                    
                    Text(mainTitle)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(descriptionText)
                        .font(.body)
                        .padding(.bottom, 16)
                        .foregroundColor(.primary)
                }
                .padding([.top, .leading, .trailing])
                
                VStack {
                    ShieldItemView(id: self.id, title: self.mainTitle,
                                   selected: self.selected,
                                   action: { self.action() }
                    )
                    .onTapGesture {
                        self.action()
                    }
                    .padding()
                }
                .background(.regularMaterial)
                .cornerRadius(8, corners: [.bottomLeft, .bottomRight])
            }
        }
        .padding(.bottom, 8)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ShieldCardManyView: View {
    var id = ""
    var headerText: String = "adblocking"
    var mainTitle: String = "Ads"
    var descriptionText: String = "The Ads shield, available in both Standard and Restrictive variants, is focused on eliminating intrusive advertisements, pop-ups, and banners from your web experience."
    var items: [String] = ["standard", "restrictive"]
    var selected: [String] = []
    var action: (String) -> Void = { it in }

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            ZStack(alignment: .top) {
                Rectangle()
                    .foregroundColor(colorScheme == .dark ? Color.cSecondaryBackground : Color.cBackground)
                
//                Rectangle()
//                    .fill(LinearGradient(
//                        gradient: Gradient(colors: [Color(UIColor.clear), Color(UIColor.systemGray6)]),
//                        startPoint: .bottom, endPoint: .top
//                    ))
//                    .frame(height: 64)
            }
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 10, y: 10)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: -5, y: -5)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(headerText.uppercased())
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color.secondary)
                }
                .padding(.top, 8)
                
                Text(mainTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(descriptionText)
                    .font(.body)
                .padding(.bottom, 24)

                ForEach(items, id: \.self) { item in
                    if item != "standard" {
                        Divider()
                    }
                    ShieldItemView(id: item, title: item.capitalizingFirstLetter(),
                                   selected: self.selected.contains(item),
                                   action: { self.action(item) }
                    )
                    .onTapGesture {
                        self.action(item)
                    }
                }
            }
            .padding()
        }
        .padding(.bottom, 8)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ShieldCardSafeSearchView: View {
    var id = ""
    var headerText: String = "adblocking"
    var mainTitle: String = "Ads"
    var descriptionText: String = "The Ads shield, available in both Standard and Restrictive variants, is focused on eliminating intrusive advertisements, pop-ups, and banners from your web experience."
    var items: [String] = ["standard", "restrictive"]
    var selected: [String] = []
    var action: (String) -> Void = { it in }

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            ZStack(alignment: .top) {
                Rectangle()
                    .foregroundColor(colorScheme == .dark ? Color.cSecondaryBackground : Color.cBackground)

                Rectangle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color(UIColor.systemGray5), Color(UIColor.systemGray3)]),
                        startPoint: .bottomTrailing, endPoint: .leading
                    ))
                    .overlay(Color.cSafeSearchCard.blendMode(.color))
            }
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 10, y: 10)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: -5, y: -5)

            VStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(headerText.uppercased())
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Color.secondary)
                    }
                    .padding(.top, 8)

                    Text(mainTitle)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(descriptionText)
                        .font(.body)
                        .padding(.bottom, 24)
                }
                .padding()

                VStack {
                    ForEach(items, id: \.self) { item in
                        let tag = "\(id)/\(item)"

                        if item != "safe search" {
                            Divider()
                        }
                        ShieldItemView(id: item, title: item.capitalizingFirstLetter(),
                                       selected: self.selected.contains(tag),
                                       action: { self.action(item) }
                        )
                        .onTapGesture {
                            self.action(item)
                        }
                    }
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(10, corners: [.bottomLeft, .bottomRight])
            }
        }
        .padding(.bottom, 8)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ShieldItemView: View {
    var id = ""
    var title: String = ""
    var slugline: String? = nil
    var selected: Bool = false
    var loading: Bool = false
    var action = {}

    var body: some View {
        HStack {
            ZStack {
                ShieldIconView(id: self.id,  title: self.title)
                    .frame(width: 64, height: 64)
                    .mask(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel(self.title)
            }

            VStack(alignment: .leading) {
                Text(self.title)
                //.foregroundColor(self.selected ? Color.cAccent : Color.primary)
                .foregroundColor(Color.primary)
                .accessibilitySortPriority(1)

                if let slug = self.slugline {
                    Text(slug.tr())
                    .font(.footnote)
                    .foregroundColor(Color.secondary)
                }
            }

            Spacer()

            LoadingButtonView(action: self.action, isOn: self.selected, alignTrailing: true, loading: self.loading)
        }
        .padding(8)
    }
}

struct ShieldIconView: View {

    var id: String = ""
    var title: String = ""
    var small: Bool = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [Color(UIColor.systemGray4), Color(UIColor.systemGray)]),
                    startPoint: .bottomTrailing, endPoint: .topLeading
                ))
                .overlay(Color(generateColor(from: id)).blendMode(.color))

            Text(title.prefix(2).uppercased())
                .font(small ? .headline : .title2)
                //.foregroundColor(Color(generateColor(from: id)))
            .foregroundColor(.white)
                .fontWeight(.bold)
        }
    }
}

private func generateColor(from string: String) -> UIColor {
    let hash = SHA256.hash(data: Data(string.utf8))
    let bytes = Array(hash)
    
    let red = CGFloat(bytes[0]) / 255.0
    let green = CGFloat(bytes[1]) / 255.0
    let blue = CGFloat(bytes[2]) / 255.0
    
    return UIColor(red: red, green: green, blue: blue, alpha: 1)
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {

    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct ShieldCardOneView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack {
                ShieldCardOneView(id: "koko", headerText: "RECOMMENDED", mainTitle: "Porn", descriptionText: "This filter is specifically designed to block access to adult and pornographic content on the web.")
                
                ShieldCardManyView()
                
                ShieldCardOneView(id: "8")
                
                ShieldCardOneView(id: "4", mainTitle: "Piracy", descriptionText: "Short description")

            }
            .padding(20)
        }
    }
}
