//
//  SharedComponents.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//
//
//  SharedComponents.swift
//  Smart_Notes_App_ios
//

import SwiftUI
import MapKit
import CoreLocation
import Combine

// MARK: - Real MapKit Search Autocomplete + Offline Coordinate Cache
struct RealPlaceSuggestion: Identifiable, Hashable {
    var id: String { "\(title)|\(subtitle)" }
    let title: String
    let subtitle: String
}

@MainActor
final class LocationSearchHelper: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [RealPlaceSuggestion] = []
    @Published var pickedCoordinate = CLLocationCoordinate2D(latitude: 33.6844, longitude: 73.0479)
    @Published var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.6844, longitude: 73.0479),
            span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
        )
    )

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address, .query]
        // Centered on Islamabad / Rawalpindi, Pakistan
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.6600, longitude: 73.0650),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
    }

    func updateQuery(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            suggestions = []
        } else {
            completer.queryFragment = trimmed
        }
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let items = completer.results.prefix(5).map {
            RealPlaceSuggestion(title: $0.title, subtitle: $0.subtitle)
        }
        Task { @MainActor in
            self.suggestions = items
        }
    }

    func selectSuggestion(_ suggestion: RealPlaceSuggestion, onSelect: @escaping (String, String, Double, Double) -> Void) {
        suggestions = []
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = "\(suggestion.title) \(suggestion.subtitle)"
        req.region = completer.region
        MKLocalSearch(request: req).start { [weak self] resp, _ in
            guard let self else { return }
            let coord = resp?.mapItems.first?.placemark.coordinate
                ?? self.pickedCoordinate
            Task { @MainActor in
                self.pickedCoordinate = coord
                self.cameraPosition = .region(
                    MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012))
                )
                CoordinateCache.save(place: suggestion.title, lat: coord.latitude, lng: coord.longitude)
                onSelect(suggestion.title, suggestion.subtitle, coord.latitude, coord.longitude)
            }
        }
    }

    func geocodeFreeText(_ place: String) {
        let trimmed = place.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let cached = CoordinateCache.load(place: trimmed) {
            pickedCoordinate = cached
            cameraPosition = .region(MKCoordinateRegion(center: cached, span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)))
            return
        }
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = trimmed
        req.region = completer.region
        MKLocalSearch(request: req).start { [weak self] resp, _ in
            guard let self, let coord = resp?.mapItems.first?.placemark.coordinate else { return }
            Task { @MainActor in
                self.pickedCoordinate = coord
                self.cameraPosition = .region(MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)))
                CoordinateCache.save(place: trimmed, lat: coord.latitude, lng: coord.longitude)
            }
        }
    }
}

enum CoordinateCache {
    private static let key = "smart_notes_coord_cache"

    static func save(place: String, lat: Double, lng: Double) {
        var dict = (UserDefaults.standard.dictionary(forKey: key) as? [String: [Double]]) ?? [:]
        dict[place.lowercased()] = [lat, lng]
        UserDefaults.standard.set(dict, forKey: key)
    }

    static func load(place: String) -> CLLocationCoordinate2D? {
        let lower = place.lowercased()
        if let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: [Double]],
           let pair = dict[lower], pair.count == 2 {
            return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
        }
        let defaults: [(String, Double, Double)] = [
            ("biit", 33.6492, 73.0815),
            ("barani", 33.6492, 73.0815),
            ("commercial market", 33.6425, 73.0722),
            ("shifa", 33.6766, 73.0827),
            ("centaurus", 33.7077, 73.0501),
            ("saddar", 33.5972, 73.0543),
            ("faisal mosque", 33.7297, 73.0372),
            ("murree", 33.9070, 73.3943),
            ("cricket stadium", 33.6628, 73.0789)
        ]
        if let match = defaults.first(where: { lower.contains($0.0) }) {
            return CLLocationCoordinate2D(latitude: match.1, longitude: match.2)
        }
        return nil
    }
}

// Interactive Map Picker Used When Adding/Editing Location in a Note
struct InteractiveLocationPicker: View {
    @Binding var placeName: String
    @Binding var subLocation: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    var onSave: () -> Void

