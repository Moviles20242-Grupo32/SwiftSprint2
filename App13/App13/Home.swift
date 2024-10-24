//
//  Home.swift
//  App13
//
//  Created by Daniela Uribe on 28/08/24.
//

import SwiftUI
import AVFoundation
import Combine
import FirebaseAnalytics

struct Home: View {
    @State private var synthesizer: AVSpeechSynthesizer?
    @StateObject var HomeModel = HomeViewModel.shared
    @State private var searchDebounceTimer: AnyCancellable?
    @State private var typingStartTime: TimeInterval?
    @State var searchStartTime: TimeInterval?
    @StateObject var LocationModel = LocationViewModel.shared
    @State private var showHighRatedItems = false
    
    var body: some View {
        
        NavigationView{
//            ZStack(alignment: .leading){
                VStack(spacing:10){
                    
                    ZStack {
                        // Gradient background with a rounded rectangle
                        RoundedRectangle(cornerRadius: 15)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.orange.opacity(1), Color.orange.opacity(0.5)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 350, height: 50)
                            .shadow(color: .gray.opacity(0.4), radius: 10, x: 0, y: 4) // Softer shadow for depth

                        // Text and icon
                        HStack {

                            // Centered Text
                            Text("¡Come por menos con Foodies!")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(red: 69/255.0, green: 39/255.0, blue: 13/255.0))
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .padding(.horizontal, 12)

                        }
                        .padding(.vertical, 8)
                    }

                    
                    HStack(spacing:5){
                        
                        // Carrito de compras
                        NavigationLink(destination: {
                            CartView(homeData: HomeModel, initialTime: searchStartTime ?? 0)
                        }, label: {
                            Image(systemName: "cart")
                                .font(.title)
                                .foregroundColor(Color(.orange))
                        })
                        .padding(10)
                        
                        // Text to Speach
                        Button(action:{
                            var elementsString: String {
                                HomeModel.filtered.map { $0.item_name }.joined(separator: " ")
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
                            
                        }).padding(10)
                        
                        
                        // Profile
                        NavigationLink(destination: {
                            ProfileView()
                        }, label: {
                            Image(systemName: "person.crop.circle")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            
                        }).padding(10)
                        
                    }
                    .padding([.horizontal, .top], 2)
                    
                    //Ubicacion
                    HStack{
                        
                        if LocationModel.userLocation == nil{
                            Text("Localizando...")
                                .foregroundColor(.black)
                                .frame(width: 110)
                        }
                        else{
                            Image(systemName: "location.fill")
                                .font(.title2)
                                .foregroundColor(Color(red: 49/255.0, green: 67/255.0, blue: 65/255.0))
                        }
                        
                        Text(LocationModel.userAddress)
                            .font(.caption)
                            .fontWeight(.heavy)
                            .foregroundColor(Color(red: 49/255.0, green: 67/255.0, blue: 65/255.0))
                    }
                    
                    HStack{
                        
                        HStack(spacing: 15){
                            
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                                .foregroundColor(Color(red: 143/255.0, green: 120/255.0, blue: 111/255.0))
                            
                            TextField("", text: $HomeModel.search)
                                .foregroundColor(Color(red: 143/255.0, green: 120/255.0, blue: 111/255.0))
                                .padding(.vertical, 10)
                                .onChange(of: HomeModel.search) { newValue in
                                    searchDebounceTimer?.cancel()
                                    
                                    // Start a new debounce timer
                                    searchDebounceTimer = Just(newValue)
                                        .delay(for: .seconds(0.8), scheduler: RunLoop.main)
                                        .sink { finalValue in
                                            if !finalValue.isEmpty {
                                                // Log the event after 0.8 seconds of inactivity
                                                Analytics.logEvent("search_completed", parameters: [
                                                    "search_term": finalValue
                                                ])
                                                print("Event logged: search_term = \(finalValue)")
                                                
                                                HomeModel.saveSearchUse(finalValue: finalValue)
                                            }
                                        }
                            }
                        }
                        .padding(.horizontal)
                        .background(
                            RoundedRectangle(cornerRadius: 10) // Adjust corner radius as needed
                                .fill(Color.white) // Background color of the rectangle
                                .shadow(color: Color(red: 143/255.0, green: 120/255.0, blue: 111/255.0), radius: 5, x: 0, y: 2) // Shadow parameters
                        )
                        .padding(.leading, 20)
                        .padding(.top,10)
                        
                        Button(action: {
                            // Toggle the filter state
                            showHighRatedItems.toggle()
                            
                            // Call the filter function in the HomeViewModel
                            HomeModel.filterHighRatedItems(showHighRated: showHighRatedItems)
                            
                            HomeModel.saveStarFilterUse()
                        }) {
                            Image(systemName: "star.fill")
                                .resizable()  // Make the image resizable
                                .aspectRatio(contentMode: .fit)  // Maintain the aspect ratio
                                .frame(width: 15, height: 15)  // Set the width and height
                                .foregroundColor(.white)
                                .padding(10)
                                .background(showHighRatedItems ? Color(red: 49/255.0, green: 67/255.0, blue: 65/255.0) : Color.orange)
                                .clipShape(Circle())
                        }
                        .padding(10)
                        .padding(.top,10)
                    }
                    
                    
                    if HomeModel.items.isEmpty{
                        
                        Spacer()
                        
                        ProgressView()
                        
                        Spacer()
                        
                    }
                    else{
                        ScrollView(.vertical, showsIndicators: false, content: {
                            VStack(spacing:5){
                                ForEach(HomeModel.filtered){item in
                                    HStack{
                                        
                                        ItemView(item: item, favoriteName: HomeModel.favorite?.item_name ?? "")
                                            .padding(15)
                                        
                                        Spacer()
                                            .frame(width: 10)
                                        
                                        Button(action: {
                                            searchStartTime = Date().timeIntervalSince1970
                                            Analytics.logEvent("product_selection_started", parameters: [
                                                "timestamp": searchStartTime.map { NSNumber(value: $0) } ?? NSNumber(value: 0)
                                            ])
                                            
                                            HomeModel.addToCart(item: item)
                                        }, label: {
                                            Image(systemName: item.isAdded ? "checkmark" : "plus")
                                                .resizable()  // Make the image resizable
                                                .aspectRatio(contentMode: .fit)  // Maintain the aspect ratio
                                                .frame(width: 10, height: 10)  // Set the width and height
                                                .foregroundColor(.white)
                                                .padding(10)
                                                .background(item.isAdded ? Color(red: 49/255.0, green: 67/255.0, blue: 65/255.0) : Color.orange)
                                                .clipShape(Circle())
                                        })
                                    }
                                    .padding(.trailing, 10)
                                }
                            }
                            .padding(.top, 10)
                        })
                    }
                    
                    
                }
                
//                if HomeModel.noLocation{
//                    Text("Por favor active el acceso a su ubicación en configuración para continuar !!!")
//                        .foregroundColor(.black)
//                        .frame(width: UIScreen.main.bounds.width - 100, height: 120)
//                        .cornerRadius(10)
//                        .frame(maxWidth: .infinity, maxHeight: .infinity)
//                        .background(Color.black.opacity(0.3).ignoresSafeArea())
//                    
//                    
//                }
//            }
        }
        .navigationBarHidden(true)
        .edgesIgnoringSafeArea(.top)
        .onAppear(perform: {
            HomeModel.locationManager.delegate = HomeModel
            LocationModel.requestNotificationPermission()
        })
        .onChange(of: HomeModel.search, perform:{ value in
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3){
                
                if value == HomeModel.search && HomeModel.search != ""{
                    HomeModel.filterData()
                }
                else if HomeModel.search == "" &&  showHighRatedItems == true{
                    withAnimation(.linear) {HomeModel.filterHighRatedItems(showHighRated:showHighRatedItems)}
                }
                else if HomeModel.search == ""{
                    withAnimation(.linear) { HomeModel.filtered = HomeModel.items}
                }
            }
        })
    }
    
    var filteredItems: [Item] {
        if showHighRatedItems {
            return HomeModel.filtered.filter { $0.item_ratings == "4" || $0.item_ratings == "5" }
        } else {
            return HomeModel.filtered
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
        
        let speechUtterance = AVSpeechUtterance(string: "Las cajas disponibles son " + elements)
        speechUtterance.voice = AVSpeechSynthesisVoice(language: "es-MX")
        
        synthesizer?.speak(speechUtterance)
    }
}
