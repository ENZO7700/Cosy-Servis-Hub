/**
 * Custom premium mobile profile approximating iPhone 17 Air:
 * thin tall OLED, 3× retina, Safari iOS, Polish locale.
 */
export const iPhone17AirPremiumDevice = {
  userAgent:
    'Mozilla/5.0 (iPhone; CPU iPhone OS 19_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/19.0 Mobile/15E148 Safari/604.1',
  viewport: { width: 420, height: 912 },
  screen: { width: 420, height: 912 },
  deviceScaleFactor: 3,
  isMobile: true,
  hasTouch: true,
  locale: 'pl-PL',
  timezoneId: 'Europe/Warsaw',
  geolocation: { latitude: 52.2297, longitude: 21.0122 }, // Warszawa
  permissions: ['geolocation'] as const,
  colorScheme: 'dark' as const,
  reducedMotion: 'no-preference' as const,
};

/** @deprecated use iPhone17AirPremiumDevice */
export const iPhone17AirPremium = {
  name: 'iPhone 17 Air Premium',
  use: iPhone17AirPremiumDevice,
};
