// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import Foundation

/// Mock data provider for the travel app demo.
/// Provides sample travel destinations, itineraries, and hotel listings.
enum MockData {

    // MARK: - Inspiration Carousel

    static let inspirationCarousel = TravelCarouselData(
        title: "What kind of trip are you looking for?",
        items: [
            TravelCarouselItem(
                description: "Relaxing Beach Holiday",
                imageName: "assets/travel_images/santorini_panorama.jpg",
                listingSelectionId: nil,
                actionName: "selectExperience"
            ),
            TravelCarouselItem(
                description: "Cultural Exploration",
                imageName: "assets/travel_images/akrotiri_spring_fresco_santorini.jpg",
                listingSelectionId: nil,
                actionName: "selectExperience"
            ),
            TravelCarouselItem(
                description: "Adventure & Outdoors",
                imageName: "assets/travel_images/santorini_from_space.jpg",
                listingSelectionId: nil,
                actionName: "selectExperience"
            ),
            TravelCarouselItem(
                description: "Foodie Tour",
                imageName: "assets/travel_images/saffron_gatherers_fresco_santorini.jpg",
                listingSelectionId: nil,
                actionName: "selectExperience"
            ),
        ]
    )

    // MARK: - Information Card

    static let santoriniInfo = InformationCardData(
        title: "Santorini, Greece",
        subtitle: "Aegean Paradise",
        body: """
        Santorini is a stunning volcanic island in the Cyclades group of the \
        Greek islands. Known for its dramatic views, stunning sunsets from Oia, \
        blue-domed churches, and vibrant nightlife.

        **Best time to visit:** April to October
        **Average temperature:** 25°C (77°F) in summer
        **Currency:** Euro (€)
        **Language:** Greek
        """,
        imageName: "assets/travel_images/santorini_panorama.jpg"
    )

    // MARK: - Itinerary

    static let greeceItinerary = ItineraryData(
        title: "Greek Island Adventure",
        subheading: "7-Day Itinerary",
        imageName: "assets/travel_images/santorini_panorama.jpg",
        days: [
            ItineraryDayData(
                title: "Day 1",
                subtitle: "Arrival in Athens",
                description: "Arrive in Athens and settle into your hotel. Explore the Plaka neighborhood and enjoy dinner with a view of the Acropolis.",
                imageName: "assets/travel_images/akrotiri_spring_fresco_santorini.jpg",
                entries: [
                    ItineraryEntryData(
                        title: "Flight to Athens",
                        subtitle: "Direct flight",
                        bodyText: "Arrive at Athens International Airport (ATH). Transfer to hotel in Plaka district.",
                        address: "Athens International Airport",
                        time: "2:00 PM",
                        totalCost: nil,
                        type: .transport,
                        status: .choiceRequired
                    ),
                    ItineraryEntryData(
                        title: "Hotel Check-in",
                        subtitle: "Plaka District",
                        bodyText: "Check in to your boutique hotel in the heart of Plaka, Athens' oldest neighborhood.",
                        address: "Plaka, Athens",
                        time: "4:00 PM",
                        totalCost: "$180/night",
                        type: .accommodation,
                        status: .choiceRequired
                    ),
                    ItineraryEntryData(
                        title: "Dinner at Acropolis View Restaurant",
                        bodyText: "Enjoy traditional Greek cuisine with a stunning view of the illuminated Acropolis.",
                        address: "Dionysiou Areopagitou",
                        time: "8:00 PM",
                        totalCost: "$45",
                        type: .activity,
                        status: .noBookingRequired
                    ),
                ]
            ),
            ItineraryDayData(
                title: "Day 2",
                subtitle: "Athens Exploration",
                description: "Full day exploring the ancient wonders of Athens, including the Acropolis, Parthenon, and the National Archaeological Museum.",
                imageName: "assets/travel_images/akrotiri_spring_fresco_santorini.jpg",
                entries: [
                    ItineraryEntryData(
                        title: "Acropolis & Parthenon",
                        bodyText: "Guided tour of the Acropolis, including the Parthenon, Erechtheion, and Temple of Athena Nike.",
                        address: "Acropolis Hill, Athens",
                        time: "9:00 AM",
                        totalCost: "$25",
                        type: .activity,
                        status: .noBookingRequired
                    ),
                    ItineraryEntryData(
                        title: "Greek Food Tour",
                        bodyText: "Walking food tour through Athens' best street food spots, markets, and tavernas.",
                        address: "Central Athens",
                        time: "1:00 PM",
                        totalCost: "$65",
                        type: .activity,
                        status: .noBookingRequired
                    ),
                ]
            ),
            ItineraryDayData(
                title: "Day 3-5",
                subtitle: "Santorini",
                description: "Ferry to Santorini for three magical days exploring white-washed villages, volcanic beaches, and world-famous sunsets.",
                imageName: "assets/travel_images/santorini_panorama.jpg",
                entries: [
                    ItineraryEntryData(
                        title: "Ferry to Santorini",
                        subtitle: "High-speed catamaran",
                        bodyText: "Blue Star Ferries high-speed catamaran from Piraeus to Santorini. Duration: ~5 hours.",
                        time: "7:30 AM",
                        totalCost: "$85",
                        type: .transport,
                        status: .choiceRequired
                    ),
                    ItineraryEntryData(
                        title: "Hotel in Oia",
                        subtitle: "Caldera view suite",
                        bodyText: "3 nights at a cliffside hotel in Oia with stunning caldera views and a private hot tub.",
                        address: "Oia, Santorini",
                        time: "1:00 PM",
                        totalCost: "$450/night",
                        type: .accommodation,
                        status: .choiceRequired
                    ),
                    ItineraryEntryData(
                        title: "Sunset in Oia",
                        bodyText: "Watch the world-famous Oia sunset from the castle ruins. Arrive early for the best spot!",
                        address: "Oia Castle, Santorini",
                        time: "7:00 PM",
                        totalCost: nil,
                        type: .activity,
                        status: .noBookingRequired
                    ),
                ]
            ),
            ItineraryDayData(
                title: "Day 6-7",
                subtitle: "Mykonos & Departure",
                description: "Quick hop to Mykonos for beach time and nightlife before flying back home.",
                imageName: "assets/travel_images/kata_noi_beach_phuket_thailand.jpg",
                entries: [
                    ItineraryEntryData(
                        title: "Ferry to Mykonos",
                        bodyText: "Short ferry ride from Santorini to Mykonos (~2.5 hours).",
                        time: "10:00 AM",
                        totalCost: "$65",
                        type: .transport,
                        status: .choiceRequired
                    ),
                    ItineraryEntryData(
                        title: "Beach Day at Paradise Beach",
                        bodyText: "Relax at one of Mykonos' most famous beaches with crystal-clear waters.",
                        address: "Paradise Beach, Mykonos",
                        time: "2:00 PM",
                        totalCost: nil,
                        type: .activity,
                        status: .noBookingRequired
                    ),
                    ItineraryEntryData(
                        title: "Return Flight",
                        subtitle: "Via Athens",
                        bodyText: "Fly from Mykonos to Athens, then connect to your international flight home.",
                        time: "11:00 AM",
                        totalCost: nil,
                        type: .transport,
                        status: .choiceRequired
                    ),
                ]
            ),
        ]
    )

