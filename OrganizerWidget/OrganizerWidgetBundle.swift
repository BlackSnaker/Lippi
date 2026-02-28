//
//  OrganizerWidgetBundle.swift
//  OrganizerWidget
//
//  Created by Oleg on 07.09.2025.
//

import WidgetKit
import SwiftUI

@main
struct OrganizerWidgetBundle: WidgetBundle {
    var body: some Widget {
        OrganizerWidget()
        OrganizerWidgetControl()
        OrganizerWidgetLiveActivity()
    }
}
