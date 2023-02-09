//
// NoteSection.swift
// Proton Pass - Created on 03/02/2023.
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

import Client
import ProtonCore_UIFoundations
import SwiftUI
import UIComponents

/// Note section of item detail pages
struct NoteSection: View {
    @State private var isShowingFullNote = false
    let itemContent: ItemContent

    var body: some View {
        HStack(spacing: kItemDetailSectionPadding) {
            ItemDetailSectionIcon(icon: IconProvider.note,
                                  color: itemContent.tintColor)

            VStack(alignment: .leading, spacing: kItemDetailSectionPadding / 4) {
                Text("Note")
                    .sectionTitleText()

                if itemContent.note.isEmpty {
                    Text("Empty note")
                        .placeholderText()
                } else {
                    Text(itemContent.note)
                        .sectionContentText()
                        .lineLimit(10)
                        .textSelection(.enabled)
                        .onTapGesture {
                            // Pure heuristic
                            if itemContent.note.count > 400 {
                                isShowingFullNote.toggle()
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(kItemDetailSectionPadding)
        .roundedDetail()
        .sheet(isPresented: $isShowingFullNote) {
            FullNoteView(itemContent: itemContent)
        }
    }
}

private struct FullNoteView: View {
    @Environment(\.dismiss) private var dismiss
    let itemContent: ItemContent

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading) {
                    ItemDetailTitleView(itemContent: itemContent)
                        .padding(.bottom)
                    Text("Note")
                        .font(.callout)
                        .foregroundColor(.textWeak)
                    Text(itemContent.note)
                        .textSelection(.enabled)
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    CircleButton(icon: IconProvider.chevronDown,
                                 color: itemContent.tintColor,
                                 action: dismiss.callAsFunction)
                }
            }
        }
    }
}
