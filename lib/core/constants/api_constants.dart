class ApiConstants {
  // TMDB API
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';
  static const String tmdbImageW500 = 'https://image.tmdb.org/t/p/w500';
  static const String tmdbImageOriginal = 'https://image.tmdb.org/t/p/original';
  
  // Chave pública de teste/demo do TMDB (Pode ser sobrescrita pelo usuário nas Configurações)
  static const String defaultTmdbApiKey = '2dca580c2a14b55200e784d157207b4d';

  // AniList GraphQL API (Sem chave necessária - 100% pública)
  static const String anilistGraphqlUrl = 'https://graphql.anilist.co';

  // Nyaa.si URLs
  static const String nyaaBaseUrl = 'https://nyaa.si';
  static const String nyaaRssAnime = 'https://nyaa.si/?page=rss&c=1_2&f=0';
  static const String nyaaRssLiveAction = 'https://nyaa.si/?page=rss&c=4_1&f=0';

  // OpenSubtitles REST API
  static const String openSubtitlesBaseUrl = 'https://api.opensubtitles.com/api/v1';
}