    // MARK: - Input Group (Trip Preferences)

    static let tripPreferencesInputGroup = InputGroupData(
        submitLabel: "Search Itineraries",
        children: [
            .optionsFilter(OptionsFilterChipData(
                id: "destination",
                chipLabel: "Destination",
                options: ["Greece", "Japan", "France", "Indonesia", "Mexico"],
                iconName: .location,
                value: "Greece"
            )),
            .optionsFilter(OptionsFilterChipData(
                id: "budget",
                chipLabel: "Budget",
                options: ["Budget ($)", "Moderate ($$)", "Luxury ($$$)"],
                iconName: .wallet,
                value: nil
            )),
            .optionsFilter(OptionsFilterChipData(
                id: "duration",
                chipLabel: "Duration",
                options: ["3 days", "5 days", "7 days", "10 days", "14 days"],
                iconName: .calendar,
                value: "7 days"
            )),
            .optionsFilter(OptionsFilterChipData(
                id: "travelers",
                chipLabel: "Travelers",
                options: ["Solo", "Couple", "Family", "Group (3-5)", "Group (6+)"],
                iconName: .people,
                value: nil
            )),
            .dateInput(DateInputChipData(
                id: "check_in",
                value: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
                label: "Check-in"
            )),
            .dateInput(DateInputChipData(
                id: "check_out",
                value: Calendar.current.date(byAdding: .day, value: 37, to: Date()),
                label: "Check-out"
            )),
            .checkboxFilter(CheckboxFilterChipsData(
                id: "activities",
                chipLabel: "Activities",
                options: ["Beach", "History", "Food", "Nightlife", "Nature", "Shopping"],
                iconName: nil,
                selectedOptions: ["Beach", "Food"]
            )),
        ],
        actionName: "searchItineraries"
    )

    // MARK: - Trailhead (Suggestions)

    static let postItinerarySuggestions = TrailheadData(
        topics: [
            "Book hotels for this trip",
            "Find flights to Athens",
            "Local cuisine recommendations",
            "Best beaches in Santorini",
            "Day trips from Athens",
            "Travel insurance options",
        ],
        actionName: "selectTopic"
    )

    // MARK: - Hotel Listings (matching Flutter's BookingService)

    static let hotelListings: [HotelListing] = {
        let calendar = Calendar.current
        let checkIn = calendar.date(byAdding: .day, value: 5, to: Date())!
        let checkOut = calendar.date(byAdding: .day, value: 7, to: checkIn)!
        return [
            HotelListing(
                id: "hotel_1",
                listingSelectionId: "sel_001",
                name: "The Dart Inn",
                location: "Sunnyvale, CA",
                pricePerNight: 150,
                imageName: "assets/booking_service/dart_inn.png",
                checkIn: checkIn,
                checkOut: checkOut,
                guests: 2
            ),
            HotelListing(
                id: "hotel_2",
                listingSelectionId: "sel_002",
                name: "The Flutter Hotel",
                location: "Mountain View, CA",
                pricePerNight: 250,
                imageName: "assets/booking_service/flutter_hotel.png",
                checkIn: checkIn,
                checkOut: checkOut,
                guests: 2
            ),
        ]
    }()

    static let listingsBooker = ListingsBookerData(
        itineraryName: "Dart and Flutter deep dive",
        listings: Array(hotelListings.prefix(2))
    )
}