    @StateObject private var searchHelper = LocationSearchHelper()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Search Real Place on Map").font(.caption2.bold()).foregroundStyle(AppTheme.inkSoft)
                    TextField("Search any place in Islamabad / Rawalpindi…", text: $placeName)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: placeName) { _, newValue in
                            searchHelper.updateQuery(newValue)
                        }
                        .onSubmit {
                            searchHelper.geocodeFreeText(placeName)
                        }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Room / Sub-location").font(.caption2.bold()).foregroundStyle(AppTheme.inkSoft)
                    TextField("LT5 or Floor 2", text: $subLocation)
                        .textFieldStyle(.roundedBorder)
                }
            }

            // Live MapKit Autocomplete Suggestions (No Fake Static List!)
            if !searchHelper.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(searchHelper.suggestions) { item in
                        Button {
                            searchHelper.selectSuggestion(item) { title, subtitle, lat, lng in
                                placeName = title
                                if subLocation.isEmpty && !subtitle.isEmpty {
                                    subLocation = subtitle
                                }
                                latitude = lat
                                longitude = lng
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(AppTheme.accentHover)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.title).font(.caption.bold()).foregroundStyle(AppTheme.ink)
                                    if !item.subtitle.isEmpty {
                                        Text(item.subtitle).font(.caption2).foregroundStyle(AppTheme.muted).lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border))
            }

            // Interactive Map Preview where dragging moves the pin
            ZStack {
                Map(position: $searchHelper.cameraPosition) {
                    Marker(placeName.isEmpty ? "Selected Pin" : placeName, coordinate: searchHelper.pickedCoordinate)
                        .tint(AppTheme.accent)
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    searchHelper.pickedCoordinate = context.region.center
                    latitude = context.region.center.latitude
                    longitude = context.region.center.longitude
                    if !placeName.isEmpty {
                        CoordinateCache.save(place: placeName, lat: context.region.center.latitude, lng: context.region.center.longitude)
                    }
                }
            }
            .frame(height: 135)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))

            HStack {
                Text("Drag map to adjust pin · works offline once saved")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.muted)
                Spacer()
                Button("Save location", action: onSave)
                    .font(.caption.bold())
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
            }
        }
        .padding(12)
        .softCard(background: AppTheme.surfaceSoft)
        .onAppear {
            if let lat = latitude, let lng = longitude {
                let c = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                searchHelper.pickedCoordinate = c
                searchHelper.cameraPosition = .region(MKCoordinateRegion(center: c, span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)))
            } else if !placeName.isEmpty {
                searchHelper.geocodeFreeText(placeName)
            }
        }
    }
}

struct AppTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure = false
    @State private var showPassword = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !label.isEmpty {
                Text(label).font(.caption.bold()).foregroundStyle(AppTheme.ink)
            }
            HStack {
                if isSecure && !showPassword {
                    SecureField(placeholder, text: $text)
                        .textInputAutocapitalization(.never)
                } else {
                    TextField(placeholder, text: $text)
                        .textInputAutocapitalization(.never)
                }
                if isSecure {
                    Button { showPassword.toggle() } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(AppTheme.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(AppTheme.surface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.borderStrong))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct PrimaryButton: View {
    let title: String
    var loading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if loading {
                    ProgressView().tint(.white)
                }
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(AppTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .shadow(color: AppTheme.accent.opacity(0.26), radius: 7, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(loading)
    }
}

struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption.bold())
            Text("You are offline — showing downloaded (.sma) notes")
                .font(.caption.bold())
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .foregroundStyle(AppTheme.accentHover)
        .background(AppTheme.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppTheme.accentHover)
                .frame(width: 58, height: 58)
                .background(AppTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            Text(title).font(.headline).foregroundStyle(AppTheme.ink)
            Text(text)
                .font(.caption)
                .foregroundStyle(AppTheme.inkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .padding(28)
    }
}

struct Card<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(AppTheme.accentHover)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
    }
}

struct Avatar: View {
    let name: String
    var size: CGFloat = 42

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
        return parts.isEmpty ? "SN" : parts.uppercased()
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.32, weight: .heavy))
            .foregroundStyle(AppTheme.avatarText)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [AppTheme.avatarStart, AppTheme.avatarEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
    }
}

struct QuickCard: View {
    let icon: String
    let title: String
    var highlight = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(highlight ? .white : AppTheme.accentHover)
                .frame(width: 36, height: 36)
                .background(highlight ? AppTheme.accent : AppTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .softCard(
            radius: 18,
            background: highlight ? AppTheme.accentSofter : AppTheme.surface,
            borderColor: highlight ? AppTheme.accent.opacity(0.35) : AppTheme.border
        )
    }
}

