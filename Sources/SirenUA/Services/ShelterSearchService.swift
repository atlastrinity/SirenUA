import Foundation
import MapKit
import CoreLocation
import OSLog

private let searchLogger = Logger(subsystem: "com.sirenua", category: "ShelterSearchService")

// MARK: - Search Result Model

struct ShelterSearchResult {
    let allFoundShelters: [MKMapItem]
    let closestShelter: MKMapItem?
    let targetRadiusMeters: Double
    let warningMessage: String?
    let errorMessage: String?
    let isSecondaryFallback: Bool
    let shelterCategory: ShelterCategory
    let isNightAccessible: Bool
    let isVehicleAccessible: Bool

    init(
        allFoundShelters: [MKMapItem] = [],
        closestShelter: MKMapItem? = nil,
        targetRadiusMeters: Double = 1500.0,
        warningMessage: String? = nil,
        errorMessage: String? = nil,
        isSecondaryFallback: Bool = false,
        shelterCategory: ShelterCategory = .primary,
        isNightAccessible: Bool = true,
        isVehicleAccessible: Bool = false
    ) {
        self.allFoundShelters = allFoundShelters
        self.closestShelter = closestShelter
        self.targetRadiusMeters = targetRadiusMeters
        self.warningMessage = warningMessage
        self.errorMessage = errorMessage
        self.isSecondaryFallback = isSecondaryFallback
        self.shelterCategory = shelterCategory
        self.isNightAccessible = isNightAccessible
        self.isVehicleAccessible = isVehicleAccessible
    }
}

// MARK: - Shelter Search Service

final class ShelterSearchService {
    static let shared = ShelterSearchService()
    
    private init() {}

