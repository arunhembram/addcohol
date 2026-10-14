/**
 * Calculate distance between two GPS coordinates using Haversine formula.
 * Returns distance in meters.
 */
function calculateDistanceMeters(lat1, lon1, lat2, lon2) {
  const R = 6371000; // Earth's radius in meters
  const toRad = deg => (deg * Math.PI) / 180;

  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c * 10) / 10;
}

/**
 * Validates if the captured GPS location is within the allowed distance
 * from the registered shop coordinates.
 * Configurable default: 150 meters.
 */
function validateUploadDistance(shopLat, shopLon, capturedLat, capturedLon, maxDistanceMeters = 150) {
  const distance = calculateDistanceMeters(shopLat, shopLon, capturedLat, capturedLon);
  const isSuspicious = distance > maxDistanceMeters;
  return {
    distanceMeters: distance,
    isSuspicious,
    allowedThreshold: maxDistanceMeters
  };
}

/**
 * Ray-casting algorithm for checking if a point is inside a polygon.
 * Point: [lon, lat], Polygon: array of [lon, lat] points
 */
function isPointInPolygon(point, polygonCoordinates) {
  const [x, y] = point;
  let inside = false;
  for (let i = 0, j = polygonCoordinates.length - 1; i < polygonCoordinates.length; j = i++) {
    const xi = polygonCoordinates[i][0], yi = polygonCoordinates[i][1];
    const xj = polygonCoordinates[j][0], yj = polygonCoordinates[j][1];
    const intersect = ((yi > y) !== (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
    if (intersect) inside = !inside;
  }
  return inside;
}

/**
 * Checks if coordinates are within a zone's GeoJSON boundary.
 */
function isInsideZoneBoundary(lat, lon, boundaryGeojsonStr) {
  if (!boundaryGeojsonStr) return true; // If no boundary defined, assume valid
  try {
    const geojson = typeof boundaryGeojsonStr === 'string' ? JSON.parse(boundaryGeojsonStr) : boundaryGeojsonStr;
    if (geojson.type === 'Polygon' && geojson.coordinates && geojson.coordinates[0]) {
      return isPointInPolygon([lon, lat], geojson.coordinates[0]);
    }
  } catch (err) {
    console.error('[GEO] Error parsing boundary geojson:', err);
  }
  return true;
}

module.exports = {
  calculateDistanceMeters,
  validateUploadDistance,
  isInsideZoneBoundary
};
