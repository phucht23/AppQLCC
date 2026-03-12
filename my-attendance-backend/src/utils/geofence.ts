// src/utils/geofence.ts

export const calculateDistance = (
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number => {
  const toRad = (value: number) => (value * Math.PI) / 180;
  const R = 6371000; // Bán kính Trái Đất tính bằng mét

  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
};

export const isWithinGeofence = (userLat: number, userLon: number): { allowed: boolean; distance: number } => {
  const companyLat = parseFloat(process.env.COMPANY_LATITUDE || '0');
  const companyLon = parseFloat(process.env.COMPANY_LONGITUDE || '0');
  const radius = parseInt(process.env.GEOFENCE_RADIUS || '100', 10);

  const distance = calculateDistance(userLat, userLon, companyLat, companyLon);

  return {
    allowed: distance <= radius,
    distance: Math.round(distance),
  };
};