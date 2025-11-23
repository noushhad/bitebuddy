// lib/services/menu_image_service.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MenuImageService {
  final _supabase = Supabase.instance.client;

  /// Get random menu images from Supabase menu_items table
  Future<List<String>> getRandomMenuImages(int count) async {
    try {
      debugPrint('📥 Fetching menu images from Supabase database...');

      // Fetch from menu_items table
      final data = await _supabase
          .from('menu_items')
          .select('image_url')
          .not('image_url', 'is', null); // Only items with image_url

      debugPrint('📊 Total menu items with images: ${data.length}');

      if (data.isEmpty) {
        debugPrint('⚠️ No menu items with images found');
        return [];
      }

      // Extract URLs
      final imageUrls = (data as List)
          .map((item) => item['image_url'] as String)
          .where((url) => url.isNotEmpty)
          .toList();

      debugPrint('🖼️ Valid image URLs: ${imageUrls.length}');

      if (imageUrls.isEmpty) {
        debugPrint('⚠️ No valid image URLs found');
        return [];
      }

      // Shuffle and return requested count
      imageUrls.shuffle();
      final selected = imageUrls.take(count).toList();

      debugPrint(
          '✅ Loaded ${selected.length} random menu images from database');
      return selected;
    } catch (e) {
      debugPrint('❌ Error fetching menu images: $e');
      return [];
    }
  }

  /// Get single random menu image
  Future<String?> getRandomMenuImage() async {
    try {
      final images = await getRandomMenuImages(1);
      return images.isNotEmpty ? images.first : null;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return null;
    }
  }

  /// Get menu images by restaurant
  Future<List<String>> getRestaurantMenuImages(
    String restaurantId,
    int count,
  ) async {
    try {
      debugPrint('📥 Fetching menu images for restaurant: $restaurantId');

      final data = await _supabase
          .from('menu_items')
          .select('image_url')
          .eq('restaurant_id', restaurantId)
          .not('image_url', 'is', null);

      final imageUrls = (data as List)
          .map((item) => item['image_url'] as String)
          .where((url) => url.isNotEmpty)
          .toList();

      imageUrls.shuffle();
      final selected = imageUrls.take(count).toList();

      debugPrint('✅ Loaded ${selected.length} images for restaurant');
      return selected;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return [];
    }
  }

  /// Get menu images by category
  Future<List<String>> getMenuImagesByCategory(String category) async {
    try {
      debugPrint('📥 Fetching menu images for category: $category');

      final data = await _supabase
          .from('menu_items')
          .select('image_url')
          .ilike('category', '%$category%')
          .not('image_url', 'is', null);

      final imageUrls = (data as List)
          .map((item) => item['image_url'] as String)
          .where((url) => url.isNotEmpty)
          .toList();

      if (imageUrls.isEmpty) {
        debugPrint('⚠️ No images found for category: $category');
        return [];
      }

      imageUrls.shuffle();
      final selected = imageUrls.take(5).toList();

      debugPrint('✅ Loaded ${selected.length} images for category');
      return selected;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return [];
    }
  }

  /// Get images excluding a specific one
  Future<List<String>> getRandomMenuImagesExcluding(
    int count,
    String? excludeUrl,
  ) async {
    try {
      final allImages = await getRandomMenuImages(count * 2);

      if (excludeUrl == null) {
        return allImages.take(count).toList();
      }

      final filtered = allImages.where((url) => url != excludeUrl).toList();
      return filtered.take(count).toList();
    } catch (e) {
      debugPrint('❌ Error: $e');
      return [];
    }
  }

  /// Clear cache (no-op for database approach)
  void clearCache() {
    debugPrint('🔄 Cache cleared (using database, no caching needed)');
  }

  /// Get cache info
  Map<String, dynamic> getCacheInfo() {
    return {'status': 'Using Supabase database (menu_items table)'};
  }
}
