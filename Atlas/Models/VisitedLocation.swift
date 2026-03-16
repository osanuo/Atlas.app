//
//  VisitedLocation.swift
//  Atlas
//

import SwiftUI
import SwiftData
import CoreLocation

@Model
final class VisitedLocation {
    var id: UUID = UUID()
    var name: String = ""
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var dateVisited: Date? = nil
    /// "trip" = auto-synced from a completed trip | "manual" = user-added
    var source: String = "manual"
    /// ISO country name, e.g. "Germany"
    var country: String = ""
    /// Continent name, e.g. "Europe"
    var continent: String = ""

    init(
        name: String,
        latitude: Double,
        longitude: Double,
        dateVisited: Date? = nil,
        source: String = "manual",
        country: String = "",
        continent: String = ""
    ) {
        self.id          = UUID()
        self.name        = name
        self.latitude    = latitude
        self.longitude   = longitude
        self.dateVisited = dateVisited
        self.source      = source
        self.country     = country
        self.continent   = continent
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Continent Helper

func continentFor(isoCode: String) -> String {
    let europe   = Set(["AT","BE","BG","HR","CY","CZ","DK","EE","FI","FR","DE","GR","HU",
                        "IE","IT","LV","LT","LU","MT","NL","PL","PT","RO","SK","SI","ES",
                        "SE","GB","CH","NO","IS","AL","BA","ME","MK","RS","UA","BY","MD",
                        "GE","AM","AZ","LI","MC","SM","VA","AD","XK"])
    let asia     = Set(["CN","JP","KR","IN","TH","VN","ID","MY","PH","SG","HK","TW","TR",
                        "SA","AE","IL","JO","LB","IQ","IR","KZ","UZ","MN","NP","BD","PK",
                        "AF","MM","KH","LA","BT","MV","LK","OM","YE","QA","KW","BH","SY",
                        "TM","TJ","KG","UZ"])
    let americas = Set(["US","CA","MX","BR","AR","CO","CL","PE","VE","EC","BO","UY","PY",
                        "GY","SR","TT","JM","CU","DO","GT","HN","SV","NI","CR","PA","PR",
                        "HT","BS","BB","LC","VC","GD","AG","DM","KN","BZ","TC","KY","AW"])
    let africa   = Set(["ZA","EG","NG","KE","ET","GH","TZ","UG","MZ","ZM","ZW","SN","CM",
                        "CI","MG","AO","SD","SO","TN","DZ","MA","LY","MU","RW","BW","NA",
                        "LS","SZ","MW","ZM","CD","CG","GA","GQ","CF","TD","NE","ML","BF",
                        "GN","SL","LR","TG","BJ","GW","GM","CV","MR","DJ","ER","SS","BI"])
    let oceania  = Set(["AU","NZ","FJ","PG","WS","TO","VU","SB","PW","FM","MH","KI","NR","TV"])

    if europe.contains(isoCode)   { return "Europe" }
    if asia.contains(isoCode)     { return "Asia" }
    if americas.contains(isoCode) { return "Americas" }
    if africa.contains(isoCode)   { return "Africa" }
    if oceania.contains(isoCode)  { return "Oceania" }
    return "Other"
}
