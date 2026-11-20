// Copy this file as "api_config.dart" (same folder) and fill in your own
// keys. Like supabase_config.dart, the real file is gitignored.
//
// --- Gemini (product recognition) ---------------------------------------
// Get a free key at https://aistudio.google.com/apikey
//
// --- eBay (price comparison, primary) ------------------------------------
// Create an app at https://developer.ebay.com/my/keys
// Use the PRODUCTION keyset ("App ID"/Client ID + "Cert ID"/Client Secret)
// if you want real listings; the sandbox has almost no real inventory.
// New accounts go through a review - eBay says "at least one business
// day" - before production calls start working.
//
// --- MercadoLibre (price comparison, fallback) ---------------------------
// Create an app at https://developer.mercadolibre.com.ar (or your
// country's equivalent: .com.mx, .com.br, ...). This is normally approved
// instantly - it uses your existing verified account, not a separate
// developer review queue. See PriceComparisonService for how the two
// providers are picked between.
//
// SECURITY NOTE: these keys end up inside the compiled app, so anyone with
// the APK can extract them. That's acceptable for a university demo, but
// for anything public these calls should go through a backend (e.g. a
// Supabase Edge Function) that holds the secrets instead.

/// Gemini API key.
const String geminiApiKey = 'YOUR-GEMINI-API-KEY';

/// Gemini model used for recognition. Needs vision support.
/// Cheap + fast options: 'gemini-3.5-flash-lite', 'gemini-3.6-flash'.
/// Higher quality: 'gemini-4-hydrogen'.
const String geminiModel = 'gemini-3.5-flash-lite';

/// eBay application credentials (client credentials grant).
const String ebayClientId = 'YOUR-EBAY-CLIENT-ID';
const String ebayClientSecret = 'YOUR-EBAY-CLIENT-SECRET';

/// Set to true to hit the eBay sandbox instead of production.
const bool ebayUseSandbox = false;

/// Which eBay marketplace to price against (EBAY_US, EBAY_ES, EBAY_GB...).
const String ebayMarketplaceId = 'EBAY_US';

/// MercadoLibre application credentials (client credentials grant).
const String mercadoLibreClientId = 'YOUR-MERCADOLIBRE-CLIENT-ID';
const String mercadoLibreClientSecret = 'YOUR-MERCADOLIBRE-CLIENT-SECRET';

/// Which MercadoLibre country site to price against.
/// MLA = Argentina, MLM = Mexico, MLB = Brazil, MCO = Colombia,
/// MLC = Chile, MLU = Uruguay, MPE = Peru, MEC = Ecuador, MLV = Venezuela.
const String mercadoLibreSiteId = 'MLA';

/// When true, recognition uses the bundled sample catalog instead of
/// calling Gemini. Handy as a fallback if the network/API is down during
/// a demo - the rest of the app behaves exactly the same.
const bool useMockRecognition = false;
