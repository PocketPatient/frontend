/// The API sends UTC timestamps ("...+00:00"); DateTime.parse keeps them in
/// UTC, so .hour/.day would show UTC. Convert to the device's time zone.
DateTime parseApiDate(String raw) => DateTime.parse(raw).toLocal();

DateTime? tryParseApiDate(String? raw) =>
    raw == null ? null : DateTime.tryParse(raw)?.toLocal();
