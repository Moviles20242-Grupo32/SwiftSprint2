//
//  ProfileView.swift
//  App13
//
//  Created by Juan Andres Jaramillo on 3/09/24.
//

import SwiftUI

struct ProfileView: View {
    
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var showPasswordPrompt: Bool = false
    @State private var password = ""
    @Environment(\.presentationMode) var present
    
    var body: some View {
        
        VStack{
            
            HStack{
                Button(action: {present.wrappedValue.dismiss()}){
                    Image(systemName: "chevron.left")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundColor(.orange)
                }
                Spacer()
                    .frame(width: 300)
            }
            if let user = viewModel.currentUser {
                List {
                    Section {
                        HStack {
                            Text(user.initials)
                                .font(.title)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(width: 72, height: 72)
                                .background(Color.orange)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4){
                                Text(user.fullname)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .padding(.top, 4)
                                
                                Text(user.email)
                                    .font(.footnote)
                                    .accentColor(.gray)
                            }
                            
                        }
                    }
                    Section("General"){
                        HStack(spacing: 12){
                            Image(systemName: "gear")
                                .imageScale(.small)
                                .font(.title)
                                .foregroundColor(Color(.systemGray))
                            
                            Text("Version")
                                .font(.subheadline)
                                .foregroundStyle(.black)
                            
                            Spacer()
                            
                            Text("1.0.0")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                    }
                    Section("Account"){
                        
                        VStack(alignment: .leading, spacing: 5){
                            
                            Button(action: {
                                viewModel.signOut()
                            }) {
                                HStack(spacing: 12){
                                    Image(systemName: "arrow.left.circle.fill")
                                        .imageScale(.small)
                                        .font(.title)
                                        .foregroundColor(Color(.systemRed))
                                    
                                    Text("Sign Out")
                                        .font(.subheadline)
                                        .foregroundStyle(.black)
                                    
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .background(Color(.systemGray6))
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