struct ActionPill: View {
    let icon: String
    let text: String
    var filled = false
    var onClear: (() -> Void)? = nil
    let action: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: icon).font(.caption.bold())
                    Text(text).font(.caption.bold()).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 11)
                .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.plain)

            if filled, let onClear {
                Divider().frame(height: 22)
                Button(action: onClear) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.muted)
                        .frame(width: 32, height: 38)
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(filled ? AppTheme.accentHover : AppTheme.inkSoft)
        .background(filled ? AppTheme.accentSofter : AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(filled ? AppTheme.accent.opacity(0.4) : AppTheme.border)
        )
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}

// MARK: - Real MapKit Preview Card (Uses Database Lat/Lng or Cached Offline Coordinates)
struct MapPreviewCard: View {
    let placeName: String
    let subLocation: String?
    var latitude: Double? = nil
    var longitude: Double? = nil

    @State private var coordinate = CLLocationCoordinate2D(latitude: 33.6492, longitude: 73.0815)
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.6492, longitude: 73.0815),
            span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
        )
    )

    private var displayTitle: String {
        if let sub = subLocation, !sub.isEmpty {
            return "\(placeName) — \(sub)"
        }
        return placeName
    }

    var body: some View {
        Button(action: openInExternalMaps) {
            ZStack(alignment: .bottomTrailing) {
                Map(position: $cameraPosition, interactionModes: []) {
                    Marker(displayTitle, coordinate: coordinate)
                        .tint(AppTheme.accent)
                }
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(displayTitle)
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppTheme.accentHover)
                    }
                    Text("Tap to open in Maps")
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(1)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(AppTheme.surface.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(AppTheme.border))
                .padding(8)
            }
            .frame(maxWidth: .infinity, minHeight: 96, maxHeight: 96)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border))
        }
        .buttonStyle(.plain)
        .task(id: "\(placeName)-\(latitude ?? 0)-\(longitude ?? 0)") {
            resolveCoordinate()
        }
    }

    private func resolveCoordinate() {
        if let lat = latitude, let lng = longitude, lat != 0, lng != 0 {
            let c = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            coordinate = c
            cameraPosition = .region(MKCoordinateRegion(center: c, span: MKCoordinateSpan(latitudeDelta: 0.014, longitudeDelta: 0.014)))
            CoordinateCache.save(place: placeName, lat: lat, lng: lng)
            return
        }
        if let cached = CoordinateCache.load(place: placeName) {
            coordinate = cached
            cameraPosition = .region(MKCoordinateRegion(center: cached, span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)))
            return
        }
        let geocoder = CLGeocoder()
        let query = placeName.lowercased().contains("pakistan") ? placeName : "\(placeName), Islamabad, Pakistan"
        geocoder.geocodeAddressString(query) { placemarks, _ in
            if let loc = placemarks?.first?.location?.coordinate {
                Task { @MainActor in
                    coordinate = loc
                    cameraPosition = .region(MKCoordinateRegion(center: loc, span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)))
                    CoordinateCache.save(place: placeName, lat: loc.latitude, lng: loc.longitude)
                }
            }
        }
    }

    private func openInExternalMaps() {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = displayTitle
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: coordinate),
            MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))
        ])
    }
}

// MARK: - Reminder Card with Past / Done Tick Sign (✓)
struct ReminderPreviewCard: View {
    let title: String
    let remindAt: String
    var isDone: Bool = false
    var leadText: String = "30 min before"
    var onToggleDone: (() -> Void)? = nil

    private var completed: Bool {
        if isDone { return true }
        guard let d = remindAt.asDate else { return false }
        return d < Date()
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                onToggleDone?()
            } label: {
                Image(systemName: completed ? "checkmark.circle.fill" : "clock")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(completed ? Color.green : AppTheme.accentHover)
                    .frame(width: 32, height: 32)
                    .background(completed ? Color.green.opacity(0.14) : AppTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(completed ? "DONE ✓" : "REMINDER")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(completed ? Color.green : AppTheme.accentHover)
                }
                Text(title)
                    .font(.caption.bold())
                    .strikethrough(completed, color: AppTheme.muted)
                    .foregroundStyle(completed ? AppTheme.inkSoft : AppTheme.ink)
                    .lineLimit(1)
                Text(remindAt.niceTime)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.inkSoft)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .softCard(radius: 14, background: AppTheme.accentSofter, borderColor: AppTheme.accent.opacity(0.35))
    }
}
