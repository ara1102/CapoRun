//
//  MainMenu.swift
//  CapoRun
//
//  Created by Samuel Bonardo on 28/06/26.
//

import SwiftUI

struct MainMenu: View {
    var body: some View {
        ZStack {
            Image("MainMenuBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Image("MainMenuLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300)
                
                VStack(spacing: 18) {
                    Button {
                        //function
                    } label: {
                        Image("PlayButton")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220)
                    }
                    Button {
                        //function
                    } label: {
                        Image("TutorialButton")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220)
                    }
                    Button {
                        //function
                    } label: {
                        Image("SettingButton")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220)
                    }
                }
                .frame(maxWidth: 260)
                .padding(.horizontal, 30)
            }
        }
    }
}


#Preview {
    MainMenu()
}
