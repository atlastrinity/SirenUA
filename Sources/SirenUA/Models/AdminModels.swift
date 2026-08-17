import SwiftUI
import Foundation

// MARK: - Decodable API Models (v2)

struct AdminErrorEntry: Codable, Identifiable {
    let id: Int
    let timestamp: String
    let source: String
    let error_type: String
    let message: String
    let endpoint: String?
    let context: String?
}

struct AdminErrorsResponse: Codable {
    let total: Int
    let errors: [AdminErrorEntry]
}

struct SourceStat: Codable, Identifiable {
    let id = UUID()
    let source: String
    let count: Int
    enum CodingKeys: String, CodingKey {
        case source, count
    }
}

struct TypeStat: Codable, Identifiable {
    let id = UUID()
    let error_type: String
    let count: Int
    enum CodingKeys: String, CodingKey {
        case error_type = "error_type"
        case count
    }
}

struct HourlyStat: Codable, Identifiable {
    let id = UUID()
    let hour: String
    let count: Int
    enum CodingKeys: String, CodingKey {
        case hour, count
    }
}

struct AdminErrorStatsResponse: Codable {
    let total: Int
    let by_source: [SourceStat]
    let by_type: [TypeStat]
    let hourly: [HourlyStat]
}

struct AdminChronologyEntry: Codable, Identifiable {
    let id: Int
    let region: String
    let threat_level: String?
    let threat_type: String?
    let confidence_at_set: Int?
    let confidence_at_clear: Int?
    let was_predictive: Int?
    let prediction_accuracy: String?
    let lifecycle_status: String?
    let duration_seconds: Int?
    let gemini_group_id: String?
    let threat_timestamp: String?
    let threat_detail: String?
    let clearing_timestamp: String?
    let resolution_type: String?
    let match_type: String? // match, mismatch, active, cleared
}

struct DailyStatEntry: Codable, Identifiable {
    let id = UUID()
    let day: String
    let total_events: Int
    let cleared: Int
    let active: Int?
    let confirmed: Int
    let overestimated: Int
    let mitigated: Int?
    let predictive: Int
    enum CodingKeys: String, CodingKey {
        case day, total_events, cleared, active, confirmed, overestimated, mitigated, predictive
    }
    
    var accuracyPct: Double? {
        let confirmedCount = confirmed
        let overestimatedCount = overestimated
        let mitigatedCount = mitigated ?? 0
        let total = confirmedCount + overestimatedCount + mitigatedCount
        guard total > 0 else { return nil }
        let accuracy = Double(confirmedCount) + Double(mitigatedCount) * 0.8
        return (accuracy / Double(total)) * 100.0
    }
}

struct AdminChronologyResponse: Codable {
    let total: Int
    let events: [AdminChronologyEntry]
    let daily_stats: [DailyStatEntry]
}

struct GeminiRule: Codable, Identifiable {
    let id: Int
    let created_at: String
    let updated_at: String
    let rule_type: String
    let source_region: String?
    let target_region: String?
    let threat_type: String?
    let rule_text: String
    let evidence_count: Int
    let accuracy_score: Double
    let is_active: Int
}

struct GeminiRulesResponse: Codable {
    let total: Int
    let rules: [GeminiRule]
}

struct GeminiRuleAuditEntry: Codable, Identifiable {
    let id: Int
    let timestamp: String
    let action: String
    let rule_type: String?
    let rule_text: String?
    let source_region: String?
    let target_region: String?
    let threat_type: String?
    let reason: String?
}

struct GeminiRulesHistoryResponse: Codable {
    let total: Int
    let entries: [GeminiRuleAuditEntry]
}

struct GraphTimeSeriesPoint: Codable, Identifiable {
    var id: String { timestamp }
    let timestamp: String
    let accuracy_score: Double
    let variance_minutes: Double
    let accuracy_gain_pct: Double
}

struct AdminRegionRuleMetrics: Codable, Identifiable {
    var id: String { region }
    let region: String
    let active_rules_count: Int
    let applied_events_count: Int
    let base_model_accuracy_pct: Double
    let ai_rules_accuracy_pct: Double
    let accuracy_gain_pct: Double
    let eta_variance_minutes: Double
    let rules: [GeminiRule]
    let recent_applications: [GeminiRuleAuditEntry]?
    let graph_time_series: [GraphTimeSeriesPoint]
}

struct AdminRulesMetricsResponse: Codable {
    let status: String
    let total_regions: Int
    let region_metrics: [String: AdminRegionRuleMetrics]
}

