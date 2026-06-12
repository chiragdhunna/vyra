/// Build flavors for Vyra (dev / staging / prod).
///
/// The flavor is set once at startup from the relevant entrypoint
/// (`main_dev.dart`, `main_staging.dart`, `main_prod.dart`) and read anywhere
/// in the app via [FlavorConfig].
enum Flavor { dev, staging, prod }

class FlavorConfig {
  FlavorConfig._();

  static Flavor _flavor = Flavor.dev;

  static Flavor get flavor => _flavor;

  static void init(Flavor flavor) => _flavor = flavor;

  static String get name => switch (_flavor) {
        Flavor.dev => 'dev',
        Flavor.staging => 'staging',
        Flavor.prod => 'prod',
      };

  static String get appTitle => switch (_flavor) {
        Flavor.prod => 'Vyra',
        Flavor.staging => 'Vyra (Staging)',
        Flavor.dev => 'Vyra (Dev)',
      };

  static bool get isProd => _flavor == Flavor.prod;
  static bool get isDev => _flavor == Flavor.dev;

  /// Whether to show the small "flavor" ribbon in non-production builds.
  static bool get showFlavorBanner => _flavor != Flavor.prod;
}