    /// Performs shelter search prioritizing user preferences, active transport mode, primary/secondary hierarchy, and distance bounds.
    func searchNearbyShelters(
        userCoordinate: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType,
        walkingRadiusKm: Double,
        drivingRadiusKm: Double,
        serverURL: String
    ) async -> ShelterSearchResult {
        // 1. Determine active search radii: Strict user radius, local extended, and regional district fallback
        let configuredKm = transportType == .automobile ? drivingRadiusKm : walkingRadiusKm
        let minRadiusKm = transportType == .automobile ? 1.0 : 0.5
        let maxRadiusKm = transportType == .automobile ? 30.0 : 10.0
        let targetRadiusKm = min(max(configuredKm, minRadiusKm), maxRadiusKm)
        let targetRadiusMeters = targetRadiusKm * 1000.0

        // Stage 2: Local extended perimeter
        let localExtendedRadiusMeters = transportType == .automobile
            ? max(targetRadiusMeters, 15_000.0)
            : max(targetRadiusMeters, 6_000.0)

        // Stage 3: Regional district perimeter (to cover neighboring towns/villages in rural areas like Uhersko/Stryi)
        let regionalExtendedRadiusMeters = transportType == .automobile
            ? max(localExtendedRadiusMeters, 30_000.0)
            : max(localExtendedRadiusMeters, 15_000.0)

        searchLogger.info("Starting shelter search for mode \(transportType == .automobile ? "automobile" : "walking"). User: (\(userCoordinate.latitude), \(userCoordinate.longitude)), Target: \(Int(targetRadiusMeters))m, LocalExtended: \(Int(localExtendedRadiusMeters))m, Regional: \(Int(regionalExtendedRadiusMeters))m")

        // 2. Priority 1: Backend ThreatServer API (Pre-seeded registry, Firestore, and OSM Overpass)
        var apiShelters: [ShelterItem] = []
        do {
            let networkManager = NetworkManager()
            apiShelters = try await networkManager.fetchShelters(
                serverURL: serverURL,
                lat: userCoordinate.latitude,
                lon: userCoordinate.longitude,
                radiusMeters: regionalExtendedRadiusMeters
            )
            searchLogger.info("Backend API returned \(apiShelters.count) shelters")
        } catch {
            searchLogger.warning("Backend Shelter API failed, falling back to MKLocalSearch: \(error.localizedDescription)")
        }

        let userLoc = CLLocation(latitude: userCoordinate.latitude, longitude: userCoordinate.longitude)

        if !apiShelters.isEmpty {
            // Re-verify exact Haversine distance and apply smart safety tier ranking
            let sortedWithDistance = apiShelters.map { shelter -> (shelter: ShelterItem, distance: Double, tier: Int, isPrimary: Bool) in
                let shelterLoc = CLLocation(latitude: shelter.lat, longitude: shelter.lon)
                let dist = shelterLoc.distance(from: userLoc)
                let tier = self.safetyTierScore(for: shelter)
                let isPrimary = shelter.category == .primary
                return (shelter, dist, tier, isPrimary)
            }.sorted {
                // Tier ranking: Primary first, then mall parkings/24-7, then others
                if abs($0.distance - $1.distance) < 300.0 && $0.tier != $1.tier {
                    return $0.tier < $1.tier
                }
                return $0.distance < $1.distance
            }

            let strictlyWithin = sortedWithDistance.filter { $0.distance <= targetRadiusMeters }
            let withinLocalExtended = sortedWithDistance.filter { $0.distance <= localExtendedRadiusMeters }
            let withinRegionalExtended = sortedWithDistance.filter { $0.distance <= regionalExtendedRadiusMeters }

            // 2A. Primary official shelters strictly within user radius
            let primaryStrict = strictlyWithin.filter { $0.isPrimary }
            if let closestPrimary = primaryStrict.first {
                let mapItems = strictlyWithin.map { self.createMapItem(from: $0.shelter) }
                let closestMapItem = createMapItem(from: closestPrimary.shelter)
                return ShelterSearchResult(
                    allFoundShelters: mapItems,
                    closestShelter: closestMapItem,
                    targetRadiusMeters: targetRadiusMeters,
                    warningMessage: nil,
                    errorMessage: nil,
                    isSecondaryFallback: false,
                    shelterCategory: .primary,
                    isNightAccessible: closestPrimary.shelter.isNightAccessible,
                    isVehicleAccessible: closestPrimary.shelter.isVehicleAccessible
                )
            }

            // 2B. Secondary alternative shelters (Mall Parkings, Schools, Hospitals) strictly within user radius
            let secondaryStrict = strictlyWithin.filter { !$0.isPrimary }
            if let closestSecondary = secondaryStrict.first {
                let mapItems = strictlyWithin.map { self.createMapItem(from: $0.shelter) }
                let closestMapItem = createMapItem(from: closestSecondary.shelter)
                let distText = ShelterFormatter.formatDistance(meters: closestSecondary.distance)
                let warn = self.secondaryNoticeMessage(for: closestSecondary.shelter, distText: distText)

                return ShelterSearchResult(
                    allFoundShelters: mapItems,
                    closestShelter: closestMapItem,
                    targetRadiusMeters: targetRadiusMeters,
                    warningMessage: warn,
                    errorMessage: nil,
                    isSecondaryFallback: true,
                    shelterCategory: .secondary,
                    isNightAccessible: closestSecondary.shelter.isNightAccessible,
                    isVehicleAccessible: closestSecondary.shelter.isVehicleAccessible
                )
            }

            // 2C. Stage 2: Local Extended Perimeter (Primary first, then secondary)
            let primaryLocal = withinLocalExtended.filter { $0.isPrimary }
            if let closestPrimaryLocal = primaryLocal.first {
                let mapItems = withinLocalExtended.map { self.createMapItem(from: $0.shelter) }
                let closestMapItem = createMapItem(from: closestPrimaryLocal.shelter)
                let distText = ShelterFormatter.formatDistance(meters: closestPrimaryLocal.distance)
                let warn = "Найближче офіційне укриття знайдено на відстані \(distText) (поза обраним радіусом)"
                return ShelterSearchResult(
                    allFoundShelters: mapItems,
                    closestShelter: closestMapItem,
                    targetRadiusMeters: targetRadiusMeters,
                    warningMessage: warn,
                    errorMessage: nil,
                    isSecondaryFallback: false,
                    shelterCategory: .primary,
                    isNightAccessible: closestPrimaryLocal.shelter.isNightAccessible,
                    isVehicleAccessible: closestPrimaryLocal.shelter.isVehicleAccessible
                )
            } else if let closestSecondaryLocal = withinLocalExtended.first {
                let mapItems = withinLocalExtended.map { self.createMapItem(from: $0.shelter) }
                let closestMapItem = createMapItem(from: closestSecondaryLocal.shelter)
                let distText = ShelterFormatter.formatDistance(meters: closestSecondaryLocal.distance)
                let warn = "Найближче альтернативне укриття знайдено на відстані \(distText) (поза обраним радіусом)"
                return ShelterSearchResult(
                    allFoundShelters: mapItems,
                    closestShelter: closestMapItem,
                    targetRadiusMeters: targetRadiusMeters,
                    warningMessage: warn,
                    errorMessage: nil,
                    isSecondaryFallback: true,
                    shelterCategory: .secondary,
                    isNightAccessible: closestSecondaryLocal.shelter.isNightAccessible,
                    isVehicleAccessible: closestSecondaryLocal.shelter.isVehicleAccessible
                )
            }

            // 2D. Stage 3: Regional District Perimeter
            if let closestRegional = withinRegionalExtended.first {
                let closestMapItem = createMapItem(from: closestRegional.shelter)
                let distText = ShelterFormatter.formatDistance(meters: closestRegional.distance)
                let warn = "Поруч немає укриттів. Знайдено захисну споруду району (\(distText)). Радимо скористатися авто."
                return ShelterSearchResult(
                    allFoundShelters: [closestMapItem],
                    closestShelter: closestMapItem,
                    targetRadiusMeters: targetRadiusMeters,
                    warningMessage: warn,
                    errorMessage: nil,
                    isSecondaryFallback: !closestRegional.isPrimary,
                    shelterCategory: closestRegional.shelter.category,
                    isNightAccessible: closestRegional.shelter.isNightAccessible,
                    isVehicleAccessible: closestRegional.shelter.isVehicleAccessible
                )
            }
        }

        // 3. Priority 2: Apple MapKit MKLocalSearch fallback with Smart Ranking
        searchLogger.info("Executing MKLocalSearch for civil defense shelters, parkings, educational and medical facilities across Ukraine...")
        let localSearchItems = await performLocalSearch(
            center: userCoordinate,
            radiusMeters: regionalExtendedRadiusMeters
        )

        let itemsWithDistance = localSearchItems.map { item -> (item: MKMapItem, distance: Double, tier: Int, isPrimary: Bool, isNight: Bool, isVehicle: Bool) in
            let itemLoc = CLLocation(
                latitude: item.placemark.coordinate.latitude,
                longitude: item.placemark.coordinate.longitude
            )
            let dist = itemLoc.distance(from: userLoc)
            let tier = self.safetyTierScore(for: item)
            let isPrimary = tier == 1
            let isVehicle = tier == 2 || (item.name?.lowercased().contains("паркінг") ?? false)
            let isNight = isPrimary || isVehicle || (item.name?.lowercased().contains("лікарня") ?? false)
            return (item, dist, tier, isPrimary, isNight, isVehicle)
        }.sorted {
            if abs($0.distance - $1.distance) < 300.0 && $0.tier != $1.tier {
                return $0.tier < $1.tier
            }
            return $0.distance < $1.distance
        }

        let preferred = itemsWithDistance.filter { $0.distance <= targetRadiusMeters }
        let localExt = itemsWithDistance.filter { $0.distance <= localExtendedRadiusMeters }
        let regionalExt = itemsWithDistance.filter { $0.distance <= regionalExtendedRadiusMeters }

        // 3A. Preferred radius: Primary first
        let primaryPreferred = preferred.filter { $0.isPrimary }
        if let closestPrimary = primaryPreferred.first {
            return ShelterSearchResult(
                allFoundShelters: preferred.map { $0.item },
                closestShelter: closestPrimary.item,
                targetRadiusMeters: targetRadiusMeters,
                warningMessage: nil,
                errorMessage: nil,
                isSecondaryFallback: false,
                shelterCategory: .primary,
                isNightAccessible: closestPrimary.isNight,
                isVehicleAccessible: closestPrimary.isVehicle
            )
        }

        // 3B. Preferred radius: Secondary alternative (Mall parking, schools, etc.)
        if let closestSecondary = preferred.first {
            let distText = ShelterFormatter.formatDistance(meters: closestSecondary.distance)
            let name = closestSecondary.item.name ?? "Укриття"
            let warn: String
            if closestSecondary.isVehicle {
                warn = "Офіційних бомбосховищ у радіусі немає. Знайдено паркінг: \(name) (\(distText)) — цілодобовий заїзд авто."
            } else if closestSecondary.isNight {
                warn = "Офіційних бомбосховищ у радіусі немає. Знайдено укриття: \(name) (\(distText)) — доступне цілодобово."
            } else {
                warn = "Офіційних бомбосховищ у радіусі немає. Знайдено найпростіше укриття: \(name) (\(distText)). У нічний час перевіряйте доступність чергового."
            }

            return ShelterSearchResult(
                allFoundShelters: preferred.map { $0.item },
                closestShelter: closestSecondary.item,
                targetRadiusMeters: targetRadiusMeters,
                warningMessage: warn,
                errorMessage: nil,
                isSecondaryFallback: true,
                shelterCategory: .secondary,
                isNightAccessible: closestSecondary.isNight,
                isVehicleAccessible: closestSecondary.isVehicle
            )
        } else if let closestLocal = localExt.first {
            let distText = ShelterFormatter.formatDistance(meters: closestLocal.distance)
            let warn = "Найближче укриття знайдено на відстані \(distText) (поза обраним радіусом)"
            return ShelterSearchResult(
                allFoundShelters: localExt.map { $0.item },
                closestShelter: closestLocal.item,
                targetRadiusMeters: targetRadiusMeters,
                warningMessage: warn,
                errorMessage: nil,
                isSecondaryFallback: !closestLocal.isPrimary,
                shelterCategory: closestLocal.isPrimary ? .primary : .secondary,
                isNightAccessible: closestLocal.isNight,
                isVehicleAccessible: closestLocal.isVehicle
            )
        } else if let closestRegional = regionalExt.first {
            let distText = ShelterFormatter.formatDistance(meters: closestRegional.distance)
            let warn = "Поруч немає укриттів. Знайдено захисну споруду району (\(distText)). Радимо скористатися авто."
            return ShelterSearchResult(
                allFoundShelters: [closestRegional.item],
                closestShelter: closestRegional.item,
                targetRadiusMeters: targetRadiusMeters,
                warningMessage: warn,
                errorMessage: nil,
                isSecondaryFallback: !closestRegional.isPrimary,
                shelterCategory: closestRegional.isPrimary ? .primary : .secondary,
                isNightAccessible: closestRegional.isNight,
                isVehicleAccessible: closestRegional.isVehicle
            )
        }

        // 4. No shelters found even in regional perimeter
        let radiusStr = ShelterFormatter.formatDistance(meters: targetRadiusMeters)
        let modeStr = transportType == .automobile ? "авто" : "пішки"
        let errorMsg = "У радіусі \(radiusStr) не знайдено захисних споруд (режим «\(modeStr)»). У сільській місцевості під час тривоги використовуйте підвальні приміщення місцевого ліцею, школи, старостату або правило двох стін."
        
        return ShelterSearchResult(
            allFoundShelters: [],
            closestShelter: nil,
            targetRadiusMeters: targetRadiusMeters,
            warningMessage: nil,
            errorMessage: errorMsg,
            isSecondaryFallback: false,
            shelterCategory: .primary,
            isNightAccessible: false,
            isVehicleAccessible: false
        )
    }