// MARK: - Redesigned Dashboard v2 Decodables

struct DashboardAccuracyStats: Codable {
    let confirmed: Int?
    let mitigated: Int?
    let overestimated: Int?
    let active: Int?
    let cleared: Int?
    let total: Int?
}

struct DashboardThreatTypeStat: Codable, Identifiable {
    let id = UUID()
    let threat_type: String
    let count: Int
    enum CodingKeys: String, CodingKey {
        case threat_type, count
    }
}

struct DashboardRegionStat: Codable, Identifiable {
    let id = UUID()
    let region: String
    let count: Int
    enum CodingKeys: String, CodingKey {
        case region, count
    }
}

struct DashboardHourlyStat: Codable, Identifiable {
    let id = UUID()
    let hour: Int
    let count: Int
    enum CodingKeys: String, CodingKey {
        case hour, count
    }
}

struct AdminDashboardStatsResponse: Codable {
    let total_events_7d: Int?
    let accuracy: DashboardAccuracyStats?
    let accuracy_pct: Double?
    let active_now: Int?
    let avg_early_seconds: Int?
    let by_type: [DashboardThreatTypeStat]?
    let top_regions: [DashboardRegionStat]?
    let hourly: [DashboardHourlyStat]?
    let errors_24h: Int?
}

// MARK: - Redesigned Correlation v2 Decodables

struct AdminChronologyV2Entry: Codable, Identifiable {
    let id: Int
    let region: String?
    let threat_level: String?
    let threat_type: String?
    let confidence_at_set: Int?
    let confidence_at_clear: Int?
    let was_predictive: Int?
    let prediction_accuracy: String?
    let lifecycle_status: String?
    let duration_seconds: Int?
    let gemini_group_id: String?
    let ai_timestamp: String?
    let threat_detail: String?
    let attack_vector: String?
    let target_count: Int?
    let speed_kmh: Int?
    let weapon_subtype: String?
    let launch_origin: String?
    let altitude_category: String?
    let distance_to_target_km: Double?
    let event_phase: String?
    let source_reliability: String?
    let civilian_risk_level: String?
    let clearing_timestamp: String?
    let resolution_type: String?
    let alarm_timestamp: String?
    let time_delta_seconds: Int?
    let match_type: String? // confirmed, mitigated, overestimated, active, cleared
    let match_reason: String?
    let telemetry_summary: String?
}

struct DailyStatEntryV2: Codable, Identifiable {
    let id = UUID()
    let day: String
    let total_events: Int
    let cleared: Int
    let confirmed: Int
    let overestimated: Int
    let mitigated: Int
    let predictive: Int
    enum CodingKeys: String, CodingKey {
        case day, total_events, cleared, confirmed, overestimated, mitigated, predictive
    }
}

struct TypeBreakdownEntry: Codable, Identifiable {
    let id = UUID()
    let threat_type: String
    let prediction_accuracy: String?
    let count: Int
    enum CodingKeys: String, CodingKey {
        case threat_type, prediction_accuracy, count
    }
}

struct DeltaDistributionBucket: Identifiable {
    let id: String
    let label: String
    let minutes: Int
    let count: Int
}

struct AdminChronologyV2Response: Codable {
    let total: Int?
    let period_total: Int?
    let stats: [String: Int]?
    let events: [AdminChronologyV2Entry]?
    let daily_stats: [DailyStatEntryV2]?
    let delta_distribution: [String: Int]?
    let type_breakdown: [TypeBreakdownEntry]?
}

// MARK: - Palantir Intelligence Decodables

struct PalantirCorridor: Codable, Identifiable {
    var id: String { "\(source ?? "")_\(target ?? "")_\(threat_type ?? "")_\(count ?? 0)" }
    let source: String?
    let target: String?
    let source_lat: Double?
    let source_lon: Double?
    let target_lat: Double?
    let target_lon: Double?
    let source_coords: [Double]?
    let target_coords: [Double]?
    let route_description: String?
    let count: Int?
    let threat_type: String?
    let avg_confidence: Int?
    let accuracy: Int?
    let avg_speed: Double?
    let data_source: String?

    var computedSourceLat: Double {
        source_lat ?? source_coords?.first ?? 50.0
    }
    var computedSourceLon: Double {
        source_lon ?? (source_coords?.count ?? 0 > 1 ? source_coords![1] : 35.0)
    }
    var computedTargetLat: Double {
        target_lat ?? target_coords?.first ?? 49.0
    }
    var computedTargetLon: Double {
        target_lon ?? (target_coords?.count ?? 0 > 1 ? target_coords![1] : 32.0)
    }
}

