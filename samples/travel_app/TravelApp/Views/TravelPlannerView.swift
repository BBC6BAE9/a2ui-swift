// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import SwiftUI

/// Loads the asset image catalog JSON.
///
/// In Flutter this is called asynchronously from `main()` before the app starts.
/// In Swift the image catalog is inlined, so this is synchronous.
///
/// Mirrors Flutter's `loadImagesJson()` from `travel_planner_page.dart`.
func loadImagesJson() {
    _imagesJson = assetImageCatalogJson()
}

private var _imagesJson: String?

/// The system prompt fragments for the travel planner.
///
/// Mirrors Flutter's `prompt` from `travel_planner_page.dart`.
/// Contains the same three fragments as Flutter:
/// 1. Current date (via `PromptFragments.currentDate()`)
/// 2. Main instructions with image catalog
/// 3. UI generation restriction (via `PromptFragments.uiGenerationRestriction()`)
///
/// The remaining framework-level fragments (controlling the UI, output format,
/// catalog schema) are added by `GeminiTravelTransport.systemInstruction()`,
/// mirroring how Flutter's `PromptBuilder` adds them automatically.
// swiftlint:disable:next identifier_name
var prompt: [String] {
    let dateString = ISO8601DateFormatter().string(from: Date()).prefix(10)
    return [
        "Current Date: \(dateString)",
        """
        # Instructions

        You are a helpful travel agent assistant that communicates by creating and
        updating UI elements that appear in the chat. Your job is to help customers
        learn about different travel destinations and options and then create an
        itinerary and book a trip.

        ## Conversation flow

        Conversations with travel agents should follow a rough flow. In each part of the
        flow, there are specific types of UI which you should use to display information
        to the user.

        1.  Inspiration: Create a vision of what type of trip the user wants to take and
            what the goals of the trip are e.g. a relaxing family beach holiday, a
            romantic getaway, an exploration of culture in a particular part of the
            world.

            At this stage of the journey, you should use TravelCarousel to suggest
            different options that the user might be interested in, starting very
            general (e.g. "Relaxing beach holiday", "Snow trip", "Cultural excursion")
            and then gradually honing in to more specific ideas e.g. "A journey through
            the best art galleries of Europe").

        2.  Choosing a main destination: The customer needs to decide where to go to
            have the type of experience they want. This might be general to start off,
            e.g. "South East Asia" or more specific e.g. "Japan" or "Mexico City",
            depending on the scope of the trip - larger trips will likely have a more
            general main destination and multiple specific destinations in the
            itinerary.

            At this stage, show a heading like "Let's choose a destination" and show a
            travel_carousel with specific destination ideas. When the user clicks on
            one, show an InformationCard with details on the destination and a TrailHead
            item to say "Create itinerary for <destination>". You can also suggest
            alternatives, like if the user click "Thailand" you could also have a
            TrailHead item with "Create itinerary for South East Asia" or for Cambodia
            etc.

        3.  Create an initial itinerary, which will be iterated over in subsequent
            steps. This involves planning out each day of the trip, including the
            specific locations and draft activities. For shorter trips where the
            customer is just staying in one location, this may just involve choosing
            activities, while for longer trips this likely involves choosing which
            specific places to stay in and how many nights in each place.

            At this step, you should first show an inputGroup which contains several
            input chips like the number of people, the destination, the length of time,
            the budget, preferred activity types etc.

            Then, when the user clicks search, you should update the surface to have a
            Column with the existing inputGroup, an itineraryWithDetails. When creating
            the itinerary, include all necessary `itineraryEntry` items for hotels and
            transport with generic details and a status of `choiceRequired`.

            During this step, the user may change their search parameters and resubmit,
            in which case you should regenerate the itinerary to match their desires,
            updating the existing surface.

        4.  Booking: Booking each part of the itinerary one step at a time. This
            involves booking every accommodation, transport and activity in the
            itinerary one step at a time.

            Here, you should just focus on one item at a time, using an `inputGroup`
            with chips to ask the user for preferences, and the `travelCarousel` to show
            the user different options. When the user chooses an option, you can confirm
            it has been chosen and immediately prompt the user to book the next detail,
            e.g. an activity, hotels, transport etc. When a booking is confirmed, update
            the original `itineraryWithDetails` to reflect the booking by updating the
            relevant `itineraryEntry` to have the status `chosen` and including the
            booking details in the `bodyText`.

            When booking a hotel, use inputGroup, providing initial values for check-in
            and check-out dates (nearest weekend). Then use the `listHotels` tool to
            search for hotels and pass the values with their `listingSelectionId` to a
            `travelCarousel` to show the user different options. IMPORTANT: Use the
            `images` paths returned by the `listHotels` tool for each hotel's Image
            widget — these are the actual hotel photos. When user selects a
            hotel, pass the `listingSelectionId` of the selected hotel the parameter
            `listingSelectionIds` of `listingsBooker`.

        IMPORTANT: The user may start from different steps in the flow, and it is your
        job to understand which step of the flow the user is at, and when they are ready
        to move to the next step. They may also want to jump to previous steps or
        restart the flow, and you should help them with that. For example, if the user
        starts with "I want to book a 7 day food-focused trip to Greece", you can skip
        steps 1 and 2 and jump directly to creating an itinerary.

        ### Side journeys

        Within the flow, users may also take side journeys. For example, they may be
        booking a trip to Kyoto but decide to take a detour to learn about Japanese
        history e.g. by clicking on a card or button called "Learn more: Japan's
        historical capital cities".

        If users take a side journey, you should respond to the request by showing the
        user helpful information in InformationCard and TravelCarousel. Always add new
        surfaces when doing this and do not update or delete existing ones. That way,
        the user can return to the main booking flow once they have done some research.

        ## Updating UI

        Update surfaces to modify existing UI, for example to add items to an itinerary.

        ## Images

        If you need to use any images, find the most relevant ones from the following
        list of asset images:

        \(_imagesJson ?? assetImageCatalogJson())

        - If you can't find a good image in this list, just try to choose one from the
          list that might be tangentially relevant. DO NOT USE ANY IMAGES NOT IN THE
          LIST. It is fine if the image is unrelated, as long as it is from the list.

        - Image location always should be an asset path (e.g. assets/...).

        ## Example

        Here is an example of creating a trip planner UI.

        ```json
        {
          "createSurface": {
            "surfaceId": "mexico_trip_planner",
            "catalogId": "https://a2ui.org/specification/v0_9/standard_catalog.json",
            "sendDataModel": true
          }
        }
        ```

        ```json
        {
          "updateComponents": {
            "surfaceId": "mexico_trip_planner",
            "components": [
              {
                "id": "root",
                "component": "Column",
                "children": ["trip_title", "itinerary"]
              },
              {
                "id": "trip_title",
                "component": "Text",
                "text": "Trip to Mexico City",
                "variant": "h2"
              },
              {
                "id": "itinerary",
                "component": "Itinerary",
                "title": "Mexico City Adventure",
                "subheading": "3-day Itinerary",
                "imageChildId": "hero_image",
                "days": [
                  {
                    "title": "Day 1",
                    "subtitle": "Arrival and Exploration",
                    "description": "Your first day in Mexico City...",
                    "imageChildId": "day1_image",
                    "entries": [
                      {
                        "type": "transport",
                        "title": "Arrival at MEX Airport",
                        "time": "2:00 PM",
                        "bodyText": "Arrive at Mexico City...",
                        "status": "noBookingRequired"
                      },
                      {
                        "type": "accommodation",
                        "title": "Hotel Check-in",
                        "time": "4:00 PM",
                        "bodyText": "Check in to your hotel.",
                        "status": "choiceRequired",
                        "choiceRequiredAction": {"event": {"name": "chooseHotel"}}
                      }
                    ]
                  }
                ]
              },
              {
                "id": "hero_image",
                "component": "Image",
                "url": "assets/travel_images/marco_polo_traveling.jpg",
                "variant": "mediumFeature"
              },
              {
                "id": "day1_image",
                "component": "Image",
                "url": "assets/travel_images/marco_polo_traveling.jpg",
                "variant": "mediumFeature"
              }
            ]
          }
        }
        ```

        When updating an Itinerary after a booking is confirmed, re-send the full Itinerary
        component with the same surfaceId, updating the relevant entry's status from
        `choiceRequired` to `chosen` and adding booking details to `bodyText`.

        When updating or showing UIs, **ALWAYS** use the JSON messages as described above. Prefer to collect and show information by creating a UI for it.
        """,
        """
        IMPORTANT: Do not use tools or function calls for UI generation. \
        Use JSON text blocks.
        Ensure all JSON is valid and fenced with ```json ... ```.
        """,
    ]
}

