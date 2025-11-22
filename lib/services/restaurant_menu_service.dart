// lib/services/restaurant_menu_service.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:html/parser.dart' as html_parser;

class RestaurantMenuService {
  static const String _googleApiKey = 'AIzaSyCoQzkmzecrFnHY1vSeJiRdiG4YILWKK2Y';

  /// Fetch restaurant details with photos using Google Places API
  Future<RestaurantMenuData?> getRestaurantMenuData(String placeId) async {
    try {
      const String apiKey = _googleApiKey;
      final url = 'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&fields=name,photos,formatted_phone_number,website,price_level,reviews,geometry,types'
          '&key=$apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        debugPrint('❌ Google Places API error: ${response.statusCode}');
        return null;
      }

      final detail = json.decode(response.body);
      final result = detail['result'] ?? {};

      // Extract photo URLs
      final photoUrls = _extractPhotoUrls(result['photos'] ?? [], apiKey);

      // Extract cuisine/types
      final cuisine = _extractCuisine(result['types'] ?? []);

      final menuData = RestaurantMenuData(
        name: result['name'] ?? '',
        address: result['formatted_address'] ?? '',
        phoneNumber: result['formatted_phone_number'] ?? '',
        website: result['website'] ?? '',
        priceLevel: result['price_level'] ?? 0,
        cuisine: cuisine,
        photoUrls: photoUrls,
        menuLink: result['website'] ?? '',
        location: result['geometry']?['location'],
      );

      debugPrint('✅ Restaurant menu data fetched: ${menuData.name}');
      return menuData;
    } catch (e) {
      debugPrint('❌ Failed to fetch restaurant menu: $e');
      return null;
    }
  }

  /// Get high-quality photos from Google Places
  Future<List<String>> getHighQualityPhotos(
    String placeId, {
    int maxWidth = 800,
    int maxHeight = 600,
  }) async {
    try {
      const String apiKey = _googleApiKey;
      final url = 'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&fields=photos'
          '&key=$apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) return [];

      final detail = json.decode(response.body);
      final result = detail['result'] ?? {};
      final photos = result['photos'] ?? [];

      final photoUrls = <String>[];

      for (final photo in photos) {
        final ref = photo['photo_reference'];
        if (ref != null) {
          final photoUrl = 'https://maps.googleapis.com/maps/api/place/photo'
              '?maxwidth=$maxWidth'
              '&maxheight=$maxHeight'
              '&photoreference=$ref'
              '&key=$apiKey';

          photoUrls.add(photoUrl);
        }
      }

      debugPrint('✅ Fetched ${photoUrls.length} photos');
      return photoUrls;
    } catch (e) {
      debugPrint('❌ Failed to fetch photos: $e');
      return [];
    }
  }

  List<String> _extractPhotoUrls(List<dynamic> photos, String apiKey) {
    return photos
        .take(5) // Limit to first 5 photos
        .map((photo) {
          final ref = photo['photo_reference'];
          if (ref != null) {
            return 'https://maps.googleapis.com/maps/api/place/photo'
                '?maxwidth=800'
                '&maxheight=600'
                '&photoreference=$ref'
                '&key=$apiKey';
          }
          return '';
        })
        .where((url) => url.isNotEmpty)
        .toList();
  }

  String _extractCuisine(List<dynamic> types) {
    const cuisineMap = {
      'restaurant': 'Restaurant',
      'cafe': 'Café',
      'bar': 'Bar & Grill',
      'pizza_restaurant': 'Pizza',
      'chinese_restaurant': 'Chinese',
      'indian_restaurant': 'Indian',
      'japanese_restaurant': 'Japanese',
      'thai_restaurant': 'Thai',
      'mexican_restaurant': 'Mexican',
      'italian_restaurant': 'Italian',
      'korean_restaurant': 'Korean',
      'seafood_restaurant': 'Seafood',
      'steakhouse': 'Steakhouse',
    };

    for (final type in types) {
      if (cuisineMap.containsKey(type)) {
        return cuisineMap[type]!;
      }
    }
    return 'Restaurant';
  }
}

// ============ METHOD 2: Website Scraping Service ============
class MenuScraperService {
  /// Scrape menu from restaurant website
  Future<List<MenuItem>> scrapeMenuFromWebsite(String websiteUrl) async {
    try {
      if (websiteUrl.isEmpty) return [];

      final response = await http.get(Uri.parse(websiteUrl)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('', 408),
      );

      if (response.statusCode != 200) {
        debugPrint('❌ Failed to fetch website: ${response.statusCode}');
        return [];
      }

      final document = html_parser.parse(response.body);
      final menuItems = <MenuItem>[];

      // Common menu selectors (adjust based on restaurant website structure)
      final selectors = [
        '.menu-item',
        '[class*="menu"]',
        '[class*="dish"]',
        '[class*="food-item"]',
        'article',
      ];

      for (final selector in selectors) {
        final items = document.querySelectorAll(selector);

        for (final item in items) {
          final name = item
              .querySelector('[class*="name"], [class*="title"], h3, h4')
              ?.text
              .trim();
          final description = item
              .querySelector('[class*="description"], [class*="desc"], p')
              ?.text
              .trim();
          final price =
              item.querySelector('[class*="price"], .amount')?.text.trim();
          final imageUrl = item.querySelector('img')?.attributes['src'];

          if (name != null && name.isNotEmpty) {
            menuItems.add(MenuItem(
              name: name,
              description: description ?? '',
              price: price ?? 'N/A',
              imageUrl: _normalizeUrl(imageUrl, websiteUrl),
            ));
          }
        }

        if (menuItems.isNotEmpty) break;
      }

      debugPrint('✅ Scraped ${menuItems.length} menu items');
      return menuItems;
    } catch (e) {
      debugPrint('❌ Failed to scrape menu: $e');
      return [];
    }
  }

  /// Try to find menu link on restaurant website
  Future<String?> findMenuLinkOnWebsite(String websiteUrl) async {
    try {
      final response = await http.get(Uri.parse(websiteUrl)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('', 408),
      );

      if (response.statusCode != 200) return null;

      final document = html_parser.parse(response.body);

      final patterns = [
        'menu',
        'dining',
        'food',
        'dishes',
        'offerings',
        'cuisine',
      ];

      final links = document.querySelectorAll('a[href]');

      for (final link in links) {
        final href = link.attributes['href'] ?? '';
        final text = link.text.toLowerCase();

        for (final pattern in patterns) {
          if (text.contains(pattern) && href.contains(pattern)) {
            return _normalizeUrl(href, websiteUrl);
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error finding menu link: $e');
      return null;
    }
  }

  String _normalizeUrl(String? url, String baseUrl) {
    if (url == null || url.isEmpty) return '';

    if (url.startsWith('http')) return url;
    if (url.startsWith('/')) {
      return Uri.parse(baseUrl).origin + url;
    }
    return Uri.parse(baseUrl).resolve(url).toString();
  }
}

// ============ Data Models ============
class RestaurantMenuData {
  final String name;
  final String address;
  final String phoneNumber;
  final String website;
  final int priceLevel;
  final String cuisine;
  final List<String> photoUrls;
  final String menuLink;
  final Map<String, dynamic>? location;

  RestaurantMenuData({
    required this.name,
    required this.address,
    required this.phoneNumber,
    required this.website,
    required this.priceLevel,
    required this.cuisine,
    required this.photoUrls,
    required this.menuLink,
    this.location,
  });
}

class MenuItem {
  final String name;
  final String description;
  final String price;
  final String imageUrl;

  MenuItem({
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'price': price,
    'imageUrl': imageUrl,
  };
}