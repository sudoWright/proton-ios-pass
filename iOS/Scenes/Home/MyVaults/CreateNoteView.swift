//
// CreateNoteView.swift
// Proton Pass - Created on 07/07/2022.
// Copyright (c) 2022 Proton Technologies AG
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

import ProtonCore_UIFoundations
import SwiftUI
import UIComponents

struct CreateNoteView: View {
    @StateObject private var viewModel: CreateNoteViewModel

    init(viewModel: CreateNoteViewModel) {
        _viewModel = .init(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                TitledTextField(title: "Note name",
                                text: $viewModel.name,
                                placeholder: "Title",
                                isRequired: false)
                TitledTextField(title: "Note",
                                text: $viewModel.name,
                                placeholder: "Add note",
                                isRequired: false)
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: viewModel.cancelAction) {
                        Text("Cancel")
                    }
                    .foregroundColor(Color(.label))
                }

                ToolbarItem(placement: .principal) {
                    Text("Create new note")
                        .fontWeight(.bold)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: viewModel.saveAction) {
                        Text("Save")
                            .fontWeight(.bold)
                            .foregroundColor(Color(ColorProvider.BrandNorm))
                    }
                }
            }
        }
    }
}

struct CreateNoteView_Previews: PreviewProvider {
    static var previews: some View {
        CreateNoteView(viewModel: .preview)
    }
}