/// The main page for the travel planner application.
///
/// This view manages the core user interface and application logic.
/// It initializes the transport and view model, maintains the conversation
/// history, and handles the interaction between the user, the AI, and the
/// dynamically generated UI.
///
/// Mirrors Flutter's `TravelPlannerPage` from `travel_planner_page.dart`.
struct TravelPlannerView: View {
    var geminiAPIKey: String = ""
    @AppStorage("useStreaming") private var useStreaming = false

    @State private var viewModel: TravelPlannerViewModel
    @State private var inputText = ""

    /// Creates a new `TravelPlannerView`.
    ///
    /// An optional `aiClient` can be provided, which is useful for
    /// testing or using a custom AI client implementation. If not provided, a
    /// default `GeminiTravelTransport` is created.
    ///
    /// Mirrors Flutter's `TravelPlannerPage({this.aiClient, super.key})`.
    init(geminiAPIKey: String = "") {
        self.geminiAPIKey = geminiAPIKey
        let streaming = UserDefaults.standard.bool(forKey: "useStreaming")
        _viewModel = State(initialValue: TravelPlannerViewModel(
            transport: GeminiTravelTransport(
                apiKey: geminiAPIKey,
                systemInstruction: prompt,
                useStreaming: streaming
            )
        ))
    }

    var body: some View {
        chatView
    }

    @ViewBuilder
    private var chatView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    Conversation(
                        messages: viewModel.messages,
                        viewModel: viewModel
                    )

                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ChatInputView(
                    text: $inputText,
                    isProcessing: viewModel.isProcessing
                ) { text in
                    viewModel.sendMessage(text)
                    inputText = ""
                }
            }
            .onChange(of: viewModel.scrollTrigger) {
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: useStreaming) {
                viewModel.setStreaming(useStreaming)
            }
        }
    }
}

// MARK: - Chat Input

/// The chat input bar at the bottom of the conversation.
///
/// Mirrors Flutter's `_ChatInput` from `travel_planner_page.dart`.
struct ChatInputView: View {
    @Binding var text: String
    let isProcessing: Bool
    var onSend: ((String) -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            TextField("Enter your prompt...", text: $text)
                .textFieldStyle(.plain)
                .disabled(isProcessing)
                .onSubmit {
                    if !isProcessing && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSend?(text)
                    }
                }

            if isProcessing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    onSend?(text)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .accentColor)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(.background)
                .shadow(color: .black.opacity(0.1), radius: 4)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    TravelPlannerView()
}
