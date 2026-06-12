/// Endpoints for the lightweight public APIs that power Vyra's assistant tools.
/// All of these are free and keyless except OpenWeatherMap (which uses
/// `OPENWEATHER_API_KEY` from `.env`).
class ApiConstants {
  ApiConstants._();

  // Weather — https://openweathermap.org/current
  static const String openWeatherBase =
      'https://api.openweathermap.org/data/2.5/weather';

  // Inspirational quotes — https://zenquotes.io/
  static const String quotesUrl = 'https://zenquotes.io/api/random';

  // Jokes — https://v2.jokeapi.dev/
  static const String jokeUrl =
      'https://v2.jokeapi.dev/joke/Any?blacklistFlags=nsfw,religious,political,racist,sexist,explicit&type=single';

  // Useless (but fun) facts — https://uselessfacts.jsph.pl/
  static const String factUrl =
      'https://uselessfacts.jsph.pl/api/v2/facts/random?language=en';
}