    // MARK: - Helper Methods

    private func secondaryNoticeMessage(for shelter: ShelterItem, distText: String) -> String {
        let name = shelter.name ?? shelter.displayName
        if shelter.isVehicleAccessible {
            return "Офіційних бомбосховищ у радіусі немає. Знайдено паркінг: \(name) (\(distText)) — цілодобовий заїзд авто."
        } else if shelter.isNightAccessible {
            return "Офіційних бомбосховищ у радіусі немає. Знайдено укриття: \(name) (\(distText)) — доступне цілодобово."
        } else {
            return "Офіційних бомбосховищ у радіусі немає. Знайдено найпростіше укриття: \(name) (\(distText)). У нічний час перевіряйте доступність чергового."
        }
    }

    private func safetyTierScore(for item: MKMapItem) -> Int {
        let nameLower = (item.name ?? "").lowercased()
        // Tier 1: Metro, dedicated Bunkers, Bomb Shelters, Civil Defense
        if nameLower.contains("метро") || nameLower.contains("subway") ||
           nameLower.contains("бункер") || nameLower.contains("bunker") ||
           nameLower.contains("бомбосховище") || nameLower.contains("сховище") ||
           nameLower.contains("протирадіаційн") || nameLower.contains("пру") ||
           nameLower.contains("цивільного захисту") {
            return 1
        }
        // Tier 2: Shopping Mall Parking (ТРЦ/ТЦ) & underground vehicle parking
        if (nameLower.contains("трц") || nameLower.contains("тц") || nameLower.contains("mall") || nameLower.contains("плаза") || nameLower.contains("епіцентр")) &&
           (nameLower.contains("паркінг") || nameLower.contains("парковка") || nameLower.contains("автостоянка") || nameLower.contains("parking") || nameLower.contains("авто")) {
            return 2
        }
        if nameLower.contains("підземн") || nameLower.contains("паркінг") ||
           nameLower.contains("парковка") || nameLower.contains("parking") {
            return 2
        }
        // Tier 3: Certified basic shelters in communities: Schools, Lyceums, Kindergartens, Hospitals, Public Admin basements
        if nameLower.contains("ліцей") || nameLower.contains("школа") ||
           nameLower.contains("гімназія") || nameLower.contains("дитсадок") ||
           nameLower.contains("садочок") || nameLower.contains("здо") ||
           nameLower.contains("лікарня") || nameLower.contains("поліклініка") ||
           nameLower.contains("амбулаторія") || nameLower.contains("госпіталь") ||
           nameLower.contains("старостат") || nameLower.contains("сільрада") ||
           nameLower.contains("сільська рада") || nameLower.contains("міська рада") ||
           nameLower.contains("будинок культури") || nameLower.contains("пункт незламності") {
            return 3
        }
        return 4
    }