struct PalantirLaunchHub: Codable, Identifiable {
    var id: String { name ?? UUID().uuidString }
    let name: String?
    let lat: Double?
    let lon: Double?
    let total_launches: Int?
    let by_type: [String: Int]?
    let last_detected: String?
}

struct PalantirRegionRisk: Codable, Identifiable {
    var id: String { name ?? UUID().uuidString }
    let name: String?
    let lat: Double?
    let lon: Double?
    let total_events: Int?
    let by_type: [String: Int]?
    let risk_score: Int?
    let avg_confidence: Int?
    let confirmed: Int?
    let predictive: Int?
    let dominant_threat_type: String?
}

struct PalantirDailySummary: Codable, Identifiable {
    var id: String { date ?? day ?? UUID().uuidString }
    let date: String?
    let day: String?
    let total_events: Int?
    let cleared: Int?
    let confirmed: Int?
    let overestimated: Int?
    let mitigated: Int?
    let predictive: Int?
    let avg_confidence: Int?
    let effectiveness_pct: Double?
}

struct PalantirMultiHopChain: Codable, Identifiable {
    var id: String { chain }
    let chain: String
    let occurrences: Int
    let confidence: Double
}

struct PalantirBranchTarget: Codable, Identifiable {
    var id: String { "\(target)_\(count)" }
    let target: String
    let count: Int
    let probability: Double
}

struct PalantirJunctionBranch: Codable, Identifiable {
    var id: String { junction_region }
    let junction_region: String
    let total_transitions: Int
    let branches: [PalantirBranchTarget]
}

struct PalantirAirDefenseAttrition: Codable, Identifiable {
    var id: String { region }
    let region: String
    let total_events: Int
    let intercepted_count: Int
    let impact_count: Int
    let transit_count: Int
    let interception_rate_percent: Double
    let defense_density: String // "high", "medium", "standard"
}

struct PostMortemRuleCreated: Codable, Identifiable {
    var id: String { rule_text }
    let rule_type: String
    let rule_text: String
    let accuracy_score: Double?
}

struct PostMortemResponse: Codable {
    let status: String
    let rules_created: Int?
    let message: String?
    let rules_details: [PostMortemRuleCreated]?
}

struct PalantirOverviewResponse: Codable {
    let system: String?
    let days: Int?
    let trajectory_corridors: [PalantirCorridor]?
    let launch_hubs: [PalantirLaunchHub]?
    let region_risk_matrix: [PalantirRegionRisk]?
    let flight_corridors: [PalantirCorridor]?
    let daily_summaries: [PalantirDailySummary]?
    let multihop_chains: [PalantirMultiHopChain]?
    let junction_branches: [PalantirJunctionBranch]?
    let air_defense_attrition: [PalantirAirDefenseAttrition]?
}

struct PalantirReportEntry: Codable, Identifiable {
    let id: Int
    let created_at: String
    let report_date: String
    let threat_assessment_summary: String?
    let confidence_index: Double?
    let generated_by: String?
}

struct PalantirReportsResponse: Codable {
    let reports: [PalantirReportEntry]
    let total: Int
}

// MARK: - UI Constants

struct ChartColorTheme {
    static let confirmed = Color(red: 0.29, green: 0.87, blue: 0.50) // #4ade80
    static let mitigated = Color(red: 0.65, green: 0.54, blue: 0.98) // #a78bfa
    static let overestimated = Color(red: 1.00, green: 0.36, blue: 0.36) // #ff5c5c
    static let active = Color(red: 0.98, green: 0.75, blue: 0.14) // #fbbf24
    static let cleared = Color(red: 0.35, green: 0.43, blue: 0.53) // #5a6e87
    static let accent = Color(red: 0.31, green: 0.62, blue: 1.00) // #4f9eff
    static let cyan = Color(red: 0.13, green: 0.83, blue: 0.93) // #22d3ee
    static let orange = Color(red: 0.98, green: 0.57, blue: 0.24) // #fb923c
    static let purple = Color(red: 0.75, green: 0.45, blue: 1.00) // #c084fc
    static let bg = Color(red: 0.04, green: 0.05, blue: 0.08)
    static let cardBg = Color(red: 0.07, green: 0.10, blue: 0.13)
}
