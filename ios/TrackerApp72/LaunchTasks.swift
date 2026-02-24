//
//  LaunchTasks.swift
//  TrackerApp72
//
//  Initializes NowYouSeeReact view tracking before UI is created.
//

import Foundation
import NowYouSeeMe
import NowYouSeeReact

@objc class LaunchTasks: NSObject {
    @objc static func perform() {
        NowYou.seeReact()
    }
}
