//
//  TestData.swift
//  Apple Music
//
//  Created by Justin Bush on 2020-03-04.
//  Copyright © 2020 Justin Bush. All rights reserved.
//

import Foundation

struct TestData {
    
    var items: [Item]
    
    init() {
        /*
        items = ["Styles": ["Light", "Vibrant Light", "Dark", "Vibrant Dark", "Vibrant", "Frosty", "Default"],
                 "Themes": ["Wave", "Spring", "Bubbles", "Dunes", "Quartz"],
                 "Custom": ["Select Image"]]
        */
        
        let titles = ["Styles", "Themes"]
        let styles = ["Light", "Vibrant Light", "Dark", "Vibrant Dark", "Vibrant", "Frosty", "Default"]
        let themes = ["Wave", "Spring", "Bubbles", "Dunes", "Quartz"]
        
        items = []
        let group = Item("Preferences", .Group)
        for g in titles {
            let item = Item("\(g)", .Container)
            if g == "Styles" {
                for f in styles {
                    let node = Item("\(f)", .Node)
                    item.children.append(node)
                }
            } else {
                for n in themes {
                    let node = Item("\(n)", .Node)
                    item.children.append(node)
                }
            }
            group.children.append(item)
        }
        items.append(group)
        
        /*
        items = []
        for g in 1...3 {
            let group = Item("Group \(g)", .Group)
            for f in 1...3 {
                let item = Item("Folder \(g).\(f)", .Container)
                for n in 1...4 {
                    let node = Item("Node \(g).\(f).\(n)", .Node)
                    item.children.append(node)
                }
                group.children.append(item)
            }
            items.append(group)
         }
        */
    }
}

