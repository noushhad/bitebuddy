class FirestorePaths {
  // Root collections
  static const users = 'users';
  static const restaurants = 'restaurants';

  // User-specific
  static String user(String uid) => 'users/$uid';

  // Favorites (array inside user doc)
  static String userFavorites(String uid) => 'users/$uid/favorites';

  // Restaurant-specific
  static String restaurant(String rid) => 'restaurants/$rid';

  static String menu(String rid) => 'restaurants/$rid/menu';
  static String menuItem(String rid, String itemId) =>
      'restaurants/$rid/menu/$itemId';

  static String reviews(String rid) => 'restaurants/$rid/reviews';
  static String review(String rid, String reviewId) =>
      'restaurants/$rid/reviews/$reviewId';

  static String reservations(String rid) => 'restaurants/$rid/reservations';
  static String reservation(String rid, String resId) =>
      'restaurants/$rid/reservations/$resId';

  static String promotions(String rid) => 'restaurants/$rid/promotions';
  static String promotion(String rid, String promoId) =>
      'restaurants/$rid/promotions/$promoId';

  // Example: images under a restaurant
  static String gallery(String rid) => 'restaurants/$rid/gallery';

  // Notifications (optional global collection)
  static const notifications = 'notifications';
  static String userNotifications(String uid) => 'notifications/$uid';
}