    private func safetyTierScore(for shelter: ShelterItem) -> Int {
        let rawType = shelter.type.lowercased()
        let nameLower = shelter.displayName.lowercased()
        if rawType == "metro" || rawType == "bunker" || rawType == "bomb_shelter" || rawType == "radiation_shelter" ||
           nameLower.contains("метро") || nameLower.contains("бункер") || nameLower.contains("бомбосховище") || nameLower.contains("пру") {
            return 1
        }
        if rawType == "mall_parking" || rawType == "underground_parking" || rawType == "open_parking" ||
           nameLower.contains("трц") || nameLower.contains("паркінг") || nameLower.contains("підземн") {
            return 2
        }
        if rawType == "school_shelter" || rawType == "hospital_shelter" || rawType == "admin_shelter" || rawType == "basic_shelter" ||
           nameLower.contains("ліцей") || nameLower.contains("школа") || nameLower.contains("гімназія") || nameLower.contains("лікарня") {
            return 3
        }
        return 4
    }

    private func createMapItem(from shelter: ShelterItem) -> MKMapItem {
        let placemark = MKPlacemark(coordinate: shelter.coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = shelter.displayName
        return item
    }

    private func performLocalSearch(
        center: CLLocationCoordinate2D,
        radiusMeters: Double
    ) async -> [MKMapItem] {
        let searchRegion = MKCoordinateRegion(
            center: center,
            latitudinalMeters: radiusMeters * 2,
            longitudinalMeters: radiusMeters * 2
        )

        let queries = [
            // 1. Civil defense & specialized bunkers
            "укриття", "бомбосховище", "сховище", "захисна споруда",
            "укриття цивільного захисту", "найпростіше укриття",
            "бункер", "протирадіаційне укриття", "ПРУ",
            "пункт незламності", "ДСНС",
            "споруда подвійного призначення", "захисна споруда цивільного захисту",
            "станція метро", "підземне сховище", "bomb shelter", "bunker",
            // 2. Shopping Mall Parking (ТРЦ/ТЦ) & underground / multi-storey parking
            "ТРЦ паркінг", "підземний паркінг ТРЦ", "паркінг ТРЦ", "підземний паркінг",
            "підземна автостоянка", "багаторівневий паркінг", "паркінг", "ТРЦ", "ТЦ", "торговий центр",
            // 3. Educational institutions (certified simple civil defense shelters)
            "ліцей", "гімназія", "школа", "дитсадок", "дитячий садок", "ЗДО",
            // 4. Medical facilities (basements and PRU)
            "лікарня", "поліклініка", "амбулаторія", "госпіталь",
            // 5. Municipal buildings and village centers
            "старостат", "сільська рада", "міська рада", "будинок культури", "підземний перехід"
        ]

        var rawItems: [MKMapItem] = []

        await withTaskGroup(of: [MKMapItem]?.self) { group in
            for query in queries {
                group.addTask {
                    let request = MKLocalSearch.Request()
                    request.naturalLanguageQuery = query
                    request.region = searchRegion
                    let search = MKLocalSearch(request: request)
                    do {
                        let response = try await search.start()
                        return response.mapItems
                    } catch {
                        return nil
                    }
                }
            }

            for await items in group {
                if let items = items {
                    rawItems.append(contentsOf: items)
                }
            }
        }

        // Exclusion list: weather stops, gazebos, rain awnings, beach shades, cafes
        let excludedKeywords = [
            "дощ", "зупинка", "навіс", "альтанка", "павільйон", "тент",
            "палатка", "павіліон", "пляж", "кафе", "ресторан", "маф", "кіоск", "мангал",
            "rain", "bus stop", "gazebo", "awning", "tent", "transit", "stop", "platform"
        ]

        var uniqueItems: [MKMapItem] = []

        for item in rawItems {
            let nameLower = (item.name ?? "").lowercased()

            // Filter out non-defense commercial entertainment categories, unless it's a parking/mall
            if let category = item.pointOfInterestCategory {
                if category == .park || category == .beach ||
                   category == .restaurant || category == .cafe || category == .gasStation ||
                   category == .restroom || category == .nightlife || category == .campground {
                    continue
                }
            }

            let isParkingOrMall = nameLower.contains("паркінг") || nameLower.contains("парковка") || nameLower.contains("parking") || nameLower.contains("трц") || nameLower.contains("тц") || nameLower.contains("mall")
            let isSubway = nameLower.contains("метро") || nameLower.contains("subway")
            let isInstitution = nameLower.contains("ліцей") || nameLower.contains("школа") || nameLower.contains("гімназія") ||
                                nameLower.contains("лікарня") || nameLower.contains("поліклініка") || nameLower.contains("дитсадок") ||
                                nameLower.contains("старостат") || nameLower.contains("амбулаторія")
            
            if !isParkingOrMall && !isSubway && !isInstitution {
                let isRainShelter = excludedKeywords.contains { nameLower.contains($0) }
                if isRainShelter { continue }
            }

            // Deduplicate by coordinate proximity (< 25m)
            let coord = item.placemark.coordinate
            let isDuplicate = uniqueItems.contains { existing in
                let extCoord = existing.placemark.coordinate
                let locA = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                let locB = CLLocation(latitude: extCoord.latitude, longitude: extCoord.longitude)
                return locA.distance(from: locB) < 25.0
            }

            if !isDuplicate {
                uniqueItems.append(item)
            }
        }

        return uniqueItems
    }
}

