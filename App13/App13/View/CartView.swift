//
//  CartView.swift
//  App13
//
//  Created by Daniela Uribe on 2/09/24.
//

import SwiftUI
import SDWebImageSwiftUI
import AVFoundation
import FirebaseAnalytics

struct CartView: View {
    
    @StateObject var homeData = HomeViewModel.shared
    @State private var synthesizer: AVSpeechSynthesizer?
    @Environment(\.presentationMode) var present
    var initialTime: TimeInterval
    
    var body: some View {
        VStack{
            
                HStack{
                    
                    Button(action: {present.wrappedValue.dismiss()}){
                        Image(systemName: "chevron.left")
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundColor(.orange)
                    }.padding()
                
                    Spacer()
                    
                    Button(action:{
                        var elementsString: String {
                            homeData.cartItems.map { $0.item.item_name }.joined(separator: " ")
                        }
                        speak(elements: " " + elementsString)
                    },
                           label: {
                        Image(systemName: "megaphone")
                            .resizable()
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .padding(13)
                            .background(Color(red: 49/255.0, green: 67/255.0, blue: 65/255.0))
                            .clipShape(Circle())
                        
                    }).padding(.trailing, 175)
                    
                    
                
                }
            
            HStack(spacing: 20){
                
                Text("Carrito")
                    .font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/)
                    .fontWeight(.heavy)
                    .foregroundColor(Color(red: 69/255.0, green: 39/255.0, blue: 13/255.0))
                
                Spacer()
            }
            .padding()
            
            ScrollView(.vertical, showsIndicators: false){
                LazyVStack(spacing:0){
                    ForEach(homeData.cartItems){cart in
                        
                        HStack(spacing: 15){
                            WebImage(url: URL(string:cart.item.item_image))
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 130, height: 130)
                                .cornerRadius(15)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                Text(cart.item.item_name)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color(red: 69/255.0, green: 39/255.0, blue: 13/255.0))
                                
                                Text(cart.item.item_details)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color(red: 143/255.0, green: 120/255.0, blue: 111/255.0))
                                    .lineLimit(2)
                                
                                HStack(spacing: 10){
                                    Text(homeData.getPrice(value: Float(truncating: cart.item.item_cost)))
                                        .font(.title2)
                                        .fontWeight(.heavy)
                                        .foregroundColor(Color(red: 69/255.0, green: 39/255.0, blue: 13/255.0))
                                    
                                    Spacer(minLength: 0)
                                    
                                    Button(action: {
                                        if cart.quantity > 1 {homeData.incrementDecrementItemQuantity(index: homeData.getIndex(item: cart.item, isCartIndex: true), operation: "-")}
                                    }){
                                        Image(systemName: "minus")
                                            .font(.system(size: 16, weight: .heavy))
                                            .foregroundColor(Color(red: 69/255.0, green: 39/255.0, blue: 13/255.0))
                                    }
                                    
                                    Text("\(cart.quantity)")
                                        .fontWeight(.heavy)
                                        .foregroundColor(Color(red: 143/255.0, green: 120/255.0, blue: 111/255.0))
                                        .padding(.vertical, 5)
                                        .padding(.horizontal,10)
                                        .background(Color(red: 143/255.0, green: 120/255.0, blue: 111/255.0).opacity(0.06))
                                    
                                    Button(action: {
                                        homeData.incrementDecrementItemQuantity(index: homeData.getIndex(item: cart.item, isCartIndex: true), operation: "+")
                                    }){
                                        
                                        Image(systemName: "plus")
                                            .font(.system(size: 16,weight: .heavy))
                                            .foregroundColor(Color(red: 69/255.0, green: 39/255.0, blue: 13/255.0))
                                    }
                                }
                                
                            }
                        }
                        .padding()
                        .contextMenu{
                            
                            Button(action: {
                                let index = homeData.getIndex(item: cart.item, isCartIndex: true)
                                let itemIndex = homeData.getIndex(item: cart.item, isCartIndex: false)
                                
                                homeData.items[itemIndex].isAdded = false
                                homeData.filtered[itemIndex].isAdded = false
                                
                                CartCache.shared.removeCartItem(byId: homeData.cartItems[index].id)
                                homeData.cartItems.remove(at: index)
                                
                            }){
                                Text("Eliminar")
                                    .foregroundColor(Color(red: 69/255.0, green: 39/255.0, blue: 13/255))
                            }
                            
                        }
                        
                        
                    }
                }
            }
            
            VStack{
                HStack{
                    Text("Total")
                        .fontWeight(.heavy)
                        .foregroundColor(Color(red: 69/255.0, green: 39/255.0, blue: 13/255.0))
                    
                    Spacer()
                    
                    Text(homeData.calculateTotalPrice())
                        .font(.title)
                        .fontWeight(.heavy)
                        .foregroundColor(Color(red: 69/255.0, green: 39/255.0, blue: 13/255.0))
                }
                .padding([.top,.horizontal])
                
                Button(action: {

                    let elapsedTime = Date().timeIntervalSince1970 - initialTime
                    Analytics.logEvent("time_to_checkout", parameters: [
                        "elapsed_time": NSNumber(value: elapsedTime)
                    ])
//                    print("DEBUG BQ: \(elapsedTime)")
//                    print("DEBUG: startime: \(initialTime)")
                    
                    Analytics.logEvent("proceed_to_checkout", parameters: [
                        "timestamp": NSNumber(value: Date().timeIntervalSince1970)
                    ])
                    // Check if location services are disabled
                    if homeData.noLocation {
                        // Show alert to enable location services
                        homeData.alertMessage = "Para continuar con el pedido, por favor activa la localización."
                        homeData.showLocationAlert = true
                    } else {
                        // Proceed with order update
                        print("Actualizando")
                        homeData.updateOrder()
                    }
                    
                }){
                    Text("Check out")
                        .font(.title2)
                        .fontWeight(.heavy)
                        .foregroundColor(.white)
                        .padding(.vertical)
                        .frame(width: UIScreen.main.bounds.width - 30)
                        .background(
                            Color(red: 49/255.0, green: 67/255.0, blue: 65/255.0)
                        )
                        .cornerRadius(15)
                }
            }
            .background(Color.white)
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .alert(isPresented: $homeData.showAlert) {
                    Alert(title: Text("Error de conexión"), message: Text(homeData.alertMessage), dismissButton: .default(Text("OK")))
                }
        .alert(isPresented: $homeData.showLocationAlert) {
            Alert(
                title: Text("Localización Requerida"),
                message: Text(homeData.alertMessage),
                primaryButton: .default(Text("Ajustes")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                },
                secondaryButton: .cancel(Text("OK"))
            )
        }
    }
    
    func speak(elements: String) {
        
        let audioSession = AVAudioSession() // 2) handle audio session first, before trying to read the text
        do {
            try audioSession.setCategory(.playback, mode: .default, options: .duckOthers)
            try audioSession.setActive(false)
        } catch let error {
            print("❓", error.localizedDescription)
        }
        
        synthesizer = AVSpeechSynthesizer()
        
        let speechUtterance = AVSpeechUtterance(string: "Las cajas agregadas al carrito son " + elements)
        speechUtterance.voice = AVSpeechSynthesisVoice(language: "es-MX")
        
        synthesizer?.speak(speechUtterance)
    }
}

