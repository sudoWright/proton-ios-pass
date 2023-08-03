//
//
// ManageSharedVaultView.swift
// Proton Pass - Created on 02/08/2023.
// Copyright (c) 2023 Proton Technologies AG
//
// This file is part of Proton Pass.
//
// Proton Pass is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Pass is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Pass. If not, see https://www.gnu.org/licenses/.
//

import Client
import Entities
import Factory
import ProtonCore_UIFoundations
import SwiftUI
import UIComponents

struct ManageSharedVaultView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: ManageSharedVaultViewModel
    private let router = resolve(\RouterContainer.mainUIKitSwiftUIRouter)

    var body: some View {
        ZStack(alignment: .bottom) {
            mainContainer
            if viewModel.vault.isAdmin {
                CapsuleTextButton(title: "Share with more people",
                                  titleColor: PassColor.textInvert,
                                  backgroundColor: PassColor.interactionNorm,
                                  action: { router.presentSheet(for: .sharingFlow) })
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(kItemDetailSectionPadding)
        .navigationBarTitleDisplayMode(.inline)
        .background(PassColor.backgroundNorm.toColor)
        .toolbar { toolbarContent }
        .navigationModifier()
    }
}

private extension ManageSharedVaultView {
    var mainContainer: some View {
        VStack {
            headerVaultInformation
            if viewModel.loading {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else {
                userList
                    .background(PassColor.backgroundNorm.toColor)
            }
        }
//        .animation(.default, value: viewModel.error)
//        .navigate(isActive: $viewModel.goToNextStep, destination: router.navigate(to: .userSharePermission))

//        .ignoresSafeArea(.keyboard)
    }
}

private extension ManageSharedVaultView {
    var headerVaultInformation: some View {
        VStack {
            ZStack {
                viewModel.vault.backgroundColor
                    .clipShape(Circle())

                viewModel.vault.bigImage
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundColor(viewModel.vault.mainColor)
                    .frame(width: 28, height: 28)
            }
            .frame(width: 64, height: 64)

            Text(viewModel.vault.name)
                .font(.title2.bold())
                .foregroundColor(PassColor.textNorm.toColor)
            Text("\(viewModel.itemsNumber ?? 0) items")
                .font(.title3)
                .foregroundColor(PassColor.textWeak.toColor)
        }
    }
}

private extension ManageSharedVaultView {
    var userList: some View {
        List {
            ForEach(viewModel.users, id: \.self) { user in
                VStack {
                    userCell(for: user)
                        .padding(16)
                    if !viewModel.isLast(info: user) {
                        Divider()
                    }
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.white.opacity(0.04))
            }
        }
        .listStyle(.plain)
        .cornerRadius(10)
        .onAppear {
            // Set the default to clear
            UITableView.appearance().backgroundColor = .clear
        }
    }

    func userCell(for infos: ShareUser) -> some View {
        HStack(spacing: kItemDetailSectionPadding) {
            SquircleThumbnail(data: .initials(infos.email.initialsRemovingEmojis()),
                              tintColor: ItemType.login.tintColor,
                              backgroundColor: ItemType.login.backgroundColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(infos.email)
                    .foregroundColor(PassColor.textNorm.toColor)
                Text(infos.shareRole?.role ?? "pending")
                    .foregroundColor(PassColor.textWeak.toColor)
            }

            Spacer()
            if viewModel.vault.isAdmin {
                vaultTrailingView(viewModel.vault)
//                Image(uiImage: IconProvider.threeDotsVertical)
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 24, height: 24)
//                    .foregroundColor(Color(uiColor: PassColor.textWeak))
            }
        }
    }
}

private extension ManageSharedVaultView {
    @ViewBuilder
    private func vaultTrailingView(_ vault: Vault) -> some View {
        Menu(content: {
            if vault.isOwner {
                Button(action: {
//                    viewModel.edit(vault: vault)
                }, label: {
                    Label(title: {
                        Text("Edit")
                    }, icon: {
                        Image(uiImage: IconProvider.pencil)
                            .renderingMode(.template)
                            .foregroundColor(Color(uiColor: PassColor.textWeak))
                    })
                })
            }

            if !vault.isPrimary, vault.isOwner {
                Button(action: {
//                    viewModel.share(vault: vault)
                }, label: {
                    Label(title: {
                        Text("Share")
                    }, icon: {
                        IconProvider.userPlus
                    })
                })
            }

            if vault.members > 1 {
                Button(action: {
//                    viewModel.router.presentSheet(for: .manageShareVault(vault, false))
                }, label: {
                    Label(title: {
                        Text(vault.isAdmin ? "Manage access" : "View members")
                    }, icon: {
                        IconProvider.users
                    })
                })
            }

            Divider()

            if vault.isOwner {
                Button(role: .destructive,
                       action: {
//                    viewModel.delete(vault: vault)

                       },
                       label: {
                           Label(title: {
                               Text("Delete vault")
                           }, icon: {
                               Image(uiImage: IconProvider.trash)
                           })
                       })
            }

            if !vault.isOwner {
                Button(role: .destructive,
                       action: {
//                    viewModel.leaveVault(vault: vault)

                       },
                       label: {
                           Label(title: {
                               Text("Leave vault")
                           }, icon: {
                               Image(uiImage: IconProvider.circleSlash)
                           })
                       })
            }
        }, label: { Image(uiImage: IconProvider.threeDotsVertical)
            .resizable()
            .scaledToFit()
            .frame(width: 24, height: 24)
            .foregroundColor(Color(uiColor: PassColor.textWeak))
        })
    }
}

private extension ManageSharedVaultView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            CircleButton(icon: IconProvider.arrowDown,
                         iconColor: PassColor.interactionNormMajor2,
                         backgroundColor: PassColor.interactionNormMinor1,
                         action: dismiss.callAsFunction)
        }
    }
}

//
// struct RoundedCorner: Shape {
//    var radius: CGFloat = .infinity
//    var corners: UIRectCorner = .allCorners
//
//    func path(in rect: CGRect) -> Path {
//        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
//                                cornerRadii: CGSize(width: radius, height: radius))
//        return Path(path.cgPath)
//    }
// }
//
// extension View {
//    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
//        clipShape(RoundedCorner(radius: radius, corners: corners))
//    }
// }
//
// struct CornerRadiusStyle: ViewModifier {
//    var radius: CGFloat
//    var corners: UIRectCorner
//
//    struct CornerRadiusShape: Shape {
//        var radius = CGFloat.infinity
//        var corners = UIRectCorner.allCorners
//
//        func path(in rect: CGRect) -> Path {
//            let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
//                                    cornerRadii: CGSize(width: radius, height: radius))
//            return Path(path.cgPath)
//        }
//    }
//
//    func body(content: Content) -> some View {
//        content
//            .clipShape(CornerRadiusShape(radius: radius, corners: corners))
//    }
// }
//
// extension View {
//    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
//        ModifiedContent(content: self, modifier: CornerRadiusStyle(radius: radius, corners: corners))
//    }
// }
