/// Normalizes device ids for comparison across iOS (UUID) and Android (MAC).
bool deviceIdsMatch(String a, String b) => a.toLowerCase() == b.toLowerCase();
