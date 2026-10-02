import 'package:flutter/material.dart';

/// Icon set for savings goals — Material Icons only, no emoji.
const List<String> goalIconNames = [
  'flag',
  'shield',
  'flight',
  'laptop_mac',
  'directions_car',
  'home',
  'favorite',
  'menu_book',
  'fitness_center',
  'music_note',
  'public',
  'child_friendly',
  'pets',
  'sailing',
  'terrain',
  'school',
];

IconData goalIconFor(String iconName) {
  switch (iconName) {
    case 'flag':
      return Icons.flag;
    case 'shield':
      return Icons.shield;
    case 'flight':
      return Icons.flight;
    case 'laptop_mac':
      return Icons.laptop_mac;
    case 'directions_car':
      return Icons.directions_car;
    case 'home':
      return Icons.home;
    case 'favorite':
      return Icons.favorite;
    case 'menu_book':
      return Icons.menu_book;
    case 'fitness_center':
      return Icons.fitness_center;
    case 'music_note':
      return Icons.music_note;
    case 'public':
      return Icons.public;
    case 'child_friendly':
      return Icons.child_friendly;
    case 'pets':
      return Icons.pets;
    case 'sailing':
      return Icons.sailing;
    case 'terrain':
      return Icons.terrain;
    case 'school':
      return Icons.school;
    default:
      return Icons.flag;
  }
}
