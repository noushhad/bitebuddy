// lib/services/foodpanda_menu_service.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

class FoodpandaMenuService {
  static const String baseUrl = 'https://www.foodpanda.com.bd';
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

  /// Check if Foodpanda restaurant exists and is scrapable
  Future<FoodpandaRestaurant?> getFoodpandaRestaurant(
    String restaurantName, {
    String city = 'Dhaka',
  }) async {
    try {
      // Search for restaurant on Foodpanda
      final searchUrl = '$baseUrl/restaurants?query=$restaurantName';

      final response = await http.get(
        Uri.parse(searchUrl),
        headers: {'User-Agent': userAgent},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        // Parse restaurant listings
        final restaurant =
            _parseRestaurantListing(response.body, restaurantName);
        return restaurant;
      }
    } catch (e) {
      debugPrint('❌ Error fetching Foodpanda restaurant: $e');
    }
    return null;
  }

  /// Scrape menu items from Foodpanda restaurant page
  Future<List<FoodpandaMenuItem>> scrapeFoodpandaMenu(
    String restaurantUrl,
  ) async {
    try {
      if (restaurantUrl.isEmpty) return [];

      // Ensure full URL
      final fullUrl = restaurantUrl.startsWith('http')
          ? restaurantUrl
          : '$baseUrl$restaurantUrl';

      final response = await http.get(
        Uri.parse(fullUrl),
        headers: {
          'User-Agent': userAgent,
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final menuItems = _parseFoodpandaMenu(response.body);
        debugPrint('✅ Scraped ${menuItems.length} items from Foodpanda');
        return menuItems;
      } else if (response.statusCode == 429) {
        debugPrint('⚠️ Rate limited by Foodpanda (429)');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error scraping Foodpanda menu: $e');
    }
    return [];
  }

  /// Parse restaurant listing from search results
  FoodpandaRestaurant? _parseRestaurantListing(String html, String searchTerm) {
    try {
      final document = html_parser.parse(html);

      // Foodpanda restaurant listing structure
      final restaurantElements = document.querySelectorAll(
        'a[href*="/restaurants/"], div[class*="restaurant"]',
      );

      for (final elem in restaurantElements) {
        final name =
            elem.querySelector('h2, h3, span[class*="name"]')?.text.trim();
        final href = elem.attributes['href'] ?? '';
        final rating = elem.querySelector('[class*="rating"]')?.text.trim();
        final address = elem.querySelector('[class*="address"]')?.text.trim();
        final minOrder = elem.querySelector('[class*="minimum"]')?.text.trim();

        if (name != null &&
            name.toLowerCase().contains(searchTerm.toLowerCase())) {
          return FoodpandaRestaurant(
            name: name,
            url: href,
            rating: _parseRating(rating),
            address: address ?? '',
            minimumOrder: minOrder ?? '',
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error parsing restaurant listing: $e');
    }
    return null;
  }

  /// Parse menu items from restaurant page
  List<FoodpandaMenuItem> _parseFoodpandaMenu(String html) {
    final items = <FoodpandaMenuItem>[];

    try {
      final document = html_parser.parse(html);

      // ✅ Foodpanda selectors for menu items
      final selectors = [
        '[class*="menu-item"]',
        '[class*="food-item"]',
        '[class*="dish"]',
        'div[data-qa*="item"]',
        'div[class*="ProductCard"]',
      ];

      for (final selector in selectors) {
        final menuElements = document.querySelectorAll(selector);

        if (menuElements.isEmpty) continue;

        for (final elem in menuElements.take(100)) {
          try {
            // Extract name
            final name = elem
                .querySelector(
                  '[class*="name"], [class*="title"], h4, h3, span',
                )
                ?.text
                .trim();

            if (name == null || name.isEmpty || name.length > 100) continue;

            // Extract price
            final priceText = elem
                    .querySelector(
                      '[class*="price"], [class*="amount"], span[class*="tk"]',
                    )
                    ?.text
                    .trim() ??
                '';

            // Extract description
            final description = elem
                    .querySelector(
                      '[class*="description"], [class*="desc"], p',
                    )
                    ?.text
                    .trim() ??
                '';

            // Extract category
            final category = elem
                    .querySelector(
                      '[class*="category"], [class*="type"]',
                    )
                    ?.text
                    .trim() ??
                '';

            // Extract image
            final imageUrl = elem.querySelector('img')?.attributes['src'] ??
                elem.querySelector('img')?.attributes['data-src'] ??
                '';

            // Extract rating if available
            final rating = elem
                .querySelector(
                  '[class*="rating"], [class*="star"]',
                )
                ?.text
                .trim();

            items.add(FoodpandaMenuItem(
              name: name,
              price: priceText,
              description: description,
              category: category,
              imageUrl: _normalizeUrl(imageUrl),
              rating: _parseRating(rating),
            ));
          } catch (e) {
            debugPrint('⚠️ Error parsing menu item: $e');
            continue;
          }
        }

        if (items.isNotEmpty) break;
      }
    } catch (e) {
      debugPrint('❌ Error parsing menu: $e');
    }

    return items;
  }

  String _normalizeUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    if (url.startsWith('http')) return url;
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('/')) return '$baseUrl$url';

    return '$baseUrl/$url';
  }

  double? _parseRating(String? ratingText) {
    if (ratingText == null || ratingText.isEmpty) return null;

    try {
      final cleanedText = ratingText.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(cleanedText);
    } catch (e) {
      return null;
    }
  }

  /// Search restaurants by location (Dhaka, Chittagong, etc)
  Future<List<FoodpandaRestaurant>> searchRestaurants(
    String query, {
    String city = 'Dhaka',
  }) async {
    try {
      final url =
          '$baseUrl/search?q=$query&city=${city.toLowerCase().replaceAll(' ', '%20')}';

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': userAgent},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final restaurants = _parseMultipleRestaurants(response.body);
        return restaurants;
      }
    } catch (e) {
      debugPrint('❌ Error searching restaurants: $e');
    }

    return [];
  }

  List<FoodpandaRestaurant> _parseMultipleRestaurants(String html) {
    final restaurants = <FoodpandaRestaurant>[];

    try {
      final document = html_parser.parse(html);

      final restaurantElements = document
          .querySelectorAll('[class*="restaurant"], a[href*="/restaurants/"]');

      for (final elem in restaurantElements.take(20)) {
        try {
          final name = elem.querySelector('h2, h3, span')?.text.trim();
          final href = elem.attributes['href'] ?? '';
          final rating = elem.querySelector('[class*="rating"]')?.text.trim();
          final address = elem.querySelector('[class*="address"]')?.text.trim();

          if (name != null && href.isNotEmpty) {
            restaurants.add(FoodpandaRestaurant(
              name: name,
              url: href,
              rating: _parseRating(rating),
              address: address ?? '',
              minimumOrder: '',
            ));
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing restaurant: $e');
          continue;
        }
      }
    } catch (e) {
      debugPrint('❌ Error parsing restaurants: $e');
    }

    return restaurants;
  }
}

// ============ Data Models ============
class FoodpandaRestaurant {
  final String name;
  final String url;
  final double? rating;
  final String address;
  final String minimumOrder;

  FoodpandaRestaurant({
    required this.name,
    required this.url,
    this.rating,
    required this.address,
    required this.minimumOrder,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'url': url,
        'rating': rating,
        'address': address,
        'minimumOrder': minimumOrder,
      };
}

class FoodpandaMenuItem {
  final String name;
  final String price;
  final String description;
  final String category;
  final String imageUrl;
  final double? rating;

  FoodpandaMenuItem({
    required this.name,
    required this.price,
    required this.description,
    required this.category,
    required this.imageUrl,
    this.rating,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'description': description,
        'category': category,
        'imageUrl': imageUrl,
        'rating': rating,
      };
}
