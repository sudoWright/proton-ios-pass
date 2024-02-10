//
// CircleButton.swift
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

import SwiftUI

public enum CircleButtonType {
    case small, regular, big

    var width: CGFloat {
        switch self {
        case .small:
            36
        case .regular:
            40
        case .big:
            48
        }
    }

    var iconWidth: CGFloat {
        switch self {
        case .small:
            16
        case .regular:
            20
        case .big:
            20
        }
    }
}

/// A cirle button with an icon inside.
public struct CircleButton: View {
    @Environment(\.isEnabled) private var isEnabled
    let icon: UIImage
    let iconColor: UIColor
    let backgroundColor: UIColor
    let type: CircleButtonType
    let action: (() -> Void)?

    public init(icon: UIImage,
                iconColor: UIColor,
                backgroundColor: UIColor,
                type: CircleButtonType = .regular,
                action: (() -> Void)? = nil) {
        self.icon = icon
        self.iconColor = iconColor
        self.backgroundColor = backgroundColor
        self.type = type
        self.action = action
    }

    public var body: some View {
        if let action {
            Button(action: action) {
                realBody
            }
        } else {
            realBody
        }
    }

    private var realBody: some View {
        ZStack {
            Color(uiColor: isEnabled ? backgroundColor : PassColor.backgroundWeak)
                .clipShape(Circle())

            Image(uiImage: icon)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundColor(isEnabled ? Color(uiColor: iconColor) : PassColor.textDisabled.toColor)
                .frame(width: type.iconWidth, height: type.iconWidth)
        }
        .frame(width: type.width, height: type.width)
    }
}
