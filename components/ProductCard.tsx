/**
 * Single product/item card for the horizontal list.
 */

import React from 'react';
import {StyleSheet, Text, View, ViewStyle} from 'react-native';

const CARD_WIDTH = 160;
const CARD_MARGIN = 12;

export interface ProductItem {
  id: string;
  title: string;
  subtitle: string;
  impressionCount: number;
}

export interface ProductCardProps {
  item: ProductItem;
  surfaceStyle: ViewStyle;
  mutedColor: string;
  textColor: string;
}

function ProductCard({item, surfaceStyle, mutedColor, textColor}: ProductCardProps): JSX.Element {
  return (
    <View
      style={[styles.card, surfaceStyle, {borderColor: mutedColor}]}>
      <View style={[styles.cardThumb, {backgroundColor: mutedColor}]} />
      <Text style={[styles.cardTitle, {color: textColor}]} numberOfLines={1}>
        {item.title}
      </Text>
      <Text style={[styles.cardSubtitle, {color: mutedColor}]} numberOfLines={2}>
        {item.subtitle}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    width: CARD_WIDTH,
    marginRight: CARD_MARGIN,
    padding: 12,
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
  },
  cardThumb: {
    width: '100%',
    aspectRatio: 1,
    borderRadius: 8,
    marginBottom: 8,
    opacity: 0.3,
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 4,
  },
  cardSubtitle: {
    fontSize: 12,
  },
});

export default ProductCard;
